import Foundation

/// 충전 상태 수치. `AppleSmartBattery` 노드에서 구성. 전력 단위는 mW. (PRD-PRT-007)
///
/// 값이 읽을 때마다 변하므로 `PortInventory`(변화 감지 비교 대상)와 분리.
public struct ChargingTelemetry: Codable, Hashable, Sendable {
    public var isCharging: Bool?
    public var fullyCharged: Bool?
    /// 배터리 잔량 (%).
    public var chargePercent: Int?
    /// 완충까지 남은 시간 (분). 시스템이 계산하지 못한 경우 nil.
    public var minutesToFull: Int?
    /// 어댑터에서 들어오는 전력.
    public var systemPowerIn: Int?
    /// 시스템 소비 전력.
    public var systemLoad: Int?
    /// 충전 회로가 보고하는 사유 부호. 0은 해당 없음. 부호의 의미는 공개 문서가 없어 원시 값으로만 표시.
    public var notChargingReason: Int?
    public var slowChargingReason: Int?
    public var chargerInhibitReason: Int?
    /// 온도로 충전이 제한된 누적 시간 (초).
    public var thermallyLimitedSeconds: Int?

    public init(isCharging: Bool? = nil, fullyCharged: Bool? = nil, chargePercent: Int? = nil, minutesToFull: Int? = nil, systemPowerIn: Int? = nil, systemLoad: Int? = nil, notChargingReason: Int? = nil, slowChargingReason: Int? = nil, chargerInhibitReason: Int? = nil, thermallyLimitedSeconds: Int? = nil) {
        self.isCharging = isCharging
        self.fullyCharged = fullyCharged
        self.chargePercent = chargePercent
        self.minutesToFull = minutesToFull
        self.systemPowerIn = systemPowerIn
        self.systemLoad = systemLoad
        self.notChargingReason = notChargingReason
        self.slowChargingReason = slowChargingReason
        self.chargerInhibitReason = chargerInhibitReason
        self.thermallyLimitedSeconds = thermallyLimitedSeconds
    }

    /// `node`는 `AppleSmartBattery` 노드의 속성 사전.
    public static func decode(_ node: [String: Any]) -> ChargingTelemetry {
        func int(_ dictionary: [String: Any], _ key: String) -> Int? { (dictionary[key] as? NSNumber)?.intValue }
        func bool(_ key: String) -> Bool? { (node[key] as? NSNumber)?.boolValue }
        let telemetry = node["PowerTelemetryData"] as? [String: Any] ?? [:]
        let charger = node["ChargerData"] as? [String: Any] ?? [:]
        // 완충 시간 65535는 계산 전 상태.
        let minutes = int(node, "AvgTimeToFull").flatMap { $0 > 0 && $0 < 65535 ? $0 : nil }
        return ChargingTelemetry(
            isCharging: bool("IsCharging"),
            fullyCharged: bool("FullyCharged"),
            chargePercent: int(node, "CurrentCapacity"),
            minutesToFull: minutes,
            systemPowerIn: int(telemetry, "SystemPowerIn"),
            systemLoad: int(telemetry, "SystemLoad"),
            notChargingReason: int(charger, "NotChargingReason"),
            slowChargingReason: int(charger, "SlowChargingReason"),
            chargerInhibitReason: int(charger, "ChargerInhibitReason"),
            thermallyLimitedSeconds: int(charger, "TimeChargingThermallyLimited")
        )
    }
}

/// 충전 제한 요소 판정: 충전기, 케이블, 시스템 소비를 비교. (PRD-PRT-007)
public enum ChargingAssessment {
    /// 케이블 e-marker의 전류 정격 (A). 표기가 없으면 nil.
    public static func cableAmperes(_ cable: CableEMarker) -> Double? {
        switch cable.currentCode {
        case 1: 3
        case 2: 5
        default: nil
        }
    }

    /// 케이블 정격 안에서 받을 수 있는 최대 전력 (W): 케이블 최대 전압 이하의 전원 옵션 중 전류를 케이블 정격으로 제한한 값의 최댓값.
    public static func deliverableWatts(options: [PowerAdapterInfo.Option], cable: CableEMarker) -> Double? {
        guard let amperes = cableAmperes(cable) else { return nil }
        return options.filter { $0.voltage <= Double(cable.maxVoltage) }.map { $0.voltage * min($0.current, amperes) }.max()
    }

    static func watts(_ value: Double) -> String {
        abs(value - value.rounded()) < 0.05 ? String(format: "%.0f W", value) : String(format: "%.1f W", value)
    }

    /// `cable`은 전원이 들어오는 포트의 케이블 e-marker. 포트를 특정할 수 없으면 nil.
    public static func assess(adapter: PowerAdapterInfo, telemetry: ChargingTelemetry, cable: CableEMarker?) -> [Finding] {
        let subject = "전원"
        guard adapter.isConnected else {
            return [Finding(code: "CHG.NOT_CONNECTED", severity: .info, subject: subject, title: "전원 어댑터 연결 없음", detail: "배터리로 동작 중", remedy: "")]
        }
        var findings: [Finding] = []

        // (1) 공급 전력의 상한: 충전기와 케이블 비교.
        let sourceMaximum = adapter.options.map(\.watts).max() ?? adapter.watts.map(Double.init)
        let negotiated: Double? = {
            guard let voltage = adapter.voltage, let current = adapter.current, voltage > 0 else { return nil }
            return voltage * current
        }()
        let negotiatedText = negotiated.map { _ in String(format: "협상 %.1f V, %.2f A (%@)", adapter.voltage ?? 0, adapter.current ?? 0, watts(negotiated ?? 0)) }
        if let sourceMaximum {
            let cableText = cable.map { "케이블 정격 \($0.currentName), 최대 \($0.maxVoltage) V" } ?? "케이블 정격 미확인 (e-marker 없음 또는 전원 포트 특정 불가)"
            if let cable, let deliverable = deliverableWatts(options: adapter.options, cable: cable), deliverable < sourceMaximum - 0.5 {
                findings.append(Finding(
                    code: "CHG.CABLE_LIMIT", severity: .warning, subject: subject,
                    title: "케이블이 충전 전력을 제한",
                    detail: "충전기 최대 \(watts(sourceMaximum)), \(cableText). 이 케이블로 받을 수 있는 전력 \(watts(deliverable))",
                    remedy: "전류 정격 5 A 케이블(100 W 이상 표기)로 교체"
                ))
            } else {
                findings.append(Finding(
                    code: "CHG.SOURCE_LIMIT", severity: .info, subject: subject,
                    title: "공급 전력의 상한은 충전기",
                    detail: (["충전기 최대 \(watts(sourceMaximum))"] + (negotiatedText.map { [$0] } ?? []) + [cableText]).joined(separator: ", "),
                    remedy: "더 빠른 충전이 필요하면 출력이 더 큰 충전기 사용"
                ))
            }
            if let negotiated, negotiated < sourceMaximum - 1 {
                findings.append(Finding(
                    code: "CHG.BELOW_MAXIMUM", severity: .info, subject: subject,
                    title: "협상 전력이 충전기 최대보다 낮음",
                    detail: "\(negotiatedText ?? ""), 충전기 최대 \(watts(sourceMaximum)). 기기가 더 낮은 전원 옵션을 선택한 상태",
                    remedy: ""
                ))
            }
        }

        // (2) 입력 전력과 시스템 소비 비교.
        if let input = telemetry.systemPowerIn, let load = telemetry.systemLoad, input > 0 {
            let inputWatts = Double(input) / 1000, loadWatts = Double(load) / 1000
            if load > input {
                findings.append(Finding(
                    code: "CHG.LOAD_EXCEEDS_INPUT", severity: .warning, subject: subject,
                    title: "시스템 소비가 입력 전력보다 큼",
                    detail: String(format: "입력 %.1f W, 시스템 소비 %.1f W. 부족분 %.1f W는 배터리에서 공급", inputWatts, loadWatts, loadWatts - inputWatts),
                    remedy: "출력이 더 큰 충전기 사용 또는 부하 감소"
                ))
            } else {
                var detail = String(format: "입력 %.1f W 중 시스템 소비 %.1f W, 배터리 쪽 %.1f W", inputWatts, loadWatts, inputWatts - loadWatts)
                if telemetry.isCharging == true, let minutes = telemetry.minutesToFull { detail += ", 완충까지 \(minutes)분" }
                findings.append(Finding(code: "CHG.POWER_SPLIT", severity: .info, subject: subject, title: "입력 전력 배분", detail: detail, remedy: ""))
            }
        }

        // (3) 충전 상태와 사유 부호.
        let percent = telemetry.chargePercent.map { ", 잔량 \($0)%" } ?? ""
        if telemetry.fullyCharged == true {
            findings.append(Finding(code: "CHG.FULL", severity: .info, subject: subject, title: "충전 완료", detail: "배터리 완충 상태\(percent)", remedy: ""))
        } else if telemetry.isCharging == false {
            let reason = telemetry.notChargingReason.flatMap { $0 != 0 ? "충전 중지 사유 부호 \($0) (0x\(String($0, radix: 16)))" : nil } ?? "사유 부호 없음"
            findings.append(Finding(
                code: "CHG.NOT_CHARGING", severity: .info, subject: subject,
                title: "전원 연결 상태에서 충전 중 아님",
                detail: "\(reason)\(percent). 충전 한도 설정, 최적화된 배터리 충전, 온도 조건에서 나타남",
                remedy: "시스템 설정의 배터리 항목에서 충전 한도와 최적화된 충전 확인"
            ))
        }
        if let slow = telemetry.slowChargingReason, slow != 0 {
            findings.append(Finding(
                code: "CHG.SLOW", severity: .warning, subject: subject,
                title: "저속 충전 상태",
                detail: "저속 충전 사유 부호 \(slow) (0x\(String(slow, radix: 16)))",
                remedy: "출력이 더 큰 충전기와 5 A 케이블 사용"
            ))
        }
        if let inhibit = telemetry.chargerInhibitReason, inhibit != 0 {
            findings.append(Finding(
                code: "CHG.INHIBIT", severity: .info, subject: subject,
                title: "충전 회로 억제 상태",
                detail: "억제 사유 부호 \(inhibit) (0x\(String(inhibit, radix: 16)))",
                remedy: ""
            ))
        }
        if let seconds = telemetry.thermallyLimitedSeconds, seconds > 0 {
            findings.append(Finding(
                code: "CHG.THERMAL", severity: .warning, subject: subject,
                title: "온도로 충전이 제한된 기록",
                detail: "누적 \(seconds)초",
                remedy: "통풍이 되는 곳에서 사용하고 기기 온도를 낮춤"
            ))
        }
        return findings
    }

    /// 전원이 들어오는 포트의 케이블. 연결된 포트에 e-marker가 정확히 1개일 때만 특정.
    public static func powerCable(in inventory: PortInventory) -> CableEMarker? {
        let connected = Set(inventory.ports.filter(\.connectionActive).map(\.key))
        let candidates = inventory.cables.filter { connected.contains($0.port) }
        return candidates.count == 1 ? candidates[0] : nil
    }
}
