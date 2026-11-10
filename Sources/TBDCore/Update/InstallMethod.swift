import Foundation

/// 앱 설치 방식. Homebrew cask 소유 앱은 brew 명령으로만 갱신. (SRS-UPD-002)
public enum InstallMethod: Equatable, Sendable {
    case homebrew(brewPath: String)
    case manual

    public static let caskFullName = "hungryZoo/tap/thebestdisplay"

    /// cask 설치 위치(`/Applications` 또는 `~/Applications`)에 있고 Caskroom에 기록이 있으면 Homebrew.
    /// Apple Silicon(`/opt/homebrew`)을 Intel(`/usr/local`)보다 먼저 검사한다.
    public static func classify(
        appPath: String,
        homeDirectory: String,
        fileExists: (String) -> Bool
    ) -> InstallMethod {
        let home = homeDirectory.hasSuffix("/") ? String(homeDirectory.dropLast()) : homeDirectory
        let caskAppPaths = [
            "/Applications/TheBestDisplay.app",
            home + "/Applications/TheBestDisplay.app"
        ]
        guard caskAppPaths.contains(appPath) else { return .manual }

        for prefix in ["/opt/homebrew", "/usr/local"] {
            let brew = prefix + "/bin/brew"
            if fileExists(prefix + "/Caskroom/thebestdisplay"), fileExists(brew) {
                return .homebrew(brewPath: brew)
            }
        }
        return .manual
    }
}

/// Homebrew 업데이트를 터미널에서 실행하는 스크립트. 앱 프로세스가 종료된 뒤 brew가 앱 번들을 교체한다.
public enum UpdateScript {
    public static func homebrew(brewPath: String, appPath: String, waitForPID pid: Int32) -> String {
        let brew = shellQuote(brewPath)
        let app = shellQuote(appPath)
        let cask = InstallMethod.caskFullName
        return """
        #!/bin/zsh
        # TheBestDisplay 업데이트 (Homebrew)
        while kill -0 \(pid) 2>/dev/null; do sleep 0.3; done
        echo "TheBestDisplay 업데이트: brew update, brew upgrade \(cask)"
        echo
        \(brew) update
        if \(brew) upgrade \(cask); then
          xattr -dr com.apple.quarantine \(app) 2>/dev/null
          open \(app)
          echo
          echo "업데이트 완료. 이 창은 닫아도 됨"
        else
          echo
          echo "업데이트 실패. 위 메시지 확인"
        fi
        rm -f -- "$0"

        """
    }

    public static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
