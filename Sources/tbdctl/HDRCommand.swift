import Foundation
import TBDCore
import TBDPlatform

/// `tbdctl hdr <디스플레이> [on|off] [--timeout <초>] [--yes] [--json]` (PRD-HDR-001-003, PRD-CLI-002)
func runHDR(_ command: ParsedCommand, json: Bool) {
    let (display, displays) = resolveDisplay(command.positionals[0])
    let edid = EDIDSource.record(for: display, among: displays)?.parsed
    let status = HDRService.status(for: display, edid: edid)

    guard command.positionals.count > 1 else {
        if json {
            printJSON(status)
            return
        }
        print("\(display.identity.name) [id:\(display.id)] HDR \(status.stateLabel)")
        print("  지원 EOTF: \(status.supportedEOTFs.isEmpty ? "EDID 미보고" : status.supportedEOTFs.joined(separator: ", "))")
        print("  최대 휘도: \(status.maxLuminance.map { String(format: "%.0f cd/m²", $0) } ?? "EDID 미보고")")
        print("  EDR 헤드룸: 현재 \(status.currentEDRHeadroom.map { String(format: "%.2f", $0) } ?? "미확인")배, 최대 \(status.maxEDRHeadroom.map { String(format: "%.2f", $0) } ?? "미확인")배")
        return
    }

    guard let enable = Toggle.parse(command.positionals[1]) else {
        writeError("오류: 두 번째 인자는 on 또는 off")
        exit(.usage)
    }
    guard status.isSupported else {
        writeError("오류: 이 디스플레이는 HDR 미지원")
        exit(.unsupported)
    }
    if status.isEnabled == enable {
        print("이미 HDR \(status.stateLabel)")
        return
    }
    let change = DisplayChanges.hdrChange(display: display, enable: enable) { used in
        print("전환 경로: \(used.rawValue)")
    }
    performGuardedChange(change, timeout: timeoutOption(command), assumeYes: command.has("--yes"))
}
