import Foundation

/// 확인 대기 중인 변경에 다른 프로세스가 전하는 결정. (PRD-AGT-002, SRS-AGT-003)
///
/// `tbdctl <변경 명령> --timeout <초>`를 백그라운드로 실행해 두고 `tbdctl resolve keep|revert`로 끝내는 흐름에 사용.
/// 표준 입력을 붙잡을 수 없는 셸 기반 에이전트가 적용과 확정을 서로 다른 명령으로 나눠 실행하기 위함.
public struct GuardedDecisionStore: Sendable {
    public enum Decision: String, Sendable {
        case keep, revert
    }

    public var fileURL: URL

    public init(fileURL: URL) { self.fileURL = fileURL }

    /// Application Support의 앱 폴더 아래 `pending-decision`.
    public static var standard: GuardedDecisionStore {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return GuardedDecisionStore(fileURL: base.appendingPathComponent("TheBestDisplay", isDirectory: true).appendingPathComponent("pending-decision"))
    }

    public func write(_ decision: Decision) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(decision.rawValue.utf8).write(to: fileURL, options: .atomic)
    }

    /// 결정을 읽고 파일 삭제. 파일이 없으면 nil. 해석할 수 없는 내용은 지우고 nil.
    public func take() -> Decision? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        clear()
        return Decision(rawValue: String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }

    public func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
