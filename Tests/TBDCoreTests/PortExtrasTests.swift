import Foundation
import Testing
@testable import TBDCore

/// TC-PRT-003: 플러그 방향, PHY 레인, 전원 어댑터 해석.
@Suite("TC-PRT-003 플러그 방향, PHY, 전원 어댑터")
struct PortExtrasTests {
    @Test func 실측_픽스처의_플러그_방향() throws {
        let inventory = try RegistryFixture.inventory(RegistryFixture.normal)
        let connected = try #require(inventory.ports.first { $0.key == PortKey(type: "USB-C", number: 4) })
        #expect(connected.plugOrientation == 2)
        let empty = try #require(inventory.ports.first { $0.key == PortKey(type: "USB-C", number: 1) })
        #expect(empty.plugOrientation == 0)
        // HDMI 포트 노드에는 방향 속성이 없음.
        #expect(inventory.ports.first { $0.key.type == "HDMI" }?.plugOrientation == nil)
    }

    @Test func 실측_픽스처의_PHY_레인() throws {
        let inventory = try RegistryFixture.inventory(RegistryFixture.normal)
        #expect(inventory.phys.map(\.id) == [0, 1, 2, 3])
        let active = try #require(inventory.phys.first { $0.id == 3 })
        #expect(active.portNumber == 4)
        #expect(active.isActive)
        #expect(active.lanes.map(\.name) == ["Lane 0", "Lane 1"])
        #expect(active.lanes.allSatisfy { $0.transport == "CIO" && $0.powerLevel == "on" && $0.client == "AppleThunderboltNHIType7" })
        #expect(active.usb2?.transport == "USB2")
        #expect(active.dpTunnels.first?.linkRate == "8.10Gbps/lane (HBR3)")
        #expect(active.dpPixelClocks.first?.clients == ["AppleATCDPINAdapterPort(atc3-dpin0)"])
        #expect(active.summary == "레인 0 CIO, 레인 1 CIO, USB2 사용, DP 터널 8.10Gbps/lane (HBR3)")

        let idle = try #require(inventory.phys.first { $0.id == 0 })
        #expect(!idle.isActive)
        #expect(idle.usb2 == nil)
        #expect(idle.summary == "레인 0 미사용, 레인 1 미사용")
        #expect(PhyInfo.decode(["IOClass": "다른 노드"]) == nil)
    }

    @Test func 전원_어댑터_해석() {
        // 합성 자료: 배터리 노드의 어댑터 속성 (전압 mV, 전류 mA).
        let node: [String: Any] = [
            "ExternalConnected": true,
            "AdapterDetails": [
                "Watts": 96, "AdapterVoltage": 20000, "Current": 4800, "Name": "96W USB-C Power Adapter", "Manufacturer": "Apple Inc.", "IsWireless": false,
                "UsbHvcMenu": [
                    ["Index": 0, "MaxVoltage": 5000, "MaxCurrent": 3000],
                    ["Index": 1, "MaxVoltage": 9000, "MaxCurrent": 3000],
                    ["Index": 2, "MaxVoltage": 20000, "MaxCurrent": 4800],
                ],
            ] as [String: Any],
        ]
        let adapter = PowerAdapterInfo.decode(node)
        #expect(adapter.isConnected)
        #expect(adapter.watts == 96)
        #expect(adapter.voltage == 20 && adapter.current == 4.8)
        #expect(adapter.options.count == 3)
        #expect(adapter.options[2].watts == 96)
        #expect(adapter.summary == "96 W, 협상 20.0 V, 4.80 A, 96W USB-C Power Adapter, Apple Inc., 전원 옵션 5 V 3 A, 9 V 3 A, 20 V 4.8 A")
    }

    @Test func 전원_어댑터_미연결() {
        // 실측: 충전기 미연결 상태의 속성.
        let adapter = PowerAdapterInfo.decode(["ExternalConnected": false, "AdapterDetails": ["FamilyCode": 0]])
        #expect(!adapter.isConnected)
        #expect(adapter.watts == nil && adapter.options.isEmpty)
        #expect(adapter.summary == "연결 없음")
        #expect(PowerAdapterInfo.decode([:]).isConnected == false)
    }
}
