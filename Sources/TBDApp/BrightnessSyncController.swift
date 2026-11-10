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
    /// 휘도 기준 동기화 사용 여부. 저장해 다음 실행에서도 유지. (PRD-BRT-010)
    var normalizesLuminance = UserDefaults.standard.bool(forKey: "brightnessSync.normalizesLuminance") {
        didSet {
            guard normalizesLuminance != oldValue else { return }
            UserDefaults.standard.set(normalizesLuminance, forKey: "brightnessSync.normalizesLuminance")
            // 실행 중이면 새 기준으로 다시 시작.
            if let sourceID { start(source: sourceID) }
        }
    }

    @ObservationIgnored private var service: BrightnessSyncService?
    @ObservationIgnored private var loop: Task<Void, Never>?
    /// 이전 실행의 마무리 작업 (진행 중인 동기화 1회가 끝난 뒤 디밍 복원). 새 실행은 이 작업 뒤에 시작.
    @ObservationIgnored private var finishing: Task<Void, Never>?

    func isSource(_ display: UInt32) -> Bool { sourceID == display }

    func start(source: UInt32) {
        stop()
        sourceID = source
        let service = BrightnessSyncService(normalizesLuminance: normalizesLuminance)
        self.service = service
        let previous = finishing
        loop = Task { [weak self] in
            await previous?.value
            while !Task.isCancelled {
                let displays = DisplayCatalog.displays()
                guard let live = displays.first(where: { $0.id == source }) else {
                    // 원본이 사라지면 종료.
                    self?.stop()
                    return
                }
                // 대상의 DDC 탐지가 응답 없는 디스플레이에서 수 초 걸리므로 메인 스레드 밖에서 수행. (T57 실측)
                let results = await Task.detached { service.syncOnce(source: live, displays: displays) }.value
                guard !Task.isCancelled else { return }
                if !results.isEmpty { self?.lastResults = results }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    func stop() {
        let running = loop
        let stopping = service
        loop?.cancel()
        loop = nil
        service = nil
        if running != nil || stopping != nil {
            let previous = finishing
            // 메인 스레드 밖에서 진행 중인 동기화 1회가 끝난 뒤에 복원해야 디밍이 남지 않음.
            finishing = Task {
                await previous?.value
                await running?.value
                stopping?.stop()
            }
        }
        sourceID = nil
        lastResults = []
    }
}
