import Foundation
import TBDCore
import TBDPlatform

/// `tbdctl night-shift-sync <디스플레이> [--seconds <초>]` (PRD-CLR-006)
/// 지정 시간(기본 30초) 동안 Night Shift 상태에 맞춰 대상 디스플레이의 색온도를 조정한 뒤 원래대로 복원.
func runNightShiftSync(_ command: ParsedCommand) {
    let (display, _) = resolveDisplay(command.positionals[0])
    var seconds = 30.0
    if let text = command.options["--seconds"] {
        guard let value = Double(text), (1...3600).contains(value) else {
            writeError("오류: --seconds 값은 1-3600 범위의 초")
            exit(.usage)
        }
        seconds = value
    }
    guard NightShiftService.status()?.isSupported == true else {
        writeError("오류: 이 기기에서 Night Shift 상태를 읽을 수 없음")
        exit(.unsupported)
    }
    print("\(display.identity.name) Night Shift 연동 색온도. \(Int(seconds))초 동안 유지")
    let deadline = Date().addingTimeInterval(seconds)
    while Date() < deadline {
        if let status = NightShiftService.status() {
            let current = GammaService.shared.adjustment(for: display.id)
            if let next = NightShiftEmulation.adjusted(current, isEnabled: status.isEnabled, strength: status.strength) {
                do {
                    try GammaService.shared.apply(next, to: display.id)
                    let table = GammaService.currentTable(display.id)
                    print("  Night Shift \(status.isEnabled ? "켜짐" : "꺼짐"): 색온도 \(Int(next.temperature)) K, 전달 테이블 최댓값 빨강 \(String(format: "%.3f", table?.red.max() ?? 0)), 파랑 \(String(format: "%.3f", table?.blue.max() ?? 0))")
                    fflush(stdout)
                } catch {
                    writeError("오류: \(RevertCoordinator.describe(error))")
                }
            }
        }
        usleep(500_000)
    }
    GammaService.shared.resetAll()
    print("종료. 색온도 복원")
}

/// `tbdctl night-shift [on|off]` (PRD-CLR-003): 시스템 Night Shift 조회와 전환.
func runNightShift(_ command: ParsedCommand) {
    if let text = command.positionals.first {
        guard let enabled = Toggle.parse(text) else {
            writeError("오류: 인자는 on 또는 off")
            exit(.usage)
        }
        do {
            try NightShiftService.setEnabled(enabled)
        } catch {
            writeError("오류: \(RevertCoordinator.describe(error))")
            exit(.failure)
        }
    }
    guard let status = NightShiftService.status(), status.isSupported else {
        writeError("오류: 이 기기에서 Night Shift를 사용할 수 없음")
        exit(.unsupported)
    }
    print("Night Shift: \(status.isEnabled ? "켜짐" : "꺼짐")\(status.strength.map { ", 강도 \(Int(($0 * 100).rounded()))%" } ?? "")")
}
