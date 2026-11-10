import Foundation
import TBDCore
import TBDPlatform

/// `tbdctl dither <디스플레이> [on|off] [--json]` (PRD-COL-008)
func runDither(_ command: ParsedCommand, json: Bool) {
    let (display, _) = resolveDisplay(command.positionals[0])
    guard command.positionals.count > 1 else {
        let state = DitherService.isEnabled(for: display)
        if json {
            struct Output: Encodable { var display: DisplayIdentity; var enabled: Bool? }
            printJSON(Output(display: display.identity, enabled: state))
        } else {
            print("\(display.identity.name) [id:\(display.id)] GPU 디더링: \(state.map { $0 ? "켜짐" : "꺼짐" } ?? "확인 불가")")
        }
        if state == nil { exit(.unsupported) }
        return
    }
    guard let enable = Toggle.parse(command.positionals[1]) else {
        writeError("오류: 두 번째 인자는 on 또는 off")
        exit(.usage)
    }
    do {
        try DitherService.setEnabled(enable, for: display)
        print("\(display.identity.name) GPU 디더링 \(enable ? "켜짐" : "꺼짐"). 재시동 또는 디스플레이 재연결 시 시스템 기본값으로 복귀")
    } catch {
        writeError("오류: \(RevertCoordinator.describe(error))")
        exit(.unsupported)
    }
}
