import Foundation

/// 제품 버전과 배포 위치. 앱 번들의 Info.plist 버전과 `tbdctl --version`이 같은 값을 쓰도록 빌드 스크립트가 이 값을 읽음. (SRS-UPD-001)
public enum AppVersion {
    public static let current = "1.0.0"
    public static let repository = "hungryZoo/TheBestDisplay"
    public static let releasesURL = URL(string: "https://github.com/\(repository)/releases/latest")!
    public static let latestReleaseAPI = URL(string: "https://api.github.com/repos/\(repository)/releases/latest")!
}
