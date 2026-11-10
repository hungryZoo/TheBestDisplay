import Foundation
import Observation
import TBDCore
import TBDPlatform

/// 내장 자동 해제 실행기. 2초마다 설정 파일과 온라인 목록을 확인해 판단 결과를 수행. 앱 실행 중에만 동작. (SRS-ARR-006)
/// 종료 시와 다음 실행 시작 시 해제해 둔 내장 디스플레이를 재연결.
@MainActor
@Observable
final class AutoDisconnectController {
    private(set) var isEnabled = false
    private(set) var disconnectedBuiltin: UInt32?
    private(set) var message: String?

    @ObservationIgnored private let store = AutoDisconnectStore.standard
    @ObservationIgnored private var loop: Task<Void, Never>?

    func start() {
        guard loop == nil else { return }
        // 이전 실행이 내장을 해제한 채 끝났으면 먼저 재연결.
        var state = store.load()
        if let id = state.disconnectedBuiltin {
            try? ArrangementService.reconnect(id, timeout: 8)
            state.disconnectedBuiltin = nil
            try? store.save(state)
        }
        loop = Task { [weak self] in
            while !Task.isCancelled {
                self?.evaluate()
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    func setEnabled(_ enabled: Bool) {
        var state = store.load()
        state.enabled = enabled
        try? store.save(state)
        evaluate()
    }

    /// 종료 처리: 해제해 둔 내장 디스플레이 재연결.
    func shutdown() {
        loop?.cancel()
        var state = store.load()
        if let id = state.disconnectedBuiltin {
            try? ArrangementService.reconnect(id, timeout: 8)
            state.disconnectedBuiltin = nil
            try? store.save(state)
        }
    }

    private func evaluate() {
        var state = store.load()
        isEnabled = state.enabled
        disconnectedBuiltin = state.disconnectedBuiltin
        let online = DisplayCatalog.displays().map {
            AutoDisconnectPolicy.DisplayState(id: $0.id, isBuiltin: $0.identity.isBuiltin, isVirtual: VirtualDisplayService.shared.isVirtual($0.id) || $0.identity.vendorID == VirtualDisplayService.vendorID)
        }
        switch AutoDisconnectPolicy.decide(enabled: state.enabled, online: online, disconnectedBuiltin: state.disconnectedBuiltin) {
        case .none:
            break
        case .disconnectBuiltin(let id):
            do {
                // 상태를 먼저 기록: 해제 직후 앱이 죽어도 다음 실행에서 재연결.
                state.disconnectedBuiltin = id
                try store.save(state)
                try ArrangementService.disconnect(id)
                message = "외장 디스플레이 연결로 내장 디스플레이 연결 해제"
            } catch {
                state.disconnectedBuiltin = nil
                try? store.save(state)
                message = "내장 디스플레이 연결 해제 실패: \(RevertCoordinator.describe(error))"
            }
        case .reconnectBuiltin(let id):
            do {
                try ArrangementService.reconnect(id, timeout: 8)
                state.disconnectedBuiltin = nil
                try store.save(state)
                message = "내장 디스플레이 재연결"
            } catch {
                message = "내장 디스플레이 재연결 실패: \(RevertCoordinator.describe(error)). `tbdctl reconnect` 또는 재시동으로 복구"
            }
        }
        disconnectedBuiltin = state.disconnectedBuiltin
    }
}
