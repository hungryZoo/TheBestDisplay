import Foundation

/// 디스플레이 관련 이벤트 1건. (PRD-DGN-004)
public struct DisplayEvent: Codable, Hashable, Sendable, Identifiable {
    public enum Kind: String, Codable, Sendable {
        case displayConnected, displayDisconnected
        case modeChanged, colorModeChanged, hdrChanged
        case linkChanged, hpdChanged
        case portConnected, portDisconnected

        public var title: String {
            switch self {
            case .displayConnected: "디스플레이 연결"
            case .displayDisconnected: "디스플레이 연결 해제"
            case .modeChanged: "모드 변경"
            case .colorModeChanged: "색 모드 변경"
            case .hdrChanged: "HDR 변경"
            case .linkChanged: "링크 변화"
            case .hpdChanged: "HPD 변화"
            case .portConnected: "포트 연결"
            case .portDisconnected: "포트 연결 해제"
            }
        }
    }

    public var id: Int
    public var date: Date
    public var kind: Kind
    /// 대상: 디스플레이 이름 또는 포트 이름.
    public var subject: String
    public var detail: String
}

/// 이벤트 생성에 쓰는 축약 상태. 스냅샷에서 비교에 필요한 값만 추출.
public struct EventState: Hashable, Sendable {
    public struct Display: Hashable, Sendable {
        public var name: String
        public var mode: String
        public var color: String?
        public var hdrEnabled: Bool?
    }

    public struct Port: Hashable, Sendable {
        public var connected: Bool
        public var hpd: Bool
        public var link: String?
    }

    public var displays: [UInt32: Display]
    public var ports: [PortKey: Port]

    public init(displays: [UInt32: Display] = [:], ports: [PortKey: Port] = [:]) {
        self.displays = displays
        self.ports = ports
    }

    public init(_ snapshot: DiagnosticSnapshot) {
        var displays: [UInt32: Display] = [:]
        for d in snapshot.displays {
            let color = d.signal?.linkData?.colorLabel ?? d.signal?.currentColor?.label
            displays[d.id] = Display(name: d.summary.identity.name, mode: d.currentMode?.label ?? d.summary.modeDescription, color: color, hdrEnabled: d.hdr?.isSupported == true ? d.hdr?.isEnabled : nil)
        }
        var ports: [PortKey: Port] = [:]
        for path in snapshot.paths {
            let link = path.dp.flatMap { $0.hasLink && $0.isActive ? "\($0.linkRateDescription), 레인 \($0.laneCount)개" : nil }
            ports[path.port.key] = Port(connected: path.port.connectionActive, hpd: path.dp?.hpdAsserted == true || path.port.hpdAsserted == true, link: link)
        }
        self.displays = displays
        self.ports = ports
    }
}

/// 이벤트 보관. 최근 `capacity`건 유지. (SRS-DGN-002)
public struct EventLog: Sendable {
    public static let defaultCapacity = 1000

    public private(set) var events: [DisplayEvent] = []
    public let capacity: Int
    private var nextID = 1

    public init(capacity: Int = EventLog.defaultCapacity) {
        self.capacity = max(1, capacity)
    }

    public mutating func append(kind: DisplayEvent.Kind, subject: String, detail: String, at date: Date) {
        events.append(DisplayEvent(id: nextID, date: date, kind: kind, subject: subject, detail: detail))
        nextID += 1
        if events.count > capacity { events.removeFirst(events.count - capacity) }
    }

    /// 두 상태의 차이를 이벤트로 기록. 기록한 이벤트 수 반환.
    @discardableResult
    public mutating func record(from old: EventState, to new: EventState, at date: Date) -> Int {
        let before = nextID
        for (id, display) in new.displays.sorted(by: { $0.key < $1.key }) {
            guard let previous = old.displays[id] else {
                append(kind: .displayConnected, subject: display.name, detail: display.mode, at: date)
                continue
            }
            if previous.mode != display.mode {
                append(kind: .modeChanged, subject: display.name, detail: "\(previous.mode) → \(display.mode)", at: date)
            }
            if let a = previous.color, let b = display.color, a != b {
                append(kind: .colorModeChanged, subject: display.name, detail: "\(a) → \(b)", at: date)
            }
            if let a = previous.hdrEnabled, let b = display.hdrEnabled, a != b {
                append(kind: .hdrChanged, subject: display.name, detail: b ? "HDR 켜짐" : "HDR 꺼짐", at: date)
            }
        }
        for (id, display) in old.displays.sorted(by: { $0.key < $1.key }) where new.displays[id] == nil {
            append(kind: .displayDisconnected, subject: display.name, detail: "마지막 모드 \(display.mode)", at: date)
        }
        for (key, port) in new.ports.sorted(by: { ($0.key.type, $0.key.number) < ($1.key.type, $1.key.number) }) {
            guard let previous = old.ports[key] else { continue }
            if previous.connected != port.connected {
                append(kind: port.connected ? .portConnected : .portDisconnected, subject: key.label, detail: port.connected ? "장치 연결 감지" : "장치 분리", at: date)
            }
            if previous.hpd != port.hpd {
                append(kind: .hpdChanged, subject: key.label, detail: port.hpd ? "디스플레이 연결 신호 감지" : "디스플레이 연결 신호 사라짐", at: date)
            }
            if previous.link != port.link {
                append(kind: .linkChanged, subject: key.label, detail: "\(previous.link ?? "링크 없음") → \(port.link ?? "링크 없음")", at: date)
            }
        }
        return nextID - before
    }
}
