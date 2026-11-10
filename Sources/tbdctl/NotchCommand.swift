import Foundation
import TBDCore
import TBDPlatform

/// `tbdctl notch <디스플레이> [show|hide] [--timeout <초>] [--yes] [--json]` (PRD-MOD-011)
/// show는 화면 전체를 쓰는 모드, hide는 notch 아래 16:10 영역만 쓰는 모드로 전환.
func runNotch(_ command: ParsedCommand, json: Bool) {
    let (display, _) = resolveDisplay(command.positionals[0])
    let modes = ModeService.modes(for: display.id)
    guard let current = ModeService.currentMode(for: display.id, in: modes) else {
        writeError("오류: 현재 모드를 확인할 수 없음")
        exit(.unsupported)
    }
    let pair = ModeCatalog.notchPair(modes, current: current)
    guard command.positionals.count > 1 else {
        if json {
            struct Output: Encodable { var hasNotchModes: Bool; var usesNotchArea: Bool?; var full: String?; var belowNotch: String? }
            printJSON(Output(hasNotchModes: pair != nil, usesNotchArea: pair.map { $0.full.modeNumber == current.modeNumber }, full: pair?.full.label, belowNotch: pair?.belowNotch.label))
            return
        }
        guard let pair else {
            print("\(display.identity.name) [id:\(display.id)] notch 모드 쌍 없음 (현재 \(current.label))")
            return
        }
        print("\(display.identity.name) [id:\(display.id)] 현재 \(pair.full.modeNumber == current.modeNumber ? "화면 전체 사용 (notch 영역 포함)" : "notch 아래 영역만 사용")")
        print("  전체 모드: \(pair.full.label), notch 아래 모드: \(pair.belowNotch.label)")
        return
    }
    let action = command.positionals[1].lowercased()
    guard action == "show" || action == "hide" else {
        writeError("오류: 두 번째 인자는 show 또는 hide")
        exit(.usage)
    }
    guard let pair else {
        writeError("오류: 이 디스플레이의 현재 해상도에는 notch 모드 쌍이 없음")
        exit(.unsupported)
    }
    let target = action == "show" ? pair.full : pair.belowNotch
    if target.modeNumber == current.modeNumber {
        print("이미 해당 모드: \(target.label)")
        return
    }
    performGuardedChange(DisplayChanges.modeChange(display: display, from: current, to: target), timeout: timeoutOption(command), assumeYes: command.has("--yes"))
}
