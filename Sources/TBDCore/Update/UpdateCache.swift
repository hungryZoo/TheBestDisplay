import Foundation

/// 마지막 업데이트 확인 결과. `checkedAt`은 확인을 시도한 시각(성공 여부와 무관), 0이면 확인한 적 없음. (PRD-UPD-001)
public struct UpdateCache: Codable, Equatable, Sendable {
    public var checkedAt: TimeInterval
    public var latestVersion: String?
    public var releaseNotes: String?
    public var releaseURL: String?

    public init(
        checkedAt: TimeInterval = 0,
        latestVersion: String? = nil,
        releaseNotes: String? = nil,
        releaseURL: String? = nil
    ) {
        self.checkedAt = checkedAt
        self.latestVersion = latestVersion
        self.releaseNotes = releaseNotes
        self.releaseURL = releaseURL
    }

    public mutating func record(_ release: LatestRelease) {
        latestVersion = release.version.description
        releaseNotes = release.notes
        releaseURL = release.url.absoluteString
    }
}

/// `~/Library/Caches/TheBestDisplay/update-check.json` 읽기와 쓰기. 파일이 없거나 손상되면 기본값(즉시 재확인). (SRS-UPD-001)
public struct UpdateCacheStore: Sendable {
    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public static func defaultFileURL(fileManager: FileManager = .default) -> URL? {
        fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("TheBestDisplay", isDirectory: true)
            .appendingPathComponent("update-check.json", isDirectory: false)
    }

    public func load() -> UpdateCache {
        guard let data = try? Data(contentsOf: fileURL),
              let cache = try? JSONDecoder().decode(UpdateCache.self, from: data) else {
            return UpdateCache()
        }
        return cache
    }

    public func save(_ cache: UpdateCache) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(cache).write(to: fileURL, options: .atomic)
    }
}
