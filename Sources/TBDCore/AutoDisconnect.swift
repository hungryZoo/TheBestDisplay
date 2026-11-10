import Foundation

/// 외장 디스플레이 연결 시 내장 디스플레이 자동 연결 해제의 판단. (PRD-ARR-008, SRS-ARR-006)
///
/// 안전 규칙: 실제 외장 디스플레이(가상 디스플레이 제외)가 온라인일 때만 내장을 해제하고,
/// 실제 외장이 하나도 없으면 설정과 무관하게 내장을 다시 연결.
public enum AutoDisconnectPolicy {
    public struct DisplayState: Hashable, Sendable {
        public var id: UInt32
        public var isBuiltin: Bool
        public var isVirtual: Bool

        public init(id: UInt32, isBuiltin: Bool, isVirtual: Bool) {
            self.id = id
            self.isBuiltin = isBuiltin
            self.isVirtual = isVirtual
        }
    }

    public enum Action: Equatable, Sendable {
        case none
        case disconnectBuiltin(UInt32)
        case reconnectBuiltin(UInt32)
    }

    /// - Parameters:
    ///   - enabled: 기능 설정.
    ///   - online: 현재 온라인 디스플레이.
    ///   - disconnectedBuiltin: 이 기능이 해제해 둔 내장 디스플레이 ID. 없으면 nil.
    public static func decide(enabled: Bool, online: [DisplayState], disconnectedBuiltin: UInt32?) -> Action {
        let physicalExternalOnline = online.contains { !$0.isBuiltin && !$0.isVirtual }
        if let disconnectedBuiltin {
            // 이미 온라인이면 (다른 경로로 재연결됨) 할 일 없음.
            if online.contains(where: { $0.id == disconnectedBuiltin }) { return .none }
            return !enabled || !physicalExternalOnline ? .reconnectBuiltin(disconnectedBuiltin) : .none
        }
        guard enabled, physicalExternalOnline, let builtin = online.first(where: \.isBuiltin) else { return .none }
        return .disconnectBuiltin(builtin.id)
    }
}

/// 자동 해제 설정과 상태 파일. 해제해 둔 내장 디스플레이 ID를 기록해 앱이 비정상 종료된 뒤에도 다음 실행에서 재연결.
public struct AutoDisconnectStore: Sendable {
    public struct State: Codable, Hashable, Sendable {
        public var enabled: Bool
        public var disconnectedBuiltin: UInt32?

        public init(enabled: Bool = false, disconnectedBuiltin: UInt32? = nil) {
            self.enabled = enabled
            self.disconnectedBuiltin = disconnectedBuiltin
        }
    }

    public var fileURL: URL

    public init(fileURL: URL) { self.fileURL = fileURL }

    public static var standard: AutoDisconnectStore {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return AutoDisconnectStore(fileURL: base.appendingPathComponent("TheBestDisplay", isDirectory: true).appendingPathComponent("auto-disconnect.json"))
    }

    public func load() -> State {
        guard let data = try? Data(contentsOf: fileURL), let state = try? JSONDecoder().decode(State.self, from: data) else { return State() }
        return state
    }

    public func save(_ state: State) throws {
        if state == State() {
            if FileManager.default.fileExists(atPath: fileURL.path) { try FileManager.default.removeItem(at: fileURL) }
            return
        }
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(state).write(to: fileURL, options: .atomic)
    }
}
