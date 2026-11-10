import Foundation
import Testing
@testable import TBDCore

/// TC-PRT-007: 충전 수치 해석과 충전 제한 요소 판정.
@Suite("TC-PRT-007 충전 제한 요소 판정")
struct ChargingAssessmentTests {
    /// 실측 (T53): 독이 45 W로 충전 중인 상태의 배터리 노드 속성.
    static let measuredNode: [String: Any] = [
        "ExternalConnected": true, "IsCharging": true, "FullyCharged": false, "CurrentCapacity": 83, "AvgTimeToFull": 81,
        "AdapterDetails": [
            "Watts": 45, "AdapterVoltage": 20000, "Current": 2250, "Description": "pd charger", "IsWireless": false,
            "UsbHvcMenu": [
                ["Index": 0, "MaxVoltage": 5000, "MaxCurrent": 1500],
                ["Index": 1, "MaxVoltage": 9000, "MaxCurrent": 780],
                ["Index": 2, "MaxVoltage": 12000, "MaxCurrent": 1340],
                ["Index": 3, "MaxVoltage": 15000, "MaxCurrent": 1670],
                ["Index": 4, "MaxVoltage": 20000, "MaxCurrent": 2250],
            ],
        ] as [String: Any],
        "PowerTelemetryData": ["SystemPowerIn": 42184, "SystemLoad": 10366, "BatteryPower": 31818, "SystemVoltageIn": 19458, "SystemCurrentIn": 2167],
        "ChargerData": ["NotChargingReason": 0, "SlowChargingReason": 0, "ChargerInhibitReason": 0, "TimeChargingThermallyLimited": 0, "ChargingCurrent": 2611],
    ]

    static func cable(current: Int, voltageCode: Int = 0, epr: Bool = false) -> CableEMarker {
        CableEMarker(port: PortKey(type: "USB-C", number: 4), productType: "Passive Cable", vendorID: 0, speedCode: 3, currentCode: current, maxVoltageCode: voltageCode, eprCapable: epr)
    }

    static func adapter(_ options: [(Double, Double)], negotiated: Int? = nil) -> PowerAdapterInfo {
        let picked = options[negotiated ?? options.count - 1]
        return PowerAdapterInfo(
            isConnected: true, watts: Int((picked.0 * picked.1).rounded()), voltage: picked.0, current: picked.1,
            name: nil, manufacturer: nil, isWireless: false,
            options: options.map { PowerAdapterInfo.Option(voltage: $0.0, current: $0.1) }
        )
    }

    @Test func 실측_노드_해석() {
        let telemetry = ChargingTelemetry.decode(Self.measuredNode)
        #expect(telemetry == ChargingTelemetry(isCharging: true, fullyCharged: false, chargePercent: 83, minutesToFull: 81, systemPowerIn: 42184, systemLoad: 10366, notChargingReason: 0, slowChargingReason: 0, chargerInhibitReason: 0, thermallyLimitedSeconds: 0))
        // 완충 시간 65535는 계산 전 상태.
        #expect(ChargingTelemetry.decode(["AvgTimeToFull": 65535]).minutesToFull == nil)
        #expect(ChargingTelemetry.decode([:]) == ChargingTelemetry())
    }

    @Test func 실측_구성은_충전기가_상한() {
        let findings = ChargingAssessment.assess(
            adapter: PowerAdapterInfo.decode(Self.measuredNode),
            telemetry: ChargingTelemetry.decode(Self.measuredNode),
            cable: Self.cable(current: 2, voltageCode: 3, epr: true)
        )
        #expect(findings.map(\.code) == ["CHG.SOURCE_LIMIT", "CHG.POWER_SPLIT"])
        #expect(findings[0].detail == "충전기 최대 45 W, 협상 20.0 V, 2.25 A (45 W), 케이블 정격 5 A, 최대 50 V")
        #expect(findings[1].detail == "입력 42.2 W 중 시스템 소비 10.4 W, 배터리 쪽 31.8 W, 완충까지 81분")
        #expect(findings.allSatisfy { $0.severity == .info })
    }

    @Test func 전류_정격_3A_케이블은_96W_충전기를_60W로_제한() throws {
        let adapter = Self.adapter([(5, 3), (9, 3), (15, 3), (20, 4.8)])
        #expect(ChargingAssessment.deliverableWatts(options: adapter.options, cable: Self.cable(current: 1)) == 60)
        let findings = ChargingAssessment.assess(adapter: adapter, telemetry: ChargingTelemetry(), cable: Self.cable(current: 1))
        let limit = try #require(findings.first { $0.code == "CHG.CABLE_LIMIT" })
        #expect(limit.severity == .warning)
        #expect(limit.detail == "충전기 최대 96 W, 케이블 정격 3 A, 최대 20 V. 이 케이블로 받을 수 있는 전력 60 W")
        #expect(!findings.contains { $0.code == "CHG.SOURCE_LIMIT" })
    }

    @Test func 전압_20V_케이블은_EPR_전원_옵션을_쓸_수_없음() throws {
        // 140 W 충전기 (28 V 5 A)와 20 V 5 A 케이블: 받을 수 있는 전력은 20 V 5 A.
        let adapter = Self.adapter([(5, 3), (9, 3), (15, 5), (20, 5), (28, 5)])
        #expect(ChargingAssessment.deliverableWatts(options: adapter.options, cable: Self.cable(current: 2)) == 100)
        let findings = ChargingAssessment.assess(adapter: adapter, telemetry: ChargingTelemetry(), cable: Self.cable(current: 2))
        #expect(findings.first?.code == "CHG.CABLE_LIMIT")
        // 50 V 정격 케이블이면 제한 없음.
        let epr = ChargingAssessment.assess(adapter: adapter, telemetry: ChargingTelemetry(), cable: Self.cable(current: 2, voltageCode: 3, epr: true))
        #expect(epr.first?.code == "CHG.SOURCE_LIMIT")
    }

    @Test func 케이블을_특정할_수_없으면_충전기_기준으로_표기() {
        let findings = ChargingAssessment.assess(adapter: Self.adapter([(5, 3), (20, 3)]), telemetry: ChargingTelemetry(), cable: nil)
        #expect(findings.map(\.code) == ["CHG.SOURCE_LIMIT"])
        #expect(findings[0].detail.hasSuffix("케이블 정격 미확인 (e-marker 없음 또는 전원 포트 특정 불가)"))
        // 전류 정격 표기가 없는 e-marker도 제한으로 판정하지 않음.
        #expect(ChargingAssessment.deliverableWatts(options: [.init(voltage: 20, current: 3)], cable: Self.cable(current: 0)) == nil)
    }

    @Test func 협상_전력이_최대보다_낮으면_안내() {
        let findings = ChargingAssessment.assess(adapter: Self.adapter([(5, 3), (9, 3), (20, 4.8)], negotiated: 1), telemetry: ChargingTelemetry(), cable: nil)
        #expect(findings.map(\.code) == ["CHG.SOURCE_LIMIT", "CHG.BELOW_MAXIMUM"])
        #expect(findings[1].detail == "협상 9.0 V, 3.00 A (27 W), 충전기 최대 96 W. 기기가 더 낮은 전원 옵션을 선택한 상태")
    }

    @Test func 시스템_소비가_입력보다_크면_주의() throws {
        let telemetry = ChargingTelemetry(isCharging: false, fullyCharged: false, chargePercent: 40, systemPowerIn: 28000, systemLoad: 61500, notChargingReason: 0)
        let findings = ChargingAssessment.assess(adapter: Self.adapter([(5, 3), (9, 3), (15, 2)]), telemetry: telemetry, cable: nil)
        let load = try #require(findings.first { $0.code == "CHG.LOAD_EXCEEDS_INPUT" })
        #expect(load.severity == .warning)
        #expect(load.detail == "입력 28.0 W, 시스템 소비 61.5 W. 부족분 33.5 W는 배터리에서 공급")
        #expect(findings.contains { $0.code == "CHG.NOT_CHARGING" })
        #expect(!findings.contains { $0.code == "CHG.POWER_SPLIT" })
    }

    @Test func 충전_상태와_사유_부호() throws {
        let adapter = Self.adapter([(20, 4.8)])
        let full = ChargingAssessment.assess(adapter: adapter, telemetry: ChargingTelemetry(isCharging: false, fullyCharged: true, chargePercent: 100), cable: nil)
        #expect(full.map(\.code) == ["CHG.SOURCE_LIMIT", "CHG.FULL"])

        let paused = ChargingAssessment.assess(adapter: adapter, telemetry: ChargingTelemetry(isCharging: false, fullyCharged: false, chargePercent: 80, notChargingReason: 128), cable: nil)
        let notCharging = try #require(paused.first { $0.code == "CHG.NOT_CHARGING" })
        #expect(notCharging.detail.hasPrefix("충전 중지 사유 부호 128 (0x80), 잔량 80%"))

        let limited = ChargingAssessment.assess(adapter: adapter, telemetry: ChargingTelemetry(isCharging: true, slowChargingReason: 2, chargerInhibitReason: 4, thermallyLimitedSeconds: 90), cable: nil)
        #expect(limited.map(\.code) == ["CHG.SOURCE_LIMIT", "CHG.SLOW", "CHG.INHIBIT", "CHG.THERMAL"])
        #expect(limited.filter { $0.severity == .warning }.map(\.code) == ["CHG.SLOW", "CHG.THERMAL"])
    }

    @Test func 미연결이면_판정_없음() {
        let adapter = PowerAdapterInfo.decode(["ExternalConnected": false])
        let findings = ChargingAssessment.assess(adapter: adapter, telemetry: ChargingTelemetry(), cable: nil)
        #expect(findings.map(\.code) == ["CHG.NOT_CONNECTED"])
    }

    @Test func 전원_케이블은_연결된_포트의_e_marker가_1개일_때만_특정() throws {
        func port(_ number: Int, connected: Bool) throws -> PortInfo {
            try #require(PortInfo.decode(["PortTypeDescription": "USB-C", "PortNumber": number, "ConnectionActive": connected]))
        }
        func cable(_ number: Int) -> CableEMarker {
            CableEMarker(port: PortKey(type: "USB-C", number: number), productType: "Passive Cable", vendorID: 0, speedCode: 3, currentCode: 2, maxVoltageCode: 0, eprCapable: false)
        }
        func inventory(_ ports: [PortInfo], _ cables: [CableEMarker]) -> PortInventory {
            PortInventory(ports: ports, dpStates: [], cioStates: [], usbStates: [], cables: cables)
        }
        let ports = [try port(1, connected: true), try port(2, connected: false), try port(4, connected: true)]
        // 연결된 포트의 e-marker 1개.
        #expect(ChargingAssessment.powerCable(in: inventory(ports, [cable(4)]))?.port.number == 4)
        // 연결이 끊긴 포트에 남은 e-marker는 제외.
        #expect(ChargingAssessment.powerCable(in: inventory(ports, [cable(2), cable(4)]))?.port.number == 4)
        // 연결된 포트 2개에 e-marker가 있으면 특정하지 않음.
        #expect(ChargingAssessment.powerCable(in: inventory(ports, [cable(1), cable(4)])) == nil)
        #expect(ChargingAssessment.powerCable(in: inventory(ports, [])) == nil)
    }
}
