import Foundation
import TBDCore
import TBDPlatform

/// `tbdctl preset <디스플레이> [<번호 또는 이름>] [--timeout <초>] [--yes] [--json]` (PRD-CLR-005, PRD-CLI-002)
func runPreset(_ command: ParsedCommand, json: Bool) {
    let (display, _) = resolveDisplay(command.positionals[0])
    let presets = PresetService.presets(for: display.id)

    guard command.positionals.count > 1 else {
        if json {
            printJSON(presets)
            return
        }
        guard !presets.isEmpty else {
            print("\(display.identity.name) [id:\(display.id)] 프리셋 없음")
            return
        }
        let usable = presets.filter(\.isValid)
        print("\(display.identity.name) [id:\(display.id)] 프리셋 \(usable.count)개 (빈 사용자 자리 \(presets.count - usable.count)개 생략)")
        for preset in usable {
            var tags: [String] = []
            if preset.isActive { tags.append("현재") }
            if preset.isDefault { tags.append("기본") }
            print("  \(preset.index). \(preset.name)\(tags.isEmpty ? "" : "  [\(tags.joined(separator: ", "))]")")
            if !preset.detail.isEmpty { print("     \(preset.detail)") }
        }
        return
    }

    guard !presets.isEmpty else {
        writeError("오류: 이 디스플레이는 프리셋 미지원")
        exit(.unsupported)
    }
    guard let target = DisplayPreset.resolve(command.positionals[1], in: presets) else {
        writeError("오류: 일치하는 프리셋 없음 또는 여러 개와 일치: \(command.positionals[1])")
        exit(.unsupported)
    }
    guard let current = presets.first(where: \.isActive) else {
        writeError("오류: 현재 프리셋을 확인할 수 없음")
        exit(.unsupported)
    }
    if target.index == current.index {
        print("이미 현재 프리셋: \(target.name)")
        return
    }
    guard target.isValid else {
        writeError("오류: 사용할 수 없는 프리셋: \(target.name)")
        exit(.unsupported)
    }
    performGuardedChange(DisplayChanges.presetChange(display: display, from: current, to: target), timeout: timeoutOption(command), assumeYes: command.has("--yes"))
}
