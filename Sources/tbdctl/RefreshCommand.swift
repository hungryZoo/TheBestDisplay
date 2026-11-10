import AppKit
import Foundation
import TBDCore
import TBDPlatform

/// `tbdctl refresh <디스플레이> [--seconds <초>] [--json]` (PRD-MOD-008)
@MainActor
func runRefresh(_ command: ParsedCommand, json: Bool) {
    let (display, _) = resolveDisplay(command.positionals[0])
    var seconds = 2.0
    if let text = command.options["--seconds"] {
        guard let value = Double(text), (0.5...30).contains(value) else {
            writeError("오류: --seconds 값은 0.5-30 범위의 초")
            exit(.usage)
        }
        seconds = value
    }
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    RunLoop.current.run(until: Date().addingTimeInterval(0.2))
    guard let meter = RefreshRateMeter(display: display) else {
        writeError("오류: 이 디스플레이는 화면 갱신 콜백을 만들 수 없음 (미러 대상 또는 비활성)")
        exit(.unsupported)
    }
    meter.start()
    RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    let result = meter.stop()
    if json {
        printJSON(result)
    } else {
        print("\(display.identity.name) [id:\(display.id)] \(result.summary)")
        if let low = result.minIntervalMs, let high = result.maxIntervalMs {
            print(String(format: "  갱신 간격: 최소 %.3f ms, 최대 %.3f ms, 측정 시간 %.2f초", low, high, result.durationSeconds))
        }
        print("  소프트웨어 콜백 시각 기준 관측값. 가변 주사율 화면은 콘텐츠에 따라 값이 달라짐")
    }
    if result.measuredHz == nil { exit(.failure) }
}
