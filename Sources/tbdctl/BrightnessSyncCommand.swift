import Foundation
import TBDCore
import TBDPlatform

/// `tbdctl brightness-sync <원본 디스플레이> [--seconds <초>]` (PRD-BRT-006)
/// 지정 시간(기본 30초) 동안 원본의 밝기를 다른 디스플레이에 맞춤. 소프트웨어 디밍 대상은 종료 시 원래 밝기로 복원.
func runBrightnessSync(_ command: ParsedCommand) {
    let (source, _) = resolveDisplay(command.positionals[0])
    var seconds = 30.0
    if let text = command.options["--seconds"] {
        guard let value = Double(text), (1...3600).contains(value) else {
            writeError("오류: --seconds 값은 1-3600 범위의 초")
            exit(.usage)
        }
        seconds = value
    }
    guard BrightnessSyncService.sourceLevel(source) != nil else {
        writeError("오류: 원본 디스플레이의 밝기를 읽을 수 없음")
        exit(.unsupported)
    }
    let service = BrightnessSyncService()
    let deadline = Date().addingTimeInterval(seconds)
    print("\(source.identity.name) 밝기를 다른 디스플레이에 동기화. \(Int(seconds))초 동안 유지")
    var appliedCount = 0
    while Date() < deadline {
        let displays = DisplayCatalog.displays()
        guard let live = displays.first(where: { $0.id == source.id }) else {
            writeError("오류: 원본 디스플레이가 온라인 상태가 아님")
            break
        }
        for result in service.syncOnce(source: live, displays: displays) {
            appliedCount += 1
            let percent = Int((result.level * 100).rounded())
            if let failure = result.failure {
                print("  \(result.displayName): \(result.method.title) \(percent)% 적용 실패: \(failure)")
            } else {
                let table = GammaService.currentTableMaximum(result.displayID).map { String(format: ", 전달 테이블 최댓값 %.3f", $0) } ?? ""
                print("  \(result.displayName): \(result.method.title) \(percent)%\(result.method == .software ? table : "")")
            }
            fflush(stdout)
        }
        usleep(500_000)
    }
    service.stop()
    print("동기화 종료. 적용 \(appliedCount)회")
}
