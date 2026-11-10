import AppKit
import Foundation
import TBDCore
import TBDPlatform

/// `tbdctl overlay-dim <디스플레이> <강도 %> [--seconds <초>]` (PRD-BRT-007)
/// 강도 0-90. 프로세스 수명에 종속이므로 지정 시간(기본 10초) 동안 유지한 뒤 해제.
@MainActor
func runOverlayDim(_ command: ParsedCommand) {
    let (display, _) = resolveDisplay(command.positionals[0])
    guard let strength = OverlayDim.parsePercent(command.positionals[1]) else {
        writeError("오류: 강도는 0-90 범위의 백분율")
        exit(.usage)
    }
    var seconds = 10.0
    if let text = command.options["--seconds"] {
        guard let value = Double(text), (1...3600).contains(value) else {
            writeError("오류: --seconds 값은 1-3600 범위의 초")
            exit(.usage)
        }
        seconds = value
    }
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    RunLoop.current.run(until: Date().addingTimeInterval(0.2))
    do {
        try OverlayDimService.shared.setStrength(strength, for: display.id)
    } catch {
        writeError("오류: \(RevertCoordinator.describe(error))")
        exit(.failure)
    }
    RunLoop.current.run(until: Date().addingTimeInterval(0.5))
    if let info = OverlayDimService.shared.windowInfo(for: display.id) {
        // 윈도우 서버에 보이는 창인지 확인.
        let onScreen = (CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []).contains { ($0[kCGWindowNumber as String] as? Int) == info.number }
        print("\(display.identity.name) 오버레이 디밍 \(Int((strength * 100).rounded()))% 적용. 덮개 창 \(Int(info.frame.width)) x \(Int(info.frame.height)), 불투명도 \(String(format: "%.2f", info.alpha)), 화면 표시 \(onScreen ? "확인" : "미확인")")
    }
    print("\(Int(seconds))초 동안 유지한 뒤 해제")
    RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    OverlayDimService.shared.resetAll()
    RunLoop.current.run(until: Date().addingTimeInterval(0.2))
    print("해제 완료")
}
