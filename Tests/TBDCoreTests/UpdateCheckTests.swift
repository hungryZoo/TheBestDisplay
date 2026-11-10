import Foundation
import Testing
@testable import TBDCore

/// TC-UPD-001: 업데이트 확인의 버전 비교, 주기와 표시 판정, 캐시, 응답 해석, 패치 노트 변환, 설치 방식, 스크립트.
@Suite("TC-UPD-001 업데이트 확인 계산")
struct UpdateCheckTests {
    @Test func 버전_해석() {
        #expect(SemanticVersion("1.2.3") == SemanticVersion(major: 1, minor: 2, patch: 3))
        #expect(SemanticVersion("v1.0.10") == SemanticVersion(major: 1, minor: 0, patch: 10))
        #expect(SemanticVersion("1.2") == nil)
        #expect(SemanticVersion("1.2.3-rc1") == nil)
        #expect(SemanticVersion("1.+2.3") == nil)
        #expect(SemanticVersion("") == nil)
        #expect(SemanticVersion(AppVersion.current) != nil)
    }

    @Test func 버전_순서() throws {
        #expect(try #require(SemanticVersion("1.0.9")) < #require(SemanticVersion("1.0.10")))
        #expect(try #require(SemanticVersion("1.9.9")) < #require(SemanticVersion("2.0.0")))
        #expect(try !(#require(SemanticVersion("1.0.0")) < #require(SemanticVersion("1.0.0"))))
    }

    @Test func 확인은_하루_1회() {
        #expect(UpdatePolicy.shouldCheck(now: 1_000, checkedAt: 0))
        #expect(!UpdatePolicy.shouldCheck(now: 100_000, checkedAt: 100_000 - 3_600))
        #expect(UpdatePolicy.shouldCheck(now: 200_000, checkedAt: 200_000 - 86_400))
        // 시계가 과거로 돌아간 경우.
        #expect(UpdatePolicy.shouldCheck(now: 1_000, checkedAt: 5_000))
    }

    @Test func 표시_대상은_현재와_건너뛴_버전보다_새_버전() throws {
        let current = try #require(SemanticVersion("1.0.0"))
        let cache = UpdateCache(checkedAt: 1, latestVersion: "1.0.1")
        #expect(UpdatePolicy.pendingUpdate(current: current, cache: cache, skippedVersion: nil) == SemanticVersion("1.0.1"))
        #expect(UpdatePolicy.pendingUpdate(current: current, cache: cache, skippedVersion: "1.0.1") == nil)
        #expect(UpdatePolicy.pendingUpdate(current: current, cache: cache, skippedVersion: "1.0.0") == SemanticVersion("1.0.1"))
        #expect(UpdatePolicy.pendingUpdate(current: try #require(SemanticVersion("1.0.1")), cache: cache, skippedVersion: nil) == nil)
        #expect(UpdatePolicy.pendingUpdate(current: current, cache: UpdateCache(), skippedVersion: nil) == nil)
    }

    @Test func 캐시_왕복과_손상_파일() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("tbd-update-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = UpdateCacheStore(fileURL: directory.appendingPathComponent("nested/update-check.json"))
        #expect(store.load() == UpdateCache())
        let cache = UpdateCache(checkedAt: 42, latestVersion: "1.0.1", releaseNotes: "줄 1\n줄 2", releaseURL: "https://example.com")
        try store.save(cache)
        #expect(store.load() == cache)
        try Data("not json".utf8).write(to: store.fileURL)
        #expect(store.load() == UpdateCache())
        #expect(UpdateCacheStore.defaultFileURL()?.path.hasSuffix("Caches/TheBestDisplay/update-check.json") == true)
    }

    @Test func 릴리스_응답_해석() {
        let json = """
        {"tag_name":"v1.0.1","body":"## 변경\\n- 항목","html_url":"https://github.com/o/r/releases/tag/v1.0.1","draft":false,"prerelease":false}
        """
        let release = LatestReleaseParser.parse(Data(json.utf8))
        #expect(release?.version == SemanticVersion("1.0.1"))
        #expect(release?.notes == "## 변경\n- 항목")
        #expect(release?.url.absoluteString == "https://github.com/o/r/releases/tag/v1.0.1")
        let prerelease = json.replacingOccurrences(of: "\"prerelease\":false", with: "\"prerelease\":true")
        #expect(LatestReleaseParser.parse(Data(prerelease.utf8)) == nil)
        let draft = json.replacingOccurrences(of: "\"draft\":false", with: "\"draft\":true")
        #expect(LatestReleaseParser.parse(Data(draft.utf8)) == nil)
        // API 한도 초과 응답과 버전 형식이 아닌 태그.
        #expect(LatestReleaseParser.parse(Data("{\"message\":\"API rate limit exceeded\"}".utf8)) == nil)
        #expect(LatestReleaseParser.parse(Data(json.replacingOccurrences(of: "v1.0.1\",\"body", with: "nightly\",\"body").utf8)) == nil)
    }

    @Test func 패치_노트_변환() {
        let body = """
        첫 문장.

        ## What's new

        - **변경 하나.** 설명
          - 하위 항목


        ```bash
        brew install x
        ```
        """
        #expect(ReleaseNotesFormatter.inlineMarkdown(body) == "첫 문장.\n\n**What's new**\n\n• **변경 하나.** 설명\n    • 하위 항목\n\nbrew install x")
        #expect(ReleaseNotesFormatter.inlineMarkdown("") == "")
    }

    @Test func 설치_방식_판정() {
        let appleSilicon: Set<String> = ["/opt/homebrew/Caskroom/thebestdisplay", "/opt/homebrew/bin/brew"]
        #expect(InstallMethod.classify(appPath: "/Applications/TheBestDisplay.app", homeDirectory: "/Users/u", fileExists: appleSilicon.contains) == .homebrew(brewPath: "/opt/homebrew/bin/brew"))
        let intel: Set<String> = ["/usr/local/Caskroom/thebestdisplay", "/usr/local/bin/brew"]
        #expect(InstallMethod.classify(appPath: "/Users/u/Applications/TheBestDisplay.app", homeDirectory: "/Users/u/", fileExists: intel.contains) == .homebrew(brewPath: "/usr/local/bin/brew"))
        // Caskroom 기록이 없거나 설치 위치가 다르면 수동 설치.
        #expect(InstallMethod.classify(appPath: "/Applications/TheBestDisplay.app", homeDirectory: "/Users/u", fileExists: { _ in false }) == .manual)
        #expect(InstallMethod.classify(appPath: "/Users/u/dev/TheBestDisplay/build/TheBestDisplay.app", homeDirectory: "/Users/u", fileExists: appleSilicon.contains) == .manual)
        #expect(InstallMethod.caskFullName == "hungryZoo/tap/thebestdisplay")
    }

    @Test func Homebrew_스크립트는_경로를_인용하고_종료를_기다림() {
        let script = UpdateScript.homebrew(brewPath: "/opt/homebrew/bin/brew", appPath: "/Users/o'neil/Applications/TheBestDisplay.app", waitForPID: 123)
        #expect(script.hasPrefix("#!/bin/zsh\n"))
        #expect(script.contains("while kill -0 123 2>/dev/null"))
        #expect(script.contains("'/opt/homebrew/bin/brew' update\n"))
        #expect(script.contains("'/opt/homebrew/bin/brew' upgrade hungryZoo/tap/thebestdisplay"))
        #expect(script.contains("xattr -dr com.apple.quarantine '/Users/o'\\''neil/Applications/TheBestDisplay.app'"))
        #expect(script.contains("open '/Users/o'\\''neil/Applications/TheBestDisplay.app'"))
        #expect(script.contains("rm -f -- \"$0\""))
        // update가 upgrade보다 먼저.
        let update = script.range(of: "brew' update")!.lowerBound, upgrade = script.range(of: "brew' upgrade")!.lowerBound
        #expect(update < upgrade)
    }

    @Test func 배포_위치() {
        #expect(AppVersion.latestReleaseAPI.absoluteString == "https://api.github.com/repos/hungryZoo/TheBestDisplay/releases/latest")
        #expect(AppVersion.releasesURL.absoluteString == "https://github.com/hungryZoo/TheBestDisplay/releases/latest")
    }
}
