import Foundation

/// 디스플레이 1대의 저장 구성. (PRD-PRF-001)
public struct DisplayProfileEntry: Codable, Hashable, Sendable {
    public var ref: DisplayRef
    public var mode: ModeDescriptor?
    public var color: ColorDescriptor?
    /// HDR 지원 디스플레이만 값 보유.
    public var hdrEnabled: Bool?
    public var rotation: Int
    public var originX: Int
    public var originY: Int
    public var isMain: Bool
    /// 미러 원본. 미러가 아니면 nil.
    public var mirrorOf: DisplayRef?
    /// 시스템 밝기 제어 대상의 밝기 (0-1). 그 외에는 nil.
    public var brightness: Double?

    public init(ref: DisplayRef, mode: ModeDescriptor?, color: ColorDescriptor?, hdrEnabled: Bool?, rotation: Int, originX: Int, originY: Int, isMain: Bool, mirrorOf: DisplayRef?, brightness: Double?) {
        self.ref = ref
        self.mode = mode
        self.color = color
        self.hdrEnabled = hdrEnabled
        self.rotation = rotation
        self.originX = originX
        self.originY = originY
        self.isMain = isMain
        self.mirrorOf = mirrorOf
        self.brightness = brightness
    }

    /// 한 줄 요약. 예: "LG TV SSCR2: 2304 x 1296 HiDPI 120 Hz, HDR 켜짐"
    public var summary: String {
        var parts: [String] = []
        if let mode { parts.append("\(mode.width) x \(mode.height)\(mode.isHiDPI ? " HiDPI" : "") \(DisplaySummary.formatHz(mode.refreshRate)) Hz") }
        if let hdrEnabled { parts.append(hdrEnabled ? "HDR 켜짐" : "HDR 꺼짐") }
        if rotation != 0 { parts.append("회전 \(rotation)도") }
        if let mirrorOf { parts.append("\(mirrorOf.name) 미러") }
        if isMain { parts.append("메인") }
        return "\(ref.name): " + parts.joined(separator: ", ")
    }
}

/// 구성 프로파일. (PRD-PRF-001)
public struct DisplayProfile: Codable, Hashable, Sendable, Identifiable {
    public static let currentVersion = 1

    public var id: UUID
    public var version: Int
    public var name: String
    public var createdAt: Date
    public var displays: [DisplayProfileEntry]

    public init(id: UUID = UUID(), name: String, createdAt: Date, displays: [DisplayProfileEntry]) {
        self.id = id
        self.version = Self.currentVersion
        self.name = name
        self.createdAt = createdAt
        self.displays = displays
    }
}

/// 프로파일 저장소. (SRS-PRF-001)
public struct ProfileStore: Sendable {
    public var fileURL: URL

    public init(fileURL: URL) { self.fileURL = fileURL }

    public static var standard: ProfileStore {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return ProfileStore(fileURL: base.appendingPathComponent("TheBestDisplay", isDirectory: true).appendingPathComponent("profiles.json"))
    }

    public enum StoreError: Error, Equatable, LocalizedError {
        case emptyName
        case duplicateName(String)
        case notFound(String)

        public var errorDescription: String? {
            switch self {
            case .emptyName: "프로파일 이름이 비어 있음"
            case .duplicateName(let name): "같은 이름의 프로파일이 이미 있음: \(name)"
            case .notFound(let name): "프로파일 없음: \(name)"
            }
        }
    }

    /// 파일이 없거나 손상되었으면 빈 목록. 지원하지 않는 판 번호의 항목은 제외.
    public func load() -> [DisplayProfile] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return ((try? decoder.decode([DisplayProfile].self, from: data)) ?? []).filter { $0.version <= DisplayProfile.currentVersion }
    }

    public func save(_ profiles: [DisplayProfile]) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(profiles).write(to: fileURL, options: .atomic)
    }

    static func normalized(_ name: String) throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw StoreError.emptyName }
        return trimmed
    }

    /// 프로파일 추가. 같은 이름이 있으면 `replace`가 참일 때만 교체.
    @discardableResult
    public func add(_ profile: DisplayProfile, replace: Bool = false) throws -> DisplayProfile {
        var profile = profile
        profile.name = try Self.normalized(profile.name)
        var all = load()
        if let index = all.firstIndex(where: { $0.name == profile.name }) {
            guard replace else { throw StoreError.duplicateName(profile.name) }
            all[index] = profile
        } else {
            all.append(profile)
        }
        try save(all)
        return profile
    }

    public func rename(_ id: UUID, to name: String) throws {
        let newName = try Self.normalized(name)
        var all = load()
        guard let index = all.firstIndex(where: { $0.id == id }) else { throw StoreError.notFound(name) }
        if all.contains(where: { $0.name == newName && $0.id != id }) { throw StoreError.duplicateName(newName) }
        all[index].name = newName
        try save(all)
    }

    public func delete(_ id: UUID) throws {
        var all = load()
        guard all.contains(where: { $0.id == id }) else { throw StoreError.notFound(id.uuidString) }
        all.removeAll { $0.id == id }
        try save(all)
    }

    public func find(named name: String) -> DisplayProfile? {
        load().first { $0.name == name }
    }
}

/// 프로파일 적용의 단계. 실행 순서대로 정의. (SRS-PRF-002)
/// 회전을 모드보다 먼저(회전 상태에 따라 모드 목록이 달라짐), HDR을 색 모드보다 먼저(HDR 전환과 모드 전환은 색 모드를 다시 선택하게 함).
public enum ProfileStepKind: String, Codable, CaseIterable, Sendable {
    case mirror, rotation, mode, hdr, color, arrangement, brightness

    public var title: String {
        switch self {
        case .mirror: "미러"
        case .rotation: "회전"
        case .mode: "모드"
        case .hdr: "HDR"
        case .color: "색 모드"
        case .arrangement: "배치"
        case .brightness: "밝기"
        }
    }
}

/// 프로파일 적용 계획의 한 단계.
public struct ProfileStep: Hashable, Sendable {
    public var kind: ProfileStepKind
    /// 대상 디스플레이. 배치 단계는 전체 대상이라 nil.
    public var displayID: UInt32?
    public var displayName: String
    public var detail: String
}

/// 단계별 적용 결과. (PRD-PRF-002)
public struct ProfileStepResult: Codable, Hashable, Sendable, Identifiable {
    public enum Outcome: String, Codable, Sendable {
        case applied, unchanged, skipped, failed

        public var title: String {
            switch self {
            case .applied: "적용"
            case .unchanged: "변경 없음"
            case .skipped: "건너뜀"
            case .failed: "실패"
            }
        }
    }

    public var kind: ProfileStepKind
    public var displayName: String
    public var outcome: Outcome
    public var detail: String

    public var id: String { "\(kind.rawValue)|\(displayName)" }

    public init(kind: ProfileStepKind, displayName: String, outcome: Outcome, detail: String) {
        self.kind = kind
        self.displayName = displayName
        self.outcome = outcome
        self.detail = detail
    }
}

public enum ProfilePlanner {
    /// 프로파일 항목과 온라인 디스플레이의 대응. UUID 우선, 제조사와 제품 코드와 일련번호 차선. (PRD-PRF-003)
    public static func match(_ profile: DisplayProfile, displays: [DisplaySummary]) -> [(entry: DisplayProfileEntry, display: DisplaySummary?)] {
        var used = Set<UInt32>()
        return profile.displays.map { entry in
            let display = entry.ref.resolve(in: displays.filter { !used.contains($0.id) })
            if let display { used.insert(display.id) }
            return (entry, display)
        }
    }

    /// 저장 구성과 현재 구성의 차이로 필요한 단계 산출. 순서는 `ProfileStepKind`의 정의 순서.
    /// - Parameter current: 현재 구성을 같은 형식으로 담은 프로파일.
    public static func plan(_ profile: DisplayProfile, current: DisplayProfile, displays: [DisplaySummary]) -> (steps: [ProfileStep], unmatched: [DisplayProfileEntry]) {
        let matches = match(profile, displays: displays)
        let unmatched = matches.filter { $0.display == nil }.map(\.entry)
        var steps: [ProfileStep] = []
        func now(_ display: DisplaySummary) -> DisplayProfileEntry? {
            current.displays.first { $0.ref.resolve(in: [display]) != nil }
        }
        for kind in ProfileStepKind.allCases {
            if kind == .arrangement {
                let changed = matches.contains { entry, display in
                    guard let display, let present = now(display) else { return false }
                    return entry.mirrorOf == nil && (present.originX != entry.originX || present.originY != entry.originY || present.isMain != entry.isMain)
                }
                if changed {
                    let detail = matches.compactMap { entry, display in display == nil || entry.mirrorOf != nil ? nil : "\(entry.ref.name) (\(entry.originX), \(entry.originY))\(entry.isMain ? " 메인" : "")" }.joined(separator: ", ")
                    steps.append(ProfileStep(kind: .arrangement, displayID: nil, displayName: "전체", detail: detail))
                }
                continue
            }
            for (entry, display) in matches {
                guard let display, let present = now(display) else { continue }
                let name = display.identity.name
                switch kind {
                case .mirror where present.mirrorOf?.name != entry.mirrorOf?.name || (present.mirrorOf == nil) != (entry.mirrorOf == nil):
                    steps.append(ProfileStep(kind: .mirror, displayID: display.id, displayName: name, detail: entry.mirrorOf.map { "\($0.name) 미러" } ?? "미러 해제"))
                case .rotation where present.rotation != entry.rotation:
                    steps.append(ProfileStep(kind: .rotation, displayID: display.id, displayName: name, detail: "\(entry.rotation)도"))
                case .mode:
                    if let mode = entry.mode, present.mode != mode {
                        steps.append(ProfileStep(kind: .mode, displayID: display.id, displayName: name, detail: "\(mode.width) x \(mode.height)\(mode.isHiDPI ? " HiDPI" : ""), \(DisplaySummary.formatHz(mode.refreshRate)) Hz"))
                    }
                case .hdr:
                    if let hdr = entry.hdrEnabled, present.hdrEnabled != nil, present.hdrEnabled != hdr {
                        steps.append(ProfileStep(kind: .hdr, displayID: display.id, displayName: name, detail: hdr ? "켜기" : "끄기"))
                    }
                case .color:
                    // 모드나 HDR이 바뀌면 시스템이 색 모드를 다시 고르므로 그 경우에도 색 모드 단계 포함.
                    let upstreamChanged = (entry.mode != nil && present.mode != entry.mode) || (entry.hdrEnabled != nil && present.hdrEnabled != entry.hdrEnabled)
                    if let color = entry.color, present.color != color || upstreamChanged {
                        steps.append(ProfileStep(kind: .color, displayID: display.id, displayName: name, detail: color.label))
                    }
                case .brightness:
                    if let brightness = entry.brightness, let presentBrightness = present.brightness, abs(presentBrightness - brightness) > 0.01 {
                        steps.append(ProfileStep(kind: .brightness, displayID: display.id, displayName: name, detail: "\(Int((brightness * 100).rounded()))%"))
                    }
                default:
                    break
                }
            }
        }
        return (steps, unmatched)
    }
}
