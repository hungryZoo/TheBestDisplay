import Foundation
import TBDCore

struct CheckUpdateOutput: Encodable {
    var currentVersion: String
    var latestVersion: String?
    var updateAvailable: Bool
    var releaseURL: String?
}

/// `tbdctl check-update [--json]` (PRD-UPD-004)
/// GitHub 최신 릴리스를 조회해 현재 버전과 비교. 조회 실패는 종료 코드 1.
func runCheckUpdate(json: Bool) {
    let current = SemanticVersion(AppVersion.current)
    let semaphore = DispatchSemaphore(value: 0)
    nonisolated(unsafe) var latest: LatestRelease?
    Task.detached {
        latest = await UpdateChecker(apiURL: AppVersion.latestReleaseAPI).fetchLatest(userAgent: "tbdctl/\(AppVersion.current)")
        semaphore.signal()
    }
    semaphore.wait()
    guard let latest, let current else {
        if json {
            printJSON(CheckUpdateOutput(currentVersion: AppVersion.current, latestVersion: nil, updateAvailable: false, releaseURL: nil))
        }
        writeError("오류: 최신 릴리스 정보를 가져오지 못함 (네트워크 또는 릴리스 없음)")
        exit(.failure)
    }
    let available = latest.version > current
    if json {
        printJSON(CheckUpdateOutput(currentVersion: AppVersion.current, latestVersion: latest.version.description, updateAvailable: available, releaseURL: latest.url.absoluteString))
        return
    }
    print("현재 버전 \(current), 최신 릴리스 \(latest.version)")
    if available {
        print("새 버전 사용 가능: \(latest.url.absoluteString)")
        print("Homebrew 설치본: brew upgrade \(InstallMethod.caskFullName)")
    } else {
        print("최신 버전 사용 중")
    }
}
