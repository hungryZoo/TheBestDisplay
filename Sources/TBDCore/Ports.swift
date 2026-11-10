import Foundation

// 포트, 케이블, 독, 연결 경로 모델. IORegistry 노드 속성 사전에서 구성. (SRS-PRT-001, SRS-PRT-002)

private func intValue(_ node: [String: Any], _ key: String) -> Int? { (node[key] as? NSNumber)?.intValue }
private func boolValue(_ node: [String: Any], _ key: String) -> Bool? { (node[key] as? NSNumber)?.boolValue }
private func strings(_ node: [String: Any], _ key: String) -> [String] { node[key] as? [String] ?? [] }

/// 물리 포트의 조인 키: 종류와 번호. 예: USB-C 4번.
public struct PortKey: Codable, Hashable, Sendable {
    public var type: String
    public var number: Int

    public init(type: String, number: Int) {
        self.type = type
        self.number = number
    }

    public var label: String { "\(type) \(number)번" }

    /// 전송 상태와 부속 노드의 부모 포트 속성에서 구성.
    static func parent(of node: [String: Any]) -> PortKey? {
        guard let type = node["ParentPortTypeDescription"] as? String, let number = intValue(node, "ParentPortNumber") else { return nil }
        return PortKey(type: type, number: number)
    }
}

/// 물리 포트 1개. (PRD-PRT-001)
public struct PortInfo: Codable, Hashable, Sendable, Identifiable {
    public var key: PortKey
    /// 예: "Port-USB-C@4"
    public var portDescription: String
    public var connectionActive: Bool
    public var transportsSupported: [String]
    public var transportsActive: [String]
    public var transportsProvisioned: [String]
    /// 포트 컨트롤러가 보고한 HPD. HDMI 포트는 `HDMI_HPD`.
    public var hpdAsserted: Bool?
    public var activeCable: Bool?
    public var opticalCable: Bool?
    /// 연결 상대의 제조사 문자열 (USB-PD SOP).
    public var partnerManufacturer: String?
    public var plugEventCount: Int?
    public var connectionCount: Int?
    public var overcurrentCount: Int?

    public var id: String { portDescription }
    public var supportsDisplay: Bool { transportsSupported.contains("DisplayPort") }

    public static func decode(_ node: [String: Any]) -> PortInfo? {
        guard let type = node["PortTypeDescription"] as? String, let number = intValue(node, "PortNumber") else { return nil }
        let manufacturer = (node["SOPMfgString"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return PortInfo(
            key: PortKey(type: type, number: number),
            portDescription: node["PortDescription"] as? String ?? "Port-\(type)@\(number)",
            connectionActive: boolValue(node, "ConnectionActive") ?? false,
            transportsSupported: strings(node, "TransportsSupported"),
            transportsActive: strings(node, "TransportsActive"),
            transportsProvisioned: strings(node, "TransportsProvisioned"),
            hpdAsserted: boolValue(node, "HPDAsserted") ?? boolValue(node, "HDMI_HPD"),
            activeCable: boolValue(node, "ActiveCable"),
            opticalCable: boolValue(node, "OpticalCable"),
            partnerManufacturer: manufacturer?.isEmpty == false ? manufacturer : nil,
            plugEventCount: intValue(node, "Plug Event Count"),
            connectionCount: intValue(node, "ConnectionCount"),
            overcurrentCount: intValue(node, "Overcurrent Count")
        )
    }
}

/// 케이블 e-marker (USB-PD SOP' 응답). e-marker가 없는 케이블은 정보 없음. (PRD-PRT-002)
/// 케이블 VDO 필드 해석은 USB Power Delivery 규격의 Passive Cable VDO 정의 기준.
public struct CableEMarker: Codable, Hashable, Sendable {
    public var port: PortKey
    /// 예: "Passive Cable", "Active Cable"
    public var productType: String
    public var vendorID: Int
    /// USB 최고 속도 부호 (케이블 VDO 비트 2-0).
    public var speedCode: Int
    /// 전류 정격 부호 (비트 6-5). 1은 3 A, 2는 5 A.
    public var currentCode: Int
    /// 최대 전압 부호 (비트 10-9). 0은 20 V, 3은 50 V.
    public var maxVoltageCode: Int
    public var eprCapable: Bool

    public var speedName: String {
        switch speedCode {
        case 0: "USB 2.0 전용 (480 Mbps)"
        case 1: "USB 3.2 Gen 1 (5 Gbps)"
        case 2: "USB 3.2 Gen 2, USB4 Gen 2 (10 Gbps, 2레인 20 Gbps)"
        case 3: "USB4 Gen 3 (40 Gbps)"
        case 4: "USB4 Gen 4 (80 Gbps)"
        default: "알 수 없음 (\(speedCode))"
        }
    }

    public var currentName: String {
        switch currentCode {
        case 1: "3 A"
        case 2: "5 A"
        default: "미표기"
        }
    }

    public var maxVoltage: Int { [20, 30, 40, 50][safe: maxVoltageCode] ?? 20 }

    /// 고속 영상 신호(DisplayPort 대체 모드, 터널링)를 실을 수 있는 등급인지. USB 2.0 전용 케이블은 불가.
    public var supportsHighSpeedData: Bool { speedCode >= 1 }

    public static func decode(_ node: [String: Any]) -> CableEMarker? {
        guard let port = PortKey.parent(of: node) else { return nil }
        let metadata = node["Metadata"] as? [String: Any] ?? [:]
        let vdos = (metadata["VDOs"] as? [Data] ?? []).map { data -> UInt32 in
            data.count >= 4 ? data.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }.littleEndian : 0
        }
        // VDO 순서: ID 헤더, 인증, 제품, 케이블 VDO.
        guard vdos.count >= 4 else { return nil }
        let cable = vdos[3]
        return CableEMarker(
            port: port,
            productType: node["Product Type Description"] as? String ?? "미확인",
            vendorID: intValue(node, "Vendor ID") ?? Int(vdos[0] & 0xFFFF),
            speedCode: Int(cable & 0x7),
            currentCode: Int((cable >> 5) & 0x3),
            maxVoltageCode: Int((cable >> 9) & 0x3),
            eprCapable: (cable >> 17) & 0x1 == 1
        )
    }
}

/// Thunderbolt 또는 USB4 전송 상태. 독과 터널 정보. (PRD-PRT-002)
public struct CIOState: Codable, Hashable, Sendable {
    public var port: PortKey
    public var transportDescription: String
    public var isActive: Bool
    /// 링크 세대 원시 값. USB4 규격 명칭 기준으로 2는 Gen 2(20 Gbps), 3은 Gen 3(40 Gbps), 4는 Gen 4(80 Gbps).
    public var generation: Int?
    public var cableGeneration: Int?
    public var cableSpeed: Int?
    public var deviceVendor: String?
    public var deviceModel: String?
    public var tunneledTransportsSupported: [String]
    public var tunneledTransportsProvisioned: [String]
    public var legacyAdapter: Bool?
    public var trmState: String?

    public var deviceName: String? {
        let parts = [deviceVendor, deviceModel].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    public var generationName: String {
        switch generation {
        case 2?: "USB4 Gen 2 (20 Gbps)"
        case 3?: "USB4 Gen 3 (40 Gbps)"
        case 4?: "USB4 Gen 4 (80 Gbps)"
        case let value?: "세대 \(value)"
        case nil: "미확인"
        }
    }

    public static func decode(_ node: [String: Any]) -> CIOState? {
        guard let port = PortKey.parent(of: node), let description = node["TransportDescription"] as? String else { return nil }
        return CIOState(
            port: port, transportDescription: description,
            isActive: boolValue(node, "Active") ?? false,
            generation: intValue(node, "Generation"),
            cableGeneration: intValue(node, "CableGeneration"),
            cableSpeed: intValue(node, "CableSpeed"),
            deviceVendor: node["Device Vendor Name"] as? String,
            deviceModel: node["Device Model Name"] as? String,
            tunneledTransportsSupported: strings(node, "TunneledTransportsSupported"),
            tunneledTransportsProvisioned: strings(node, "TunneledTransportsProvisioned"),
            legacyAdapter: boolValue(node, "LegacyAdapter"),
            trmState: node["TRM_StateDescription"] as? String
        )
    }
}

/// USB 전송 상태 (USB2, USB3).
public struct USBState: Codable, Hashable, Sendable {
    public var port: PortKey
    public var transportDescription: String
    public var isActive: Bool
    public var generation: String?
    public var dataRate: String?
    public var product: String?
    public var manufacturer: String?

    public static func decode(_ node: [String: Any]) -> USBState? {
        guard let port = PortKey.parent(of: node), let description = node["TransportDescription"] as? String else { return nil }
        return USBState(
            port: port, transportDescription: description,
            isActive: boolValue(node, "Active") ?? false,
            generation: node["GenerationDescription"] as? String,
            dataRate: (node["DataRateDescription"] as? String) ?? (node["SuperSpeedSignalingDescription"] as? String),
            product: node["Product"] as? String,
            manufacturer: node["Manufacturer"] as? String
        )
    }
}

/// 포트 관련 노드 전체. 조회 결과의 전달 단위.
public struct PortInventory: Codable, Hashable, Sendable {
    public var ports: [PortInfo]
    public var dpStates: [DPTransportState]
    public var cioStates: [CIOState]
    public var usbStates: [USBState]
    public var cables: [CableEMarker]

    public init(ports: [PortInfo], dpStates: [DPTransportState], cioStates: [CIOState], usbStates: [USBState], cables: [CableEMarker]) {
        self.ports = ports
        self.dpStates = dpStates
        self.cioStates = cioStates
        self.usbStates = usbStates
        self.cables = cables
    }

    /// 클래스 이름별 노드 속성 사전에서 구성. 포트 컨트롤러 클래스는 칩 세대에 따라 다르므로 `PortTypeDescription`이 있는 노드를 전부 포트로 취급.
    public static func decode(nodesByClass: [String: [[String: Any]]]) -> PortInventory {
        var ports: [PortInfo] = []
        var seen = Set<String>()
        for (className, nodes) in nodesByClass.sorted(by: { $0.key < $1.key }) where className.hasPrefix("AppleHPMInterface") || className.hasPrefix("AppleTCController") || className == "AppleHDMIPortController" {
            for port in nodes.compactMap(PortInfo.decode) where seen.insert(port.portDescription).inserted {
                ports.append(port)
            }
        }
        ports.sort { ($0.key.type == "MagSafe 3" ? 1 : 0, $0.key.number, $0.key.type) < ($1.key.type == "MagSafe 3" ? 1 : 0, $1.key.number, $1.key.type) }
        return PortInventory(
            ports: ports,
            dpStates: (nodesByClass["IOPortTransportStateDisplayPort"] ?? []).compactMap(DPTransportState.decode),
            cioStates: (nodesByClass["IOPortTransportStateCIO"] ?? []).compactMap(CIOState.decode),
            usbStates: ((nodesByClass["IOPortTransportStateUSB2"] ?? []) + (nodesByClass["IOPortTransportStateUSB3"] ?? [])).compactMap(USBState.decode),
            cables: (nodesByClass["IOPortTransportComponentCCUSBPDSOPp"] ?? []).compactMap(CableEMarker.decode)
        )
    }

    public static let relevantClasses = [
        "AppleHPMInterfaceType10", "AppleHPMInterfaceType11", "AppleHPMInterfaceType12", "AppleHPMInterfaceType18",
        "AppleTCControllerType10", "AppleTCControllerType11", "AppleHDMIPortController",
        "IOPortTransportStateDisplayPort", "IOPortTransportStateCIO", "IOPortTransportStateUSB2", "IOPortTransportStateUSB3",
        "IOPortTransportComponentCCUSBPDSOPp",
    ]
}

/// 연결 경로의 한 단계. (PRD-PRT-003)
public struct PathStep: Codable, Hashable, Sendable, Identifiable {
    public enum Kind: String, Codable, Sendable { case port, cable, dock, link, display }
    public enum Status: String, Codable, Sendable {
        /// 정상.
        case ok
        /// 정보 없음 또는 해당 없음.
        case unknown
        /// 이 단계에서 연결이 끊김.
        case broken
    }

    public var kind: Kind
    public var title: String
    public var detail: String
    public var status: Status

    public var id: String { kind.rawValue }
}

/// 포트 1개의 연결 경로: 포트, 케이블, 독, 링크, 디스플레이 순서.
public struct ConnectionPath: Codable, Hashable, Sendable, Identifiable {
    public var port: PortInfo
    public var cable: CableEMarker?
    public var cio: CIOState?
    public var usb: [USBState]
    public var dp: DPTransportState?
    public var displayID: UInt32?
    public var displayName: String?
    public var steps: [PathStep]

    public var id: String { port.portDescription }
    /// 디스플레이까지 이어진 경로인지.
    public var reachesDisplay: Bool { displayID != nil }
    /// 포트에 무언가 연결되었는지.
    public var isConnected: Bool { port.connectionActive || port.hpdAsserted == true || dp?.hpdAsserted == true }

    /// 한 줄 요약. 예: "USB-C 4번 → Parade Technologies PS9010 → HBR3 x 4 → LG TV SSCR2"
    public var summary: String {
        steps.filter { $0.status != .unknown || $0.kind == .port }.map(\.title).joined(separator: " → ")
    }
}

public enum ConnectionPathBuilder {
    /// 포트마다 연결 경로 1개 구성. 디스플레이 대응은 전송 상태의 제품 정보와 디스플레이 식별 정보 대조.
    public static func build(inventory: PortInventory, displays: [DisplaySummary]) -> [ConnectionPath] {
        inventory.ports.map { port in
            let cable = inventory.cables.first { $0.port == port.key }
            let cio = inventory.cioStates.first { $0.port == port.key && $0.isActive } ?? inventory.cioStates.first { $0.port == port.key }
            let usb = inventory.usbStates.filter { $0.port == port.key && $0.isActive }
            let candidates = inventory.dpStates.filter { $0.parentPortType == port.key.type && $0.parentPortNumber == port.key.number }
            let dp = candidates.first(where: \.isActive) ?? candidates.first(where: \.hpdAsserted) ?? candidates.first
            let externals = displays.filter { !$0.identity.isBuiltin }
            var display: DisplaySummary?
            if let dp, dp.isActive {
                let activeCount = inventory.dpStates.filter(\.isActive).count
                display = externals.first { dp.matches($0.identity) } ?? (activeCount == 1 && externals.count == 1 ? externals.first : nil)
            }
            return ConnectionPath(
                port: port, cable: cable, cio: cio, usb: usb, dp: dp,
                displayID: display?.id, displayName: display?.identity.name,
                steps: steps(port: port, cable: cable, cio: cio, usb: usb, dp: dp, display: display)
            )
        }
    }

    static func steps(port: PortInfo, cable: CableEMarker?, cio: CIOState?, usb: [USBState], dp: DPTransportState?, display: DisplaySummary?) -> [PathStep] {
        var result: [PathStep] = []
        let connected = port.connectionActive || port.hpdAsserted == true || dp?.hpdAsserted == true

        // (1) 포트
        var portDetail = connected ? "연결 감지" : "연결 없음"
        if !port.transportsActive.isEmpty { portDetail += ", 활성 전송: \(port.transportsActive.joined(separator: ", "))" }
        if !port.supportsDisplay { portDetail += ", 영상 출력 미지원 포트" }
        result.append(.init(kind: .port, title: port.key.label, detail: portDetail, status: connected ? .ok : .unknown))
        guard connected else { return result }

        // (2) 케이블
        if let cable {
            let detail = "\(cable.productType), \(cable.speedName), \(cable.currentName), 최대 \(cable.maxVoltage) V\(cable.eprCapable ? ", EPR 지원" : "")"
            result.append(.init(kind: .cable, title: "케이블", detail: detail, status: cable.supportsHighSpeedData ? .ok : .broken))
        } else if port.key.type == "USB-C" {
            result.append(.init(kind: .cable, title: "케이블", detail: "e-marker 응답 없음 (e-marker가 없는 케이블이거나 케이블 일체형 장치)", status: .unknown))
        }

        // (3) 독 또는 터널
        if let cio, cio.isActive {
            var detail = "\(cio.generationName) 링크"
            if !cio.tunneledTransportsProvisioned.isEmpty { detail += ", 터널: \(cio.tunneledTransportsProvisioned.joined(separator: ", "))" }
            if let state = cio.trmState { detail += ", 액세서리 보안 상태: \(state)" }
            let hasDPTunnel = cio.tunneledTransportsProvisioned.contains("DisplayPort")
            result.append(.init(kind: .dock, title: cio.deviceName ?? "Thunderbolt 또는 USB4 장치", detail: detail, status: hasDPTunnel || dp?.isActive == true ? .ok : .unknown))
        } else if let hub = usb.first(where: { $0.product != nil }), dp == nil || dp?.isTunneled == false {
            result.append(.init(kind: .dock, title: [hub.manufacturer, hub.product].compactMap { $0 }.joined(separator: " "), detail: "USB 장치 (\(hub.dataRate ?? hub.generation ?? "속도 미확인"))", status: .unknown))
        }

        // (4) DP 링크
        guard port.supportsDisplay || dp != nil else { return result }
        if let dp {
            if dp.hasLink, dp.isActive {
                let rate = dp.laneRateGbps.map { DPTransportState.rateName($0) } ?? dp.linkRateDescription
                result.append(.init(kind: .link, title: "\(rate) x \(dp.laneCount)", detail: "DisplayPort 링크 \(dp.linkRateDescription), 레인 \(dp.laneCount)개\(dp.isTunneled ? ", 터널링" : ""), HPD \(dp.hpdDescription)", status: .ok))
            } else if dp.hpdAsserted {
                result.append(.init(kind: .link, title: "링크 없음", detail: "HPD는 감지되었으나 DisplayPort 링크가 수립되지 않음 (싱크 수 \(dp.sinkCount))", status: .broken))
            } else {
                result.append(.init(kind: .link, title: "영상 신호 없음", detail: "연결 상대가 디스플레이 연결(HPD)을 알리지 않음", status: port.key.type == "HDMI" || dp.isTunneled ? .broken : .unknown))
            }
        } else {
            result.append(.init(kind: .link, title: "영상 신호 없음", detail: "DisplayPort 전송 상태 노드 없음", status: .unknown))
        }

        // (5) 디스플레이
        if let display {
            result.append(.init(kind: .display, title: display.identity.name, detail: display.modeDescription, status: .ok))
        } else if let dp, dp.isActive, dp.hasLink {
            result.append(.init(kind: .display, title: dp.productName ?? "디스플레이", detail: "링크는 수립되었으나 시스템의 온라인 디스플레이 목록에 없음", status: .broken))
        }
        return result
    }
}
