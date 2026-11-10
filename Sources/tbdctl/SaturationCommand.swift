import Foundation
import TBDCore
import TBDPlatform

struct SaturationOutput: Encodable {
    var display: DisplayIdentity
    var saturationPercent: Int
    var baseProfile: String
    var currentProfile: String?
    var unavailableReason: String?
}

/// `tbdctl saturation <디스플레이> [<50-150> | reset] [--json]` (PRD-CLR-008)
/// 색 프로파일을 바꿔 채도를 조절. 지정은 시스템 설정으로 남으며 `reset`으로 조정 전 프로파일로 되돌림.
func runSaturation(_ command: ParsedCommand, json: Bool) {
    let (display, _) = resolveDisplay(command.positionals[0])
    if command.positionals.count > 1 {
        let text = command.positionals[1].lowercased()
        do {
            if text == "reset" {
                try SaturationService.reset(display)
            } else {
                guard let value = SaturationAdjustment.parsePercent(text) else {
                    writeError("오류: 채도는 50-150 범위의 백분율 또는 reset")
                    exit(.usage)
                }
                let status = SaturationService.status(for: display)
                if let reason = status.unavailableReason {
                    writeError("오류: \(reason)")
                    exit(.unsupported)
                }
                try SaturationService.apply(value, to: display)
            }
        } catch {
            writeError("오류: \(RevertCoordinator.describe(error))")
            exit(.failure)
        }
    }
    let status = SaturationService.status(for: display)
    let current = ColorProfileService.current(for: display.id)
    let output = SaturationOutput(display: display.identity, saturationPercent: Int((status.saturation * 100).rounded()), baseProfile: status.baseName, currentProfile: current?.name, unavailableReason: status.unavailableReason)
    if json {
        printJSON(output)
        return
    }
    print("\(display.identity.name) [id:\(display.id)] 채도: \(output.saturationPercent)%")
    print("  기준 프로파일: \(status.baseName)")
    print("  현재 프로파일: \(current?.name ?? "미확인")")
    if let reason = status.unavailableReason { print("  조정 불가: \(reason)") }
}
