import Foundation
import Testing
@testable import TBDCore

/// TC-PRT-009: 케이블 e-marker 식별 정보와 신뢰 신호.
@Suite("TC-PRT-009 케이블 식별 정보와 신뢰 신호")
struct CableTrustTests {
    static func vdo(_ value: UInt32) -> Data { withUnsafeBytes(of: value.littleEndian) { Data($0) } }

    static func node(vdos: [UInt32], vendor: Int? = nil, product: Int? = nil, type: String = "Passive Cable") -> [String: Any] {
        var node: [String: Any] = [
            "ParentPortTypeDescription": "USB-C", "ParentPortNumber": 4, "Product Type Description": type,
            "Metadata": ["VDOs": vdos.map(Self.vdo)],
        ]
        if let vendor { node["Vendor ID"] = vendor }
        if let product { node["Product ID"] = product }
        return node
    }

    /// 실측 (T56): 독에 연결한 케이블. ID 헤더 0x1C600000, 인증과 제품 VDO 0, 케이블 VDO 0x000A6644.
    static let measured = node(vdos: [0x1C60_0000, 0, 0, 0x000A_6644], vendor: 0, product: 0)

    @Test func 실측_케이블_해석() throws {
        let cable = try #require(CableEMarker.decode(Self.measured))
        #expect(cable.vendorID == 0 && cable.certificationID == 0 && cable.productID == 0)
        #expect(cable.speedCode == 4 && cable.currentCode == 2 && cable.maxVoltage == 50 && cable.eprCapable)
        #expect(cable.latencyCode == 3)
        #expect(cable.latencyName == "20-30 ns (약 3 m)")
        #expect(cable.hardwareVersion == 0 && cable.firmwareVersion == 0)
        #expect(cable.isPassive)
    }

    @Test func 실측_케이블의_신뢰_신호_3건() throws {
        let cable = try #require(CableEMarker.decode(Self.measured))
        #expect(CableTrust.identity(cable) == "제조사 ID 미기재, USB-IF 인증 ID 미기재, 지연 20-30 ns (약 3 m)")
        let signals = CableTrust.signals(cable)
        #expect(signals.count == 3)
        #expect(signals[0] == "제조사 ID가 없어 제조사를 확인할 수 없음")
        #expect(signals[1] == "USB-IF 인증 ID가 없어 e-marker로는 인증 여부를 확인할 수 없음")
        #expect(signals[2].hasPrefix("패시브 케이블이 USB4 Gen 4 (80 Gbps) 속도와 지연 20-30 ns (약 3 m)를 함께 표기"))
    }

    @Test func 기록이_갖춰진_케이블은_신호_없음() throws {
        // 제조사 0x05AC, 인증 ID 12345, 제품 0x7209 판 0x0100, 케이블 VDO: 하드웨어 1, 펌웨어 2, EPR, 지연 1, 50 V, 5 A, USB4 Gen 3.
        let cableVDO: UInt32 = (1 << 28) | (2 << 24) | (1 << 17) | (1 << 13) | (3 << 9) | (2 << 5) | 3
        let cable = try #require(CableEMarker.decode(Self.node(vdos: [0x1800_05AC, 12345, 0x7209_0100, cableVDO])))
        #expect(cable.vendorID == 0x05AC)
        #expect(cable.certificationID == 12345)
        #expect(cable.productID == 0x7209 && cable.deviceVersion == 0x0100)
        #expect(cable.hardwareVersion == 1 && cable.firmwareVersion == 2)
        #expect(CableTrust.signals(cable).isEmpty)
        #expect(CableTrust.identity(cable) == "제조사 Apple (0x05AC), 제품 0x7209, USB-IF 인증 ID 12345, 지연 10 ns 미만 (약 1 m)")
    }

    @Test func 목록에_없는_제조사는_ID만_표기() {
        let cable = CableEMarker(port: PortKey(type: "USB-C", number: 1), productType: "Passive Cable", vendorID: 0x1234, speedCode: 1, currentCode: 1, maxVoltageCode: 0, eprCapable: false, certificationID: 7, latencyCode: 2)
        #expect(CableTrust.identity(cable) == "제조사 0x1234, USB-IF 인증 ID 7, 지연 10-20 ns (약 2 m)")
        #expect(CableTrust.vendorName(0x1234) == nil)
        // USB 3.2 Gen 1 패시브 케이블의 2 m는 신호 아님.
        #expect(CableTrust.signals(cable).isEmpty)
    }

    @Test func 제조사_ID_0xFFFF도_미기재() {
        let cable = CableEMarker(port: PortKey(type: "USB-C", number: 1), productType: "Passive Cable", vendorID: 0xFFFF, speedCode: 1, currentCode: 1, maxVoltageCode: 0, eprCapable: false, certificationID: 7, latencyCode: 1)
        #expect(!CableTrust.hasVendorID(cable))
        #expect(CableTrust.signals(cable) == ["제조사 ID가 없어 제조사를 확인할 수 없음"])
    }

    @Test func EPR_표기와_정격_불일치() {
        func cable(current: Int, voltage: Int) -> CableEMarker {
            CableEMarker(port: PortKey(type: "USB-C", number: 1), productType: "Passive Cable", vendorID: 0x05AC, speedCode: 1, currentCode: current, maxVoltageCode: voltage, eprCapable: true, certificationID: 1, latencyCode: 1)
        }
        #expect(CableTrust.signals(cable(current: 2, voltage: 3)).isEmpty)
        #expect(CableTrust.signals(cable(current: 1, voltage: 3)) == ["EPR 지원 표기와 정격(3 A, 최대 50 V)이 맞지 않음"])
        #expect(CableTrust.signals(cable(current: 2, voltage: 0)) == ["EPR 지원 표기와 정격(5 A, 최대 20 V)이 맞지 않음"])
    }

    @Test func 지연_시간_부호() {
        func cable(_ latency: Int, type: String = "Passive Cable", speed: Int = 1) -> CableEMarker {
            CableEMarker(port: PortKey(type: "USB-C", number: 1), productType: type, vendorID: 0x05AC, speedCode: speed, currentCode: 1, maxVoltageCode: 0, eprCapable: false, certificationID: 1, latencyCode: latency)
        }
        #expect(cable(1).latencyName == "10 ns 미만 (약 1 m)")
        #expect(cable(7).latencyName == "60-70 ns (약 7 m)")
        #expect(cable(8).latencyName == "70 ns 초과 (7 m 초과)")
        #expect(cable(0).latencyName == nil)
        #expect(CableTrust.signals(cable(0)) == ["지연 시간 부호(0)가 규격 범위 밖"])
        #expect(CableTrust.signals(cable(12)) == ["지연 시간 부호(12)가 규격 범위 밖"])
        // 액티브 케이블은 길이 한도 판정 대상 아님. 패시브 USB4 Gen 3의 1 m 이내 표기도 신호 아님.
        #expect(CableTrust.signals(cable(3, type: "Active Cable", speed: 3)).isEmpty)
        #expect(CableTrust.signals(cable(1, speed: 3)).isEmpty)
        #expect(CableTrust.signals(cable(2, speed: 3)).count == 1)
    }

    @Test func 연결_경로의_케이블_단계에_식별_정보와_신호_포함() throws {
        let cable = try #require(CableEMarker.decode(Self.measured))
        let port = try #require(PortInfo.decode(["PortTypeDescription": "USB-C", "PortNumber": 4, "ConnectionActive": true, "TransportsSupported": ["CC", "DisplayPort"]]))
        let inventory = PortInventory(ports: [port], dpStates: [], cioStates: [], usbStates: [], cables: [cable])
        let path = try #require(ConnectionPathBuilder.build(inventory: inventory, displays: []).first)
        let step = try #require(path.steps.first { $0.kind == .cable })
        #expect(step.detail.contains("제조사 ID 미기재, USB-IF 인증 ID 미기재"))
        #expect(step.detail.contains("신뢰 신호: 제조사 ID가 없어"))
        #expect(step.status == .ok)
    }
}
