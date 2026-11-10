import Foundation

/// SDR과 HDR 상태별 색 프로파일 지정. HDR이 켜지고 꺼질 때 해당 프로파일로 자동 전환. (PRD-CLR-007)
public struct HDRProfilePreference: Codable, Hashable, Sendable {
    /// HDR이 꺼져 있을 때 쓸 프로파일 경로. nil이면 전환하지 않음.
    public var sdrProfilePath: String?
    /// HDR이 켜져 있을 때 쓸 프로파일 경로. nil이면 전환하지 않음.
    public var hdrProfilePath: String?

    public init(sdrProfilePath: String? = nil, hdrProfilePath: String? = nil) {
        self.sdrProfilePath = sdrProfilePath
        self.hdrProfilePath = hdrProfilePath
    }

    public var isEmpty: Bool { sdrProfilePath == nil && hdrProfilePath == nil }

    /// 현재 HDR 상태와 현재 프로파일에서 전환할 프로파일 경로. 지정이 없거나 이미 그 프로파일이면 nil.
    public func target(hdrEnabled: Bool, currentPath: String?) -> String? {
        guard let wanted = hdrEnabled ? hdrProfilePath : sdrProfilePath, wanted != currentPath else { return nil }
        return wanted
    }
}

/// 디스플레이별 상태별 프로파일 지정 저장. 디스플레이는 제조사, 제품 코드, 일련번호로 구분. (SRS-CLR-006)
public struct HDRProfileStore: Sendable {
    public var fileURL: URL

    public init(fileURL: URL) { self.fileURL = fileURL }

    public static var standard: HDRProfileStore {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return HDRProfileStore(fileURL: base.appendingPathComponent("TheBestDisplay", isDirectory: true).appendingPathComponent("hdr-profiles.json"))
    }

    public func loadAll() -> [String: HDRProfilePreference] {
        guard let data = try? Data(contentsOf: fileURL) else { return [:] }
        return (try? JSONDecoder().decode([String: HDRProfilePreference].self, from: data)) ?? [:]
    }

    public func preference(for identity: DisplayIdentity) -> HDRProfilePreference {
        loadAll()[ModeFavoritesStore.key(for: identity)] ?? HDRProfilePreference()
    }

    public func save(_ preference: HDRProfilePreference, for identity: DisplayIdentity) throws {
        var all = loadAll()
        all[ModeFavoritesStore.key(for: identity)] = preference.isEmpty ? nil : preference
        if all.isEmpty {
            if FileManager.default.fileExists(atPath: fileURL.path) { try FileManager.default.removeItem(at: fileURL) }
            return
        }
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(all).write(to: fileURL, options: .atomic)
    }
}

public extension ColorProfileCatalog {
    /// 이름 일부 또는 경로로 프로파일 찾기. 경로가 정확히 맞으면 그것, 아니면 이름(대소문자 무시)이 유일하게 맞는 것.
    static func resolve(_ text: String, in profiles: [ColorProfileInfo]) -> ColorProfileInfo? {
        if let exact = profiles.first(where: { $0.path == text }) { return exact }
        let lower = text.lowercased()
        if let name = profiles.first(where: { $0.name.lowercased() == lower }) { return name }
        let matches = profiles.filter { $0.name.lowercased().contains(lower) }
        return matches.count == 1 ? matches[0] : nil
    }
}
