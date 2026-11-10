import AppKit
import Observation
import SwiftUI
import TBDCore

struct UpdateInfo {
    let currentVersion: SemanticVersion
    let newVersion: SemanticVersion
    let releaseNotes: String
    let releaseURL: URL
    let installMethod: InstallMethod
}

/// 업데이트 확인과 업데이트 창. 시작 시 네트워크를 기다리지 않고, 확인은 하루 1회 백그라운드로 수행. (PRD-UPD-001-003, SRS-UPD-002)
@MainActor
@Observable
final class UpdateController {
    static let shared = UpdateController()

    static let automaticKey = "automaticallyCheckForUpdates"
    static let skippedKey = "skippedUpdateVersion"

    private(set) var isChecking = false
    /// 자동 확인 사용 여부. 기본값 켜짐. 끄면 자동 확인과 창 표시 모두 중지.
    var automaticallyChecks: Bool = (UserDefaults.standard.object(forKey: UpdateController.automaticKey) as? Bool) ?? true {
        didSet { UserDefaults.standard.set(automaticallyChecks, forKey: Self.automaticKey) }
    }

    @ObservationIgnored private let checker = UpdateChecker(apiURL: AppVersion.latestReleaseAPI)
    @ObservationIgnored private let store = UpdateCacheStore.defaultFileURL().map(UpdateCacheStore.init)
    @ObservationIgnored private var window: NSWindow?
    @ObservationIgnored private var hasPresentedThisRun = false

    private init() {}

    /// 번들의 버전. 번들 없이 실행 파일로 직접 실행한 경우 nil이며 기능 전체가 꺼짐.
    var currentVersion: SemanticVersion? {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String).flatMap(SemanticVersion.init)
    }

    private var skippedVersion: String? {
        get { UserDefaults.standard.string(forKey: Self.skippedKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.skippedKey) }
    }

    /// 실행 시 호출. 24시간이 지났으면 시도 시각을 먼저 기록하고 백그라운드로 확인.
    func startBackgroundCheckIfNeeded() {
        guard automaticallyChecks, let store, let currentVersion, !isChecking else { return }
        var cache = store.load()
        let now = Date().timeIntervalSince1970
        guard UpdatePolicy.shouldCheck(now: now, checkedAt: cache.checkedAt) else { return }
        // 요청 전에 기록해야 오프라인이나 즉시 종료 시에도 실행마다 재시도하지 않음.
        cache.checkedAt = now
        try? store.save(cache)

        isChecking = true
        Task {
            if let release = await checker.fetchLatest(userAgent: "TheBestDisplay/\(currentVersion)") {
                var latest = store.load()
                latest.record(release)
                try? store.save(latest)
            }
            isChecking = false
            // 같은 실행 중 조회가 끝나면 새 캐시로 바로 판정.
            presentPendingUpdateIfNeeded()
        }
    }

    /// 캐시에 표시할 새 버전이 있고 이번 실행에서 아직 보여 주지 않았으면 업데이트 창을 엶.
    @discardableResult
    func presentPendingUpdateIfNeeded() -> Bool {
        guard !hasPresentedThisRun, automaticallyChecks, let store, let currentVersion else { return false }
        let cache = store.load()
        guard let newVersion = UpdatePolicy.pendingUpdate(current: currentVersion, cache: cache, skippedVersion: skippedVersion) else { return false }
        hasPresentedThisRun = true
        showWindow(UpdateInfo(
            currentVersion: currentVersion,
            newVersion: newVersion,
            releaseNotes: cache.releaseNotes ?? "",
            releaseURL: cache.releaseURL.flatMap(URL.init(string:)) ?? AppVersion.releasesURL,
            installMethod: installMethod
        ))
        return true
    }

    /// "업데이트 확인…": 주기와 건너뛴 버전을 무시하고 즉시 확인.
    func checkNow() {
        guard !isChecking else { return }
        guard let currentVersion else {
            showMessage("업데이트를 확인할 수 없음", "앱 번들에서 현재 버전을 읽지 못함. 번들로 빌드한 앱에서 실행")
            return
        }
        isChecking = true
        Task {
            let release = await checker.fetchLatest(userAgent: "TheBestDisplay/\(currentVersion)")
            isChecking = false
            guard let release else {
                showMessage("업데이트 정보를 가져오지 못함", "네트워크 연결을 확인한 뒤 다시 시도")
                return
            }
            if let store {
                var cache = store.load()
                cache.checkedAt = Date().timeIntervalSince1970
                cache.record(release)
                try? store.save(cache)
            }
            guard release.version > currentVersion else {
                showMessage("최신 버전 사용 중", "TheBestDisplay \(currentVersion)이 최신 버전")
                return
            }
            hasPresentedThisRun = true
            showWindow(UpdateInfo(currentVersion: currentVersion, newVersion: release.version, releaseNotes: release.notes, releaseURL: release.url, installMethod: installMethod))
        }
    }

    private var installMethod: InstallMethod {
        InstallMethod.classify(
            appPath: Bundle.main.bundleURL.standardizedFileURL.path,
            homeDirectory: FileManager.default.homeDirectoryForCurrentUser.path,
            fileExists: { FileManager.default.fileExists(atPath: $0) }
        )
    }

    // MARK: - 창

    private func showWindow(_ info: UpdateInfo) {
        window?.close()
        let view = UpdateView(
            info: info,
            onSkip: { [weak self] in self?.skip(info) },
            onLater: { [weak self] in self?.closeWindow() },
            onInstall: { [weak self] in self?.install(info) }
        )
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.title = "TheBestDisplay 업데이트"
        window.styleMask = [.titled, .closable]
        window.isRestorable = false
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.center()
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func closeWindow() {
        let window = self.window
        self.window = nil
        window?.close()
    }

    private func skip(_ info: UpdateInfo) {
        skippedVersion = info.newVersion.description
        closeWindow()
    }

    private func install(_ info: UpdateInfo) {
        switch info.installMethod {
        case .homebrew(let brewPath):
            runHomebrewUpdate(brewPath: brewPath)
        case .manual:
            NSWorkspace.shared.open(info.releaseURL)
            closeWindow()
        }
    }

    /// 터미널에서 brew 실행. brew가 앱 번들을 교체하므로 스크립트는 이 프로세스의 종료를 기다림.
    private func runHomebrewUpdate(brewPath: String) {
        let appPath = Bundle.main.bundleURL.standardizedFileURL.path
        let script = UpdateScript.homebrew(brewPath: brewPath, appPath: appPath, waitForPID: ProcessInfo.processInfo.processIdentifier)
        let scriptURL = FileManager.default.temporaryDirectory.appendingPathComponent("TheBestDisplay-update-\(UUID().uuidString).command")
        guard let terminalURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") else {
            showHomebrewFallback(brewPath: brewPath)
            return
        }
        do {
            try script.write(to: scriptURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
        } catch {
            showHomebrewFallback(brewPath: brewPath)
            return
        }
        NSWorkspace.shared.open([scriptURL], withApplicationAt: terminalURL, configuration: NSWorkspace.OpenConfiguration()) { _, error in
            Task { @MainActor in
                if error != nil {
                    UpdateController.shared.showHomebrewFallback(brewPath: brewPath)
                } else {
                    NSApp.terminate(nil)
                }
            }
        }
    }

    private func showHomebrewFallback(brewPath: String) {
        closeWindow()
        showMessage("터미널을 열지 못함", "TheBestDisplay를 종료한 뒤 터미널에서 다음 명령 실행\n\n\(brewPath) update\n\(brewPath) upgrade \(InstallMethod.caskFullName)")
    }

    private func showMessage(_ title: String, _ message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "확인")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
