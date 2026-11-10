import Foundation
import TBDCore
import TBDPlatform

struct ColorOutput: Encodable {
    var display: DisplayIdentity
    var currentProfile: ColorProfileInfo?
    var availableProfiles: [ColorProfileInfo]
    var nightShift: NightShiftStatus?
    var trueTone: TrueToneStatus?
}

/// `tbdctl color <디스플레이> [--profiles] [--json]` (PRD-CLR-001, PRD-CLR-003, PRD-CLR-004): 색 프로파일, Night Shift, True Tone 상태.
func runColor(_ command: ParsedCommand, json: Bool) {
    let (display, _) = resolveDisplay(command.positionals[0])
    let available = ColorProfileService.available(for: display.id)
    // `--set <이름 또는 경로>`: 색 프로파일 지정. (PRD-CLR-001)
    if let text = command.options["--set"] {
        let candidates = available + (ColorProfileService.current(for: display.id).map { [$0] } ?? [])
        let profile = ColorProfileCatalog.resolve(text, in: candidates)
            ?? (FileManager.default.fileExists(atPath: text) ? ColorProfileInfo(name: URL(fileURLWithPath: text).deletingPathExtension().lastPathComponent, path: text, isFactoryDefault: false) : nil)
        guard let profile else {
            writeError("오류: 일치하는 프로파일 없음 또는 여러 개와 일치: \(text)")
            exit(.unsupported)
        }
        do {
            try ColorProfileService.set(profile, for: display.id)
        } catch {
            writeError("오류: \(RevertCoordinator.describe(error))")
            exit(.failure)
        }
    }
    let current = ColorProfileService.current(for: display.id)
    let nightShift = NightShiftService.status()
    let trueTone = TrueToneService.status()
    if json {
        printJSON(ColorOutput(display: display.identity, currentProfile: current, availableProfiles: available, nightShift: nightShift, trueTone: trueTone))
        return
    }
    print("\(display.identity.name) [id:\(display.id)]")
    print("  색 프로파일: \(current.map { "\($0.name)\($0.isFactoryDefault ? " (기본)" : "")" } ?? "확인 불가"), 지정 가능 \(available.count)개")
    if command.has("--profiles") {
        for profile in available { print("    \(profile.name)\(profile.isFactoryDefault ? " (기본)" : "")  \(profile.path)") }
    }
    if let nightShift {
        print("  Night Shift: \(nightShift.isSupported ? (nightShift.isEnabled ? "켜짐" : "꺼짐") : "미지원"), 강도 \(nightShift.strength.map { String(format: "%.0f%%", $0 * 100) } ?? "미확인"), \(nightShift.scheduleName)")
    } else {
        print("  Night Shift: 확인 불가")
    }
    print("  True Tone: \(trueTone?.stateLabel ?? "확인 불가")")
}
