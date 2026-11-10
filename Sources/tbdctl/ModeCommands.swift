import CoreGraphics
import Foundation
import TBDCore
import TBDPlatform

struct ModesOutput: Encodable {
    var display: DisplayIdentity
    var currentModeNumber: Int32?
    var modeCount: Int
    var publicModeCount: Int
    var renderingLimits: RenderingLimits?
    /// 프레임버퍼가 보고한 한도. (PRD-MOD-014)
    var framebufferLimits: FramebufferLimits?
    var modes: [DisplayMode]
}

/// `tbdctl modes <디스플레이> [--hidpi] [--outside-default] [--json]` (PRD-MOD-001, PRD-MOD-002, PRD-MOD-006)
func runModes(_ command: ParsedCommand, json: Bool) {
    let (display, _) = resolveDisplay(command.positionals[0])
    let all = ModeService.modes(for: display.id)
    let current = ModeService.currentMode(for: display.id, in: all)
    var filter = ModeFilter()
    if command.has("--hidpi") { filter.hiDPI = .hiDPIOnly }
    if command.has("--outside-default") { filter.onlyOutsideSystemDefaultList = true }
    let modes = all.filter(filter.matches)

    if json {
        let publicCount = (CGDisplayCopyAllDisplayModes(display.id, [kCGDisplayShowDuplicateLowResolutionModes: kCFBooleanTrue] as CFDictionary) as? [CGDisplayMode])?.count ?? 0
        printJSON(ModesOutput(display: display.identity, currentModeNumber: current?.modeNumber, modeCount: modes.count, publicModeCount: publicCount, renderingLimits: ModeCatalog.renderingLimits(all), framebufferLimits: ModeService.framebufferLimits(for: display), modes: modes))
        return
    }
    print("\(display.identity.name) [id:\(display.id)] 모드 \(modes.count)개 (전체 \(all.count)개)")
    if let current { print("현재: \(current.label) [mode:\(current.modeNumber)]") }
    if let limits = ModeCatalog.renderingLimits(all) { print("렌더링 한계 (모드 목록 기준): \(limits.summary)") }
    if let limits = ModeService.framebufferLimits(for: display) { print("렌더링 한계 (프레임버퍼 보고): \(limits.summary)") }
    for group in ModeCatalog.groups(modes) {
        let rates = group.modes.map { m in
            "\(DisplaySummary.formatHz(m.refreshRate))\(m.isVRR ? "v" : "")\(m.modeNumber == current?.modeNumber ? "*" : "")"
        }
        let pad = (group.label + (group.modes.contains(where: \.isNative) ? " (원본)" : "")).padding(toLength: 28, withPad: " ", startingAt: 0)
        print("  \(pad) 픽셀 \(group.pixelWidth)x\(group.pixelHeight)  \(group.aspectRatio)  Hz: \(rates.joined(separator: " "))\(group.isOutsideSystemDefaultList ? "  [시스템 설정 목록 밖]" : "")")
    }
    print("표기: * 현재 모드, v 가변 주사율")
}

/// `tbdctl set-mode <디스플레이> <모드> [--timeout <초>] [--yes]` (PRD-MOD-003, PRD-MOD-005, PRD-CLI-002)
func runSetMode(_ command: ParsedCommand) {
    let (display, _) = resolveDisplay(command.positionals[0])
    guard let spec = ModeSpec.parse(command.positionals[1]) else {
        writeError("오류: 모드 형식은 <폭>x<높이>[@<주사율>][:hidpi|:lodpi] 또는 mode:<번호>")
        exit(.usage)
    }
    let modes = ModeService.modes(for: display.id)
    let current = ModeService.currentMode(for: display.id, in: modes)
    let target: DisplayMode
    do {
        target = try spec.resolve(in: modes, current: current)
    } catch let error as ModeSpec.ResolveError {
        writeError("오류: \(error.message)")
        exit(.unsupported)
    } catch {
        writeError("오류: \(error)")
        exit(.failure)
    }
    if target.modeNumber == current?.modeNumber {
        print("이미 현재 모드: \(target.label)")
        return
    }
    guard let previous = current else {
        writeError("오류: 현재 모드를 확인할 수 없어 복귀 정보를 만들 수 없음")
        exit(.failure)
    }
    var method: ModeService.Method?
    if let text = command.options["--method"] {
        guard let parsed = ModeService.Method.allCases.first(where: { $0.rawValue.lowercased() == text.lowercased() }) else {
            writeError("오류: --method 값은 \(ModeService.Method.allCases.map(\.rawValue).joined(separator: ", ")) 중 하나")
            exit(.usage)
        }
        method = parsed
    }
    let change = DisplayChanges.modeChange(display: display, from: previous, to: target, method: method) { used in
        print("전환 경로: \(used.rawValue)")
    }
    performGuardedChange(change, timeout: timeoutOption(command), assumeYes: command.has("--yes"))
}

/// `tbdctl revert-pending [--discard]` (PRD-SAF-002): 확인 없이 종료된 변경의 복귀 정보 처리.
func runRevertPending(_ command: ParsedCommand) {
    let store = PendingRevertStore.standard
    guard let pending = store.load() else {
        print("복귀 정보 없음")
        return
    }
    if command.has("--discard") {
        store.clear()
        print("복귀 정보 삭제: \(pending.summary)")
        return
    }
    do {
        try PendingRevertApplier.apply(pending, displays: DisplayCatalog.displays())
        store.clear()
        print("복귀 완료: \(pending.summary)")
    } catch {
        writeError("오류: 복귀 실패: \(RevertCoordinatorDescribe(error))")
        exit(.failure)
    }
}
