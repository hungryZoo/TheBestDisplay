import Foundation
import Observation
import TBDCore
import TBDPlatform

/// 상태별 색 프로파일 자동 전환 실행기: 3초마다 지정이 있는 디스플레이의 HDR 상태를 확인해 프로파일 전환. 앱 실행 중에만 동작. (PRD-CLR-007)
@MainActor
@Observable
final class HDRProfileController {
    private(set) var lastMessage: String?
    @ObservationIgnored private var loop: Task<Void, Never>?

    func start() {
        guard loop == nil else { return }
        loop = Task { [weak self] in
            while !Task.isCancelled {
                self?.evaluate()
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    func evaluate() {
        guard !HDRProfileStore.standard.loadAll().isEmpty else { return }
        for display in DisplayCatalog.displays() {
            if let name = try? HDRProfileService.applyIfNeeded(for: display) {
                lastMessage = "\(display.identity.name): \(HDRService.isEnabled(display.id) ? "HDR" : "SDR") 상태에 맞춰 \(name) 적용"
            }
        }
    }
}
