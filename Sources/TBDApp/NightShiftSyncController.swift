import Foundation
import Observation
import TBDCore
import TBDPlatform

/// Night Shift 연동 색온도 실행기: 3초마다 Night Shift 상태를 읽어 지정한 디스플레이의 색온도를 맞춤. 앱 실행 중에만 동작. (SRS-CLR-005)
@MainActor
@Observable
final class NightShiftSyncController {
    private(set) var displays: Set<UInt32> = []
    @ObservationIgnored private var loop: Task<Void, Never>?

    func isEnabled(_ display: UInt32) -> Bool { displays.contains(display) }

    func setEnabled(_ enabled: Bool, for display: UInt32) {
        if enabled {
            displays.insert(display)
            apply()
            if loop == nil {
                loop = Task { [weak self] in
                    while !Task.isCancelled {
                        try? await Task.sleep(for: .seconds(3))
                        self?.apply()
                    }
                }
            }
        } else {
            displays.remove(display)
            // 연동을 끄면 색온도를 원래대로.
            var adjustment = GammaService.shared.adjustment(for: display)
            adjustment.temperature = 6500
            try? GammaService.shared.apply(adjustment, to: display)
            if displays.isEmpty {
                loop?.cancel()
                loop = nil
            }
        }
    }

    private func apply() {
        guard let status = NightShiftService.status() else { return }
        for display in displays {
            let current = GammaService.shared.adjustment(for: display)
            if let next = NightShiftEmulation.adjusted(current, isEnabled: status.isEnabled, strength: status.strength) {
                try? GammaService.shared.apply(next, to: display)
            }
        }
    }
}
