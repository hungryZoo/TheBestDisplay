import Foundation
import Testing
@testable import TBDCore

extension RegistryFixture {
    static func inventory(_ folder: String) throws -> PortInventory {
        var nodes: [String: [[String: Any]]] = [:]
        // PHY 노드는 칩별 클래스 이름으로 저장한 픽스처 사용.
        for className in PortInventory.relevantClasses + ["AppleT8132TypeCPhy"] {
            // 픽스처에 없는 클래스(이 기기에 없는 노드)는 건너뜀.
            guard let url = Bundle.module.url(forResource: "\(folder)/\(className).plist", withExtension: nil, subdirectory: "Fixtures") else { continue }
            let data = try Data(contentsOf: url)
            nodes[className] = try #require(try PropertyListSerialization.propertyList(from: data, format: nil) as? [[String: Any]])
        }
        return PortInventory.decode(nodesByClass: nodes)
    }

    static let lgTV = DisplaySummary(
        identity: DisplayIdentity(displayID: 2, uuid: "TESTUUID2", vendorID: 7789, productID: 49352, serialNumber: 16843009, name: "LG TV SSCR2", isBuiltin: false),
        isMain: true, isActive: true, mirrorsDisplayID: nil, pointWidth: 2304, pointHeight: 1296, pixelWidth: 4608, pixelHeight: 2592,
        refreshRate: 120, rotationDegrees: 0, originX: 0, originY: 0, physicalWidthMM: 1600, physicalHeightMM: 900
    )
    static let builtin = DisplaySummary(
        identity: DisplayIdentity(displayID: 1, uuid: "TESTUUID1", vendorID: 1552, productID: 41054, serialNumber: 1, name: "내장 디스플레이", isBuiltin: true),
        isMain: false, isActive: true, mirrorsDisplayID: nil, pointWidth: 1512, pointHeight: 982, pixelWidth: 3024, pixelHeight: 1964,
        refreshRate: 120, rotationDegrees: 0, originX: 0, originY: 0, physicalWidthMM: 301, physicalHeightMM: 196
    )
}

/// TC-PRT-001 일부: 포트, 케이블, 독 노드 해석 (픽스처).
@Suite("TC-PRT-001 포트와 케이블 해석")
struct PortInventoryTests {
    @Test func 포트_목록() throws {
        let inventory = try RegistryFixture.inventory(RegistryFixture.normal)
        #expect(inventory.ports.map(\.key.label) == ["USB-C 1번", "USB-C 2번", "HDMI 3번", "USB-C 4번", "MagSafe 3 1번"])
        let port4 = try #require(inventory.ports.first { $0.key == PortKey(type: "USB-C", number: 4) })
        #expect(port4.connectionActive)
        #expect(port4.transportsSupported == ["CC", "USB2", "USB3", "CIO", "DisplayPort"])
        #expect(port4.transportsActive == ["CC", "USB2", "CIO"])
        #expect(port4.partnerManufacturer == "Parade Tech Inc.")
        #expect(port4.supportsDisplay)
        #expect(port4.activeCable == false)
        let hdmi = try #require(inventory.ports.first { $0.key.type == "HDMI" })
        #expect(!hdmi.connectionActive)
        #expect(hdmi.hpdAsserted == false)
        #expect(hdmi.supportsDisplay)
        let magsafe = try #require(inventory.ports.first { $0.key.type == "MagSafe 3" })
        #expect(!magsafe.supportsDisplay)
    }

    @Test func 케이블_e_marker_해석() throws {
        let inventory = try RegistryFixture.inventory(RegistryFixture.normal)
        let cable = try #require(inventory.cables.first)
        #expect(cable.port == PortKey(type: "USB-C", number: 4))
        #expect(cable.productType == "Passive Cable")
        // 케이블 VDO 0x000A6644: 속도 부호 4, 전류 부호 2, 전압 부호 3, EPR.
        #expect(cable.speedCode == 4)
        #expect(cable.speedName == "USB4 Gen 4 (80 Gbps)")
        #expect(cable.currentName == "5 A")
        #expect(cable.maxVoltage == 50)
        #expect(cable.eprCapable)
        #expect(cable.supportsHighSpeedData)
    }

    @Test func 독과_터널_해석() throws {
        let inventory = try RegistryFixture.inventory(RegistryFixture.normal)
        let cio = try #require(inventory.cioStates.first)
        #expect(cio.port == PortKey(type: "USB-C", number: 4))
        #expect(cio.isActive)
        #expect(cio.deviceName == "Parade Technologies PS9010")
        #expect(cio.generation == 3)
        #expect(cio.generationName == "USB4 Gen 3 (40 Gbps)")
        #expect(cio.tunneledTransportsProvisioned == ["DisplayPort", "PCIe"])
        #expect(cio.tunneledTransportsSupported == ["USB3", "DisplayPort", "PCIe"])
        let usb = try #require(inventory.usbStates.first)
        #expect(usb.product == "USB2.0 Hub")
        #expect(usb.dataRate == "480 Mbps (High Speed)")
    }

    @Test func 노드가_없거나_잘못된_입력() {
        let empty = PortInventory.decode(nodesByClass: [:])
        #expect(empty.ports.isEmpty)
        #expect(ConnectionPathBuilder.build(inventory: empty, displays: []).isEmpty)
        #expect(PortInfo.decode(["PortNumber": 1]) == nil)
        #expect(CableEMarker.decode(["ParentPortTypeDescription": "USB-C", "ParentPortNumber": 1, "Metadata": ["VDOs": [Data([1, 2, 3, 4])]]]) == nil)
        #expect(CIOState.decode(["Generation": 3]) == nil)
    }

    @Test func 케이블_속도_부호_이름() {
        func cable(_ speed: Int, current: Int = 1) -> CableEMarker {
            CableEMarker(port: PortKey(type: "USB-C", number: 1), productType: "Passive Cable", vendorID: 0, speedCode: speed, currentCode: current, maxVoltageCode: 0, eprCapable: false)
        }
        #expect(cable(0).speedName.hasPrefix("USB 2.0 전용"))
        #expect(!cable(0).supportsHighSpeedData)
        #expect(cable(3).speedName == "USB4 Gen 3 (40 Gbps)")
        #expect(cable(1).currentName == "3 A")
        #expect(cable(1).maxVoltage == 20)
    }
}

/// TC-PRT-002: 연결 경로 조립.
@Suite("TC-PRT-002 연결 경로")
struct ConnectionPathTests {
    @Test func 정상_상태의_경로() throws {
        let inventory = try RegistryFixture.inventory(RegistryFixture.normal)
        let paths = ConnectionPathBuilder.build(inventory: inventory, displays: [RegistryFixture.lgTV, RegistryFixture.builtin])
        #expect(paths.count == 5)
        let reaching = paths.filter(\.reachesDisplay)
        #expect(reaching.count == 1)
        let path = try #require(reaching.first)
        #expect(path.port.key == PortKey(type: "USB-C", number: 4))
        #expect(path.displayID == 2)
        #expect(path.steps.map(\.kind) == [.port, .phy, .cable, .dock, .link, .display])
        #expect(path.steps.allSatisfy { $0.status == .ok })
        #expect(path.steps[0].detail.contains("플러그 방향 2"))
        #expect(path.steps[1].title == "PHY 3")
        #expect(path.steps[1].detail == "레인 0 CIO, 레인 1 CIO, USB2 사용, DP 터널 8.10Gbps/lane (HBR3). 구성: Thunderbolt 또는 USB4 (레인 2개 모두 CIO, 영상은 터널로 전달)")
        #expect(path.summary == "USB-C 4번 → 케이블 → Parade Technologies PS9010 → HBR3 x 4 → LG TV SSCR2")
        #expect(path.steps[4].detail.contains("터널링"))

        // 빈 포트는 포트 단계만.
        let empty = try #require(paths.first { $0.port.key == PortKey(type: "USB-C", number: 1) })
        #expect(!empty.isConnected)
        #expect(empty.steps.map(\.kind) == [.port])
        #expect(empty.steps[0].detail.hasPrefix("연결 없음"))
        let hdmi = try #require(paths.first { $0.port.key.type == "HDMI" })
        #expect(!hdmi.isConnected)
    }

    @Test func 사고_시점은_링크_단계에서_끊김() throws {
        let inventory = try RegistryFixture.inventory(RegistryFixture.noLink)
        // 사고 중 온라인 디스플레이는 내장 1대뿐.
        let paths = ConnectionPathBuilder.build(inventory: inventory, displays: [RegistryFixture.builtin])
        let path = try #require(paths.first { $0.port.key == PortKey(type: "USB-C", number: 4) })
        #expect(path.isConnected)
        #expect(!path.reachesDisplay)
        #expect(path.steps.map(\.kind) == [.port, .phy, .cable, .dock, .link])
        let link = try #require(path.steps.last)
        #expect(link.status == .broken)
        #expect(link.title == "링크 없음")
        #expect(link.detail.contains("HPD는 감지"))
        // 독까지는 정상.
        #expect(path.steps.prefix(3).allSatisfy { $0.status == .ok })
    }

    @Test func 링크는_있으나_온라인_목록에_없는_디스플레이() throws {
        let inventory = try RegistryFixture.inventory(RegistryFixture.normal)
        let paths = ConnectionPathBuilder.build(inventory: inventory, displays: [RegistryFixture.builtin])
        let path = try #require(paths.first { $0.port.key == PortKey(type: "USB-C", number: 4) })
        #expect(!path.reachesDisplay)
        let last = try #require(path.steps.last)
        #expect(last.kind == .display)
        #expect(last.status == .broken)
        #expect(last.title == "LG TV SSCR2")
    }
}
