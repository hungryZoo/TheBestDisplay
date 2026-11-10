import Foundation

/// GitHub 최신 릴리스 정보.
public struct LatestRelease: Equatable, Sendable {
    public let version: SemanticVersion
    public let notes: String
    public let url: URL

    public init(version: SemanticVersion, notes: String, url: URL) {
        self.version = version
        self.notes = notes
        self.url = url
    }
}

/// 확인 주기와 표시 대상 판정. (SRS-UPD-001)
public enum UpdatePolicy {
    public static let checkInterval: TimeInterval = 86_400

    /// 최초(0), 24시간 경과, 시계가 과거로 돌아간 경우 확인.
    public static func shouldCheck(now: TimeInterval, checkedAt: TimeInterval) -> Bool {
        checkedAt <= 0 || now < checkedAt || now - checkedAt >= checkInterval
    }

    /// 캐시의 최신 버전이 현재보다 높고, 건너뛴 버전보다도 높을 때만 표시 대상.
    public static func pendingUpdate(
        current: SemanticVersion,
        cache: UpdateCache,
        skippedVersion: String?
    ) -> SemanticVersion? {
        guard let latest = cache.latestVersion.flatMap(SemanticVersion.init),
              latest > current else { return nil }
        if let skipped = skippedVersion.flatMap(SemanticVersion.init), latest <= skipped {
            return nil
        }
        return latest
    }
}

/// GitHub REST API `releases/latest` 응답 해석. 초안, 사전 릴리스, 버전 형식이 아닌 태그는 무시.
public enum LatestReleaseParser {
    private struct Response: Decodable {
        let tagName: String
        let body: String?
        let htmlURL: URL
        let draft: Bool?
        let prerelease: Bool?

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case body
            case htmlURL = "html_url"
            case draft
            case prerelease
        }
    }

    public static func parse(_ data: Data) -> LatestRelease? {
        guard let response = try? JSONDecoder().decode(Response.self, from: data),
              response.draft != true,
              response.prerelease != true,
              let version = SemanticVersion(response.tagName) else { return nil }
        return LatestRelease(version: version, notes: response.body ?? "", url: response.htmlURL)
    }
}

/// 최신 릴리스 조회. 실패(오프라인, 시간 초과, API 한도, 형식 오류)는 모두 nil.
public struct UpdateChecker: Sendable {
    public let apiURL: URL
    public let timeout: TimeInterval

    public init(apiURL: URL, timeout: TimeInterval = 5) {
        self.apiURL = apiURL
        self.timeout = timeout
    }

    public func fetchLatest(userAgent: String) async -> LatestRelease? {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        let session = URLSession(configuration: configuration)
        defer { session.finishTasksAndInvalidate() }

        var request = URLRequest(url: apiURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await session.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return LatestReleaseParser.parse(data)
    }
}
