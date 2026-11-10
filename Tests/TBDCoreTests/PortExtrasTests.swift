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

/// TC-PRT-005: Thunderbolt 스위치 토폴로지와 레인 구성 판정.
@Suite("TC-PRT-005 스위치 토폴로지와 레인 구성")
struct SwitchTopologyTests {
    @Test func 실측_픽스처의_스위치_목록() throws {
        let inventory = try RegistryFixture.inventory(RegistryFixture.normal)
        #expect(inventory.switches.count == 4)
        #expect(inventory.switches.filter(\.isHost).count == 3)
        let dock = try #require(inventory.switches.first { !$0.isHost })
        #expect(dock.depth == 1)
        #expect(dock.vendorName == "Parade Technologies" && dock.modelName == "PS9010")
        #expect(dock.routePorts == [1])
        #expect(dock.version == 32)
        #expect(dock.summary == "깊이 1, Parade Technologies PS9010, 경로 1, 상향 포트 1, 판 값 32")
        // 깊이 순 정렬: 호스트 라우터가 앞.
        #expect(inventory.switches.map(\.depth) == [0, 0, 0, 1])
    }

    @Test func 경로_문자열_풀이() {
        let deep = ThunderboltSwitch(registryEntryID: 1, depth: 2, routeString: 0x0301, vendorName: nil, modelName: "허브", version: nil, upstreamPort: nil, maxPortNumber: nil, className: "")
        #expect(deep.routePorts == [1, 3])
        #expect(deep.summary == "깊이 2, 허브, 경로 1 → 3")
        #expect(ThunderboltSwitch.decode(["이름": "깊이 없음"]) == nil)
    }

    static func phy(_ transports: [String?]) -> PhyInfo {
        PhyInfo(id: 0, lanes: transports.enumerated().map { .init(name: "Lane \($0.offset)", transport: $0.element, client: nil, powerLevel: nil) }, usb2: nil, dpTunnels: [], dpPixelClocks: [])
    }

    @Test func 레인_구성_판정() throws {
        let inventory = try RegistryFixture.inventory(RegistryFixture.normal)
        let active = try #require(inventory.phys.first { $0.id == 3 })
        #expect(active.laneConfiguration == "Thunderbolt 또는 USB4 (레인 2개 모두 CIO, 영상은 터널로 전달)")
        #expect(Self.phy(["DP", "DP"]).laneConfiguration == "DisplayPort 대체 모드 4레인 (USB3 없음)")
        #expect(Self.phy(["DisplayPort", "USB3"]).laneConfiguration == "DisplayPort 대체 모드 2레인 + USB3")
        #expect(Self.phy(["USB3", "USB3"]).laneConfiguration == "USB3 전용")
        #expect(Self.phy([nil, nil]).laneConfiguration == "고속 레인 미사용")
    }
}
