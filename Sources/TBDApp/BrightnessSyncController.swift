import Foundation
import Observation
import TBDCore
import TBDPlatform

/// 밝기 동기화 실행기: 원본 디스플레이의 밝기를 1초마다 읽어 다른 디스플레이에 적용. 앱 실행 중에만 동작. (PRD-BRT-006)
@MainActor
@Observable
final class BrightnessSyncController {
    private(set) var sourceID: UInt32?
    private(set) var lastResults: [BrightnessSyncResult] = []

    @ObservationIgnored private var service: BrightnessSyncService?
    @ObservationIgnored private var loop: Task<Void, Never>?

    func isSource(_ display: UInt32) -> Bool { sourceID == display }

    func start(source: UInt32) {
        stop()
        sourceID = source
        let service = BrightnessSyncService()
        self.service = service
        loop = Task { [weak self] in
            while !Task.isCancelled {
                let displays = DisplayCatalog.displays()
                guard let live = displays.first(where: { $0.id == source }) else {
                    // 원본이 사라지면 종료.
                    self?.stop()
                    return
                }
                let results = service.syncOnce(source: live, displays: displays)
                if !results.isEmpty { self?.lastResults = results }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    func stop() {
        loop?.cancel()
        loop = nil
        service?.stop()
        service = nil
        sourceID = nil
        lastResults = []
    }
}
