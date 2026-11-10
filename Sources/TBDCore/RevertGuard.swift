import Foundation

// 화면 변경 동작의 자동 복귀 안전장치. (PRD 3절, SRS-SAF-001, ADR-0003)

public enum RevertState: String, Equatable, Sendable {
    case idle, applying, awaitingConfirmation, reverting
}

public enum RevertEvent: Equatable, Sendable {
    case request
    case applySucceeded, applyFailed
    case confirm, cancel, timerExpired, targetDisconnected
    case revertSucceeded, revertFailed
}

public enum RevertEffect: Equatable, Sendable {
    /// 변경 전 상태 저장, 복귀 정보 파일 기록, 변경 적용.
    case saveStateAndApply
    case showConfirmationAndStartTimer
    case reportApplyError
    case stopTimer
    /// 변경 확정.
    case commit
    case deletePendingFile
    /// 변경 전 상태 적용.
    case restore
    case reportReverted
    case reportRevertError
    /// 진행 중인 변경이 있어 새 요청 거부.
    case rejectBusy
}

/// PRD 3절 상태 전이 표의 순수 구현.
public struct RevertStateMachine: Equatable, Sendable {
    public private(set) var state: RevertState = .idle

    public init() {}

    public mutating func handle(_ event: RevertEvent) -> [RevertEffect] {
        switch (state, event) {
        case (.idle, .request):
            state = .applying
            return [.saveStateAndApply]
        case (_, .request):
            return [.rejectBusy]
        case (.applying, .applySucceeded):
            state = .awaitingConfirmation
            return [.showConfirmationAndStartTimer]
        case (.applying, .applyFailed):
            state = .idle
            return [.reportApplyError, .deletePendingFile]
        case (.awaitingConfirmation, .confirm):
            state = .idle
            return [.stopTimer, .commit, .deletePendingFile]
        case (.awaitingConfirmation, .cancel):
            state = .reverting
            return [.stopTimer, .restore]
        case (.awaitingConfirmation, .timerExpired):
            state = .reverting
            return [.restore]
        case (.awaitingConfirmation, .targetDisconnected):
            // 복귀 정보 파일은 유지: 재연결 또는 다음 실행 시 복귀 제안.
            state = .idle
            return [.stopTimer]
        case (.reverting, .revertSucceeded):
            state = .idle
            return [.reportReverted, .deletePendingFile]
        case (.reverting, .revertFailed):
            state = .idle
            return [.reportRevertError]
        default:
            return []
        }
    }
}

// MARK: - 복귀 정보

/// 재실행 후에도 같은 디스플레이를 찾기 위한 참조. UUID 우선, 제조사와 제품 코드와 일련번호 차선. (PRD-PRF-003과 같은 규칙)
public struct DisplayRef: Codable, Hashable, Sendable {
    public var uuid: String?
    public var vendorID: UInt32
    public var productID: UInt32
    public var serialNumber: UInt32
    public var name: String

    public init(_ identity: DisplayIdentity) {
        uuid = identity.uuid
        vendorID = identity.vendorID
        productID = identity.productID
        serialNumber = identity.serialNumber
        name = identity.name
    }

    public init(uuid: String?, vendorID: UInt32, productID: UInt32, serialNumber: UInt32, name: String) {
        self.uuid = uuid
        self.vendorID = vendorID
        self.productID = productID
        self.serialNumber = serialNumber
        self.name = name
    }

    public func resolve(in displays: [DisplaySummary]) -> DisplaySummary? {
        if let uuid, let match = displays.first(where: { $0.identity.uuid == uuid }) { return match }
        let sameProduct = displays.filter { $0.identity.vendorID == vendorID && $0.identity.productID == productID && $0.identity.serialNumber == serialNumber }
        return sameProduct.count == 1 ? sameProduct[0] : nil
    }
}

/// 되돌릴 대상과 되돌릴 값. 화면 변경 기능이 늘어날 때마다 경우 추가.
public enum RevertAction: Codable, Hashable, Sendable {
    case displayMode(target: DisplayRef, mode: ModeDescriptor)
    case colorMode(target: DisplayRef, color: ColorDescriptor)
    case hdr(target: DisplayRef, enabled: Bool)
    case rotation(target: DisplayRef, degrees: Int)
    /// `master`가 nil이면 미러 해제.
    case mirror(target: DisplayRef, master: DisplayRef?)
    /// 연결 해제한 디스플레이의 재연결. 해제된 디스플레이는 온라인 목록에 없으므로 ID로 지정.
    case reconnect(displayID: UInt32, name: String)
}

public struct PendingRevert: Codable, Hashable, Sendable {
    public var createdAt: Date
    public var summary: String
    public var actions: [RevertAction]

    public init(createdAt: Date, summary: String, actions: [RevertAction]) {
        self.createdAt = createdAt
        self.summary = summary
        self.actions = actions
    }
}

/// 복귀 정보 파일. 확인 전 앱이 종료되어도 다음 실행에서 복귀 제안. (SRS-SAF-002)
public struct PendingRevertStore: Sendable {
    public var fileURL: URL

    public init(fileURL: URL) { self.fileURL = fileURL }

    /// Application Support의 앱 폴더 아래 `pending-revert.json`.
    public static var standard: PendingRevertStore {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return PendingRevertStore(fileURL: base.appendingPathComponent("TheBestDisplay", isDirectory: true).appendingPathComponent("pending-revert.json"))
    }

    public func save(_ record: PendingRevert) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(record).write(to: fileURL, options: .atomic)
    }

    /// 파일이 없거나 손상되었으면 nil.
    public func load() -> PendingRevert? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(PendingRevert.self, from: data)
    }

    public func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}

// MARK: - 실행기

public protocol RevertTimer: AnyObject {
    func start(seconds: TimeInterval, onFire: @escaping () -> Void)
    func stop()
}

/// 상태 기계의 효과를 실제 동작으로 수행. 적용, 확정, 복귀 동작과 타이머는 주입.
/// 단일 스레드(메인)에서 호출.
public final class RevertCoordinator {
    public struct Change {
        public var summary: String
        /// 복귀 정보 파일에 기록할 내용. nil이면 기록 생략.
        public var pending: PendingRevert?
        public var apply: () throws -> Void
        public var commit: () throws -> Void
        public var restore: () throws -> Void

        public init(summary: String, pending: PendingRevert?, apply: @escaping () throws -> Void, commit: @escaping () throws -> Void = {}, restore: @escaping () throws -> Void) {
            self.summary = summary
            self.pending = pending
            self.apply = apply
            self.commit = commit
            self.restore = restore
        }
    }

    public enum Notice: Equatable {
        case awaitingConfirmation(summary: String, timeout: TimeInterval)
        case committed(summary: String)
        case reverted(summary: String)
        case applyFailed(summary: String, message: String)
        case revertFailed(summary: String, message: String)
        case commitFailed(summary: String, message: String)
        case rejectedBusy
        case targetDisconnected(summary: String)
    }

    public private(set) var machine = RevertStateMachine()
    public var timeout: TimeInterval
    public var onNotice: ((Notice) -> Void)?

    private let timer: RevertTimer
    private let store: PendingRevertStore?
    private var current: Change?
    private var lastError: String = ""

    public init(timeout: TimeInterval = 15, timer: RevertTimer, store: PendingRevertStore?) {
        self.timeout = timeout
        self.timer = timer
        self.store = store
    }

    public var state: RevertState { machine.state }
    public var currentSummary: String? { current?.summary }

    /// 변경 요청. 진행 중인 변경이 있으면 거부하고 false 반환.
    @discardableResult
    public func request(_ change: Change) -> Bool {
        guard machine.state == .idle else {
            run(machine.handle(.request))
            return false
        }
        current = change
        run(machine.handle(.request))
        return true
    }

    public func confirm() { run(machine.handle(.confirm)) }
    public func cancel() { run(machine.handle(.cancel)) }
    public func targetDisconnected() { run(machine.handle(.targetDisconnected)) }

    private func run(_ effects: [RevertEffect]) {
        for effect in effects {
            let summary = current?.summary ?? ""
            switch effect {
            case .saveStateAndApply:
                guard let change = current else { continue }
                do {
                    if let pending = change.pending { try store?.save(pending) }
                    try change.apply()
                    run(machine.handle(.applySucceeded))
                } catch {
                    lastError = Self.describe(error)
                    run(machine.handle(.applyFailed))
                }
            case .showConfirmationAndStartTimer:
                onNotice?(.awaitingConfirmation(summary: summary, timeout: timeout))
                timer.start(seconds: timeout) { [weak self] in
                    guard let self else { return }
                    self.run(self.machine.handle(.timerExpired))
                }
            case .reportApplyError:
                onNotice?(.applyFailed(summary: summary, message: lastError))
            case .stopTimer:
                timer.stop()
                if machine.state == .idle, effects == [.stopTimer] {
                    onNotice?(.targetDisconnected(summary: summary))
                    current = nil
                }
            case .commit:
                do {
                    try current?.commit()
                    onNotice?(.committed(summary: summary))
                } catch {
                    onNotice?(.commitFailed(summary: summary, message: Self.describe(error)))
                }
            case .deletePendingFile:
                store?.clear()
                current = nil
            case .restore:
                do {
                    try current?.restore()
                    run(machine.handle(.revertSucceeded))
                } catch {
                    lastError = Self.describe(error)
                    run(machine.handle(.revertFailed))
                }
            case .reportReverted:
                onNotice?(.reverted(summary: summary))
            case .reportRevertError:
                onNotice?(.revertFailed(summary: summary, message: lastError))
                current = nil
            case .rejectBusy:
                onNotice?(.rejectedBusy)
            }
        }
    }

    public static func describe(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? String(describing: error)
    }
}
