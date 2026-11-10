import Foundation

/// 구성 보호 설정: 지정한 프로파일의 구성에서 벗어나면 다시 적용. (PRD-PRF-004)
public struct ProtectionSetting: Codable, Hashable, Sendable {
    public var profileID: UUID
    /// 보호 대상 단계. 밝기는 사용자가 자주 바꾸므로 기본 대상에서 제외.
    public var kinds: Set<ProfileStepKind>

    public static let defaultKinds: Set<ProfileStepKind> = [.mirror, .rotation, .mode, .hdr, .color, .arrangement]

    public init(profileID: UUID, kinds: Set<ProfileStepKind> = ProtectionSetting.defaultKinds) {
        self.profileID = profileID
        self.kinds = kinds
    }

    /// 프로파일과 현재 구성의 차이 가운데 보호 대상 단계만 산출.
    public func deviations(profile: DisplayProfile, current: DisplayProfile, displays: [DisplaySummary]) -> [ProfileStep] {
        ProfilePlanner.plan(profile, current: current, displays: displays).steps.filter { kinds.contains($0.kind) }
    }
}

/// 구성 보호 설정 파일. 파일이 없으면 보호 꺼짐. (SRS-PRF-003)
public struct ProtectionStore: Sendable {
    public var fileURL: URL

    public init(fileURL: URL) { self.fileURL = fileURL }

    public static var standard: ProtectionStore {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return ProtectionStore(fileURL: base.appendingPathComponent("TheBestDisplay", isDirectory: true).appendingPathComponent("protection.json"))
    }

    public func load() -> ProtectionSetting? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(ProtectionSetting.self, from: data)
    }

    public func save(_ setting: ProtectionSetting?) throws {
        guard let setting else {
            if FileManager.default.fileExists(atPath: fileURL.path) { try FileManager.default.removeItem(at: fileURL) }
            return
        }
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(setting).write(to: fileURL, options: .atomic)
    }
}

/// 반복 복원 방지. 다른 프로그램이나 시스템이 구성을 계속 되돌리면 복원을 멈춤. (SRS-PRF-003)
public struct ProtectionGuard: Sendable {
    public static let maxAttempts = 3
    public static let window: TimeInterval = 60

    public private(set) var attempts: [Date] = []
    public private(set) var suspendedReason: String?

    public init() {}

    public enum Decision: Equatable, Sendable {
        /// 구성이 프로파일과 같음.
        case stable
        /// 복원 수행.
        case restore
        /// 일시 중지 상태. 복원하지 않음.
        case suspended(String)
    }

    public var isSuspended: Bool { suspendedReason != nil }

    /// 차이 개수와 현재 시각으로 복원 여부 결정. 복원을 결정하면 시도 기록에 추가.
    public mutating func decide(deviationCount: Int, now: Date) -> Decision {
        if let suspendedReason { return .suspended(suspendedReason) }
        guard deviationCount > 0 else { return .stable }
        attempts = attempts.filter { now.timeIntervalSince($0) < Self.window }
        if attempts.count >= Self.maxAttempts {
            let reason = "\(Int(Self.window))초 안에 \(Self.maxAttempts)회 복원한 뒤에도 구성이 다시 바뀌어 보호 일시 중지"
            suspendedReason = reason
            return .suspended(reason)
        }
        attempts.append(now)
        return .restore
    }

    public mutating func suspend(_ reason: String) { suspendedReason = reason }

    public mutating func resume() {
        suspendedReason = nil
        attempts.removeAll()
    }
}
