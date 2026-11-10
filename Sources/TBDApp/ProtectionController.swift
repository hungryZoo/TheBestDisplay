import Foundation
import Observation
import TBDCore
import TBDPlatform

/// 구성 보호 실행기: 디스플레이 구성이 바뀔 때마다 보호 중인 프로파일과 비교하고 벗어난 단계를 다시 적용. (SRS-PRF-003, PRD-PRF-004)
@MainActor
@Observable
final class ProtectionController {
    /// 구성 변경 뒤 복원까지의 대기. 시스템이 재구성을 마칠 시간을 둠.
    static let settleDelay: Duration = .milliseconds(1500)

    private(set) var setting: ProtectionSetting?
    private(set) var statusText = "꺼짐"
    private(set) var lastRestoreAt: Date?
    private(set) var lastResults: [ProfileStepResult] = []
    private(set) var isSuspended = false

    @ObservationIgnored private var guardState = ProtectionGuard()
    @ObservationIgnored private var pending: Task<Void, Never>?
    @ObservationIgnored private let store = ProtectionStore.standard
    @ObservationIgnored private let profiles = ProfileStore.standard
    /// 복원이 일으킨 재구성 알림을 건너뛰기 위한 표시.
    @ObservationIgnored private var isRestoring = false

    init() {
        setting = store.load()
        statusText = setting == nil ? "꺼짐" : "보호 중"
    }

    var protectedProfile: DisplayProfile? {
        guard let setting else { return nil }
        return profiles.load().first { $0.id == setting.profileID }
    }

    func enable(profile: DisplayProfile, kinds: Set<ProfileStepKind> = ProtectionSetting.defaultKinds) {
        let new = ProtectionSetting(profileID: profile.id, kinds: kinds)
        try? store.save(new)
        setting = new
        guardState.resume()
        isSuspended = false
        statusText = "보호 중: \(profile.name)"
    }

    func disable() {
        pending?.cancel()
        try? store.save(nil)
        setting = nil
        guardState.resume()
        isSuspended = false
        statusText = "꺼짐"
    }

    func resume() {
        guardState.resume()
        isSuspended = false
        statusText = protectedProfile.map { "보호 중: \($0.name)" } ?? "꺼짐"
    }

    /// 사용자가 이 앱에서 구성을 바꾸면 그 변경을 되돌리지 않도록 일시 중지.
    func userChangedConfiguration() {
        guard setting != nil, !isSuspended else { return }
        pending?.cancel()
        guardState.suspend("이 앱에서 구성을 바꿔 보호 일시 중지")
        isSuspended = true
        statusText = "일시 중지: 이 앱에서 구성 변경"
    }

    /// 디스플레이 구성 변경 뒤 호출. 설정 파일을 다시 읽어 명령행에서 바꾼 설정도 반영.
    func displaysChanged(isBusy: Bool) {
        let loaded = store.load()
        if loaded != setting {
            setting = loaded
            guardState.resume()
            isSuspended = false
            statusText = protectedProfile.map { "보호 중: \($0.name)" } ?? "꺼짐"
        }
        guard setting != nil, !isRestoring, !isBusy else { return }
        pending?.cancel()
        pending = Task { [weak self] in
            try? await Task.sleep(for: Self.settleDelay)
            guard !Task.isCancelled else { return }
            self?.evaluate()
        }
    }

    private func evaluate() {
        guard let setting, let profile = protectedProfile else {
            if setting != nil { statusText = "보호 대상 프로파일이 삭제됨" }
            return
        }
        let displays = DisplayCatalog.displays()
        let current = ProfileApplier.capture(name: "현재", displays: displays)
        let deviations = setting.deviations(profile: profile, current: current, displays: displays)
        switch guardState.decide(deviationCount: deviations.count, now: Date()) {
        case .stable:
            statusText = "보호 중: \(profile.name)"
        case .suspended(let reason):
            isSuspended = true
            statusText = "일시 중지: \(reason)"
        case .restore:
            isRestoring = true
            lastResults = ProfileApplier.apply(profile, only: setting.kinds)
            lastRestoreAt = Date()
            statusText = "보호 중: \(profile.name) (복원 \(lastResults.filter { $0.outcome == .applied }.count)단계)"
            // 복원이 일으킨 재구성 알림이 지나간 뒤 감시 재개.
            Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(1200))
                self?.isRestoring = false
            }
        }
    }
}
