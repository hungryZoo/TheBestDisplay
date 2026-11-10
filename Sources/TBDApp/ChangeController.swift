import Foundation
import Observation
import TBDCore
import TBDPlatform

/// `Timer` 기반 타이머.
final class FoundationRevertTimer: RevertTimer {
    private var timer: Timer?

    func start(seconds: TimeInterval, onFire: @escaping () -> Void) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { _ in onFire() }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}

/// 화면 변경 동작의 창 앱 쪽 진행 관리: 확인 대화상자, 알림, 실행 시 복귀 제안. (PRD-SAF-001, PRD-SAF-002)
@MainActor
@Observable
final class ChangeController {
    struct Confirmation: Equatable {
        var summary: String
        var deadline: Date
        var targetDisplayID: UInt32?
    }

    struct Banner: Equatable, Identifiable {
        enum Kind { case info, error }
        var id = UUID()
        var kind: Kind
        var text: String
    }

    private(set) var confirmation: Confirmation?
    private(set) var banner: Banner?
    /// 이전 실행에서 확인 없이 남은 복귀 정보.
    private(set) var pendingFromPreviousRun: PendingRevert?

    @ObservationIgnored private let coordinator: RevertCoordinator
    @ObservationIgnored private let store = PendingRevertStore.standard
    @ObservationIgnored private var pendingTarget: UInt32?
    @ObservationIgnored var onChanged: () -> Void = {}
    /// 사용자가 이 앱에서 구성 변경을 요청할 때 호출 (구성 보호의 일시 중지에 사용).
    @ObservationIgnored var onUserChange: () -> Void = {}

    init(timeout: TimeInterval = 15) {
        coordinator = RevertCoordinator(timeout: timeout, timer: FoundationRevertTimer(), store: store)
        pendingFromPreviousRun = store.load()
        coordinator.onNotice = { [weak self] notice in
            MainActor.assumeIsolated { self?.handle(notice) }
        }
    }

    /// 진행 중인 변경 유무. 화면이 관찰하도록 저장 속성으로 유지.
    private(set) var isBusy = false
    var timeout: TimeInterval { coordinator.timeout }

    /// 변경 요청. 진행 중이면 거부 알림.
    func request(_ change: RevertCoordinator.Change, targetDisplayID: UInt32?) {
        pendingTarget = targetDisplayID
        onUserChange()
        coordinator.request(change)
        isBusy = coordinator.state != .idle
        onChanged()
    }

    func confirm() {
        coordinator.confirm()
        isBusy = coordinator.state != .idle
        onChanged()
    }

    func cancel() {
        coordinator.cancel()
        isBusy = coordinator.state != .idle
        onChanged()
    }

    /// 온라인 디스플레이 목록이 바뀔 때 호출. 확인 대기 중인 대상이 사라졌으면 타이머 중단.
    func displaysChanged(onlineIDs: Set<UInt32>) {
        if let target = confirmation?.targetDisplayID, !onlineIDs.contains(target) {
            coordinator.targetDisconnected()
        }
    }

    func dismissBanner() { banner = nil }

    // MARK: - 이전 실행의 복귀 정보

    func applyPendingFromPreviousRun(displays: [DisplaySummary]) {
        guard let pending = pendingFromPreviousRun else { return }
        do {
            try PendingRevertApplier.apply(pending, displays: displays)
            store.clear()
            banner = Banner(kind: .info, text: "복귀 완료: \(pending.summary)")
        } catch {
            banner = Banner(kind: .error, text: "복귀 실패: \(RevertCoordinator.describe(error))")
        }
        pendingFromPreviousRun = nil
        onChanged()
    }

    func discardPendingFromPreviousRun() {
        store.clear()
        pendingFromPreviousRun = nil
    }

    // MARK: - 알림 처리

    private func handle(_ notice: RevertCoordinator.Notice) {
        switch notice {
        case .awaitingConfirmation(let summary, let timeout):
            confirmation = Confirmation(summary: summary, deadline: Date().addingTimeInterval(timeout), targetDisplayID: pendingTarget)
        case .committed(let summary):
            confirmation = nil
            banner = Banner(kind: .info, text: "적용 완료: \(summary)")
        case .reverted(let summary):
            confirmation = nil
            banner = Banner(kind: .info, text: "이전 설정으로 복귀: \(summary)")
        case .applyFailed(let summary, let message):
            confirmation = nil
            banner = Banner(kind: .error, text: "적용 실패 (\(summary)): \(message)")
        case .revertFailed(let summary, let message):
            confirmation = nil
            banner = Banner(kind: .error, text: "복귀 실패 (\(summary)): \(message). 시스템 설정의 디스플레이에서 직접 변경 필요")
        case .commitFailed(let summary, let message):
            confirmation = nil
            banner = Banner(kind: .error, text: "확정 실패 (\(summary)): \(message)")
        case .rejectedBusy:
            banner = Banner(kind: .error, text: "진행 중인 변경의 확인이 끝난 뒤 다시 시도")
        case .targetDisconnected(let summary):
            confirmation = nil
            banner = Banner(kind: .error, text: "변경 대상 디스플레이의 연결이 끊김 (\(summary)). 재연결 후 앱을 다시 열면 복귀 제안 표시")
            pendingFromPreviousRun = store.load()
        }
        // 알림은 상태 전이 도중에 오므로 전이가 끝난 뒤의 상태를 다음 런 루프에서 반영.
        DispatchQueue.main.async { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.isBusy = self.coordinator.state != .idle
            }
        }
        onChanged()
    }
}
