import Foundation
import TBDCore
import TBDPlatform

/// `tbdctl hdr-profile <디스플레이> [sdr|hdr <프로파일 이름 또는 경로|none> | apply]` (PRD-CLR-007)
/// 지정만 저장하고, 자동 전환은 창 앱이 실행 중일 때 수행. `apply`는 현재 HDR 상태에 맞춰 한 번 적용.
func runHDRProfile(_ command: ParsedCommand) {
    let (display, _) = resolveDisplay(command.positionals[0])
    let store = HDRProfileStore.standard
    var preference = store.preference(for: display.identity)
    let available = ColorProfileService.available(for: display.id) + (ColorProfileService.current(for: display.id).map { [$0] } ?? [])
    func name(_ path: String?) -> String {
        guard let path else { return "지정 없음" }
        return available.first { $0.path == path }?.name ?? path
    }

    if command.positionals.count > 1 {
        let action = command.positionals[1].lowercased()
        switch action {
        case "apply":
            do {
                if let applied = try HDRProfileService.applyIfNeeded(for: display) {
                    print("적용: \(applied) (\(HDRService.isEnabled(display.id) ? "HDR" : "SDR") 상태)")
                } else {
                    print("전환할 프로파일 없음 (지정이 없거나 이미 적용됨)")
                }
            } catch {
                writeError("오류: \(RevertCoordinator.describe(error))")
                exit(.failure)
            }
            return
        case "sdr", "hdr":
            guard command.positionals.count > 2 else {
                writeError("오류: 프로파일 이름 또는 경로, 또는 none 필요")
                exit(.usage)
            }
            let text = command.positionals[2]
            var path: String?
            if text.lowercased() != "none" {
                guard let profile = ColorProfileCatalog.resolve(text, in: available) else {
                    writeError("오류: 일치하는 프로파일 없음 또는 여러 개와 일치: \(text). 목록은 `tbdctl color <디스플레이> --profiles`")
                    exit(.unsupported)
                }
                path = profile.path
            }
            if action == "sdr" { preference.sdrProfilePath = path } else { preference.hdrProfilePath = path }
            do {
                try store.save(preference, for: display.identity)
            } catch {
                writeError("오류: \(RevertCoordinator.describe(error))")
                exit(.failure)
            }
        default:
            writeError("오류: 두 번째 인자는 sdr, hdr, apply 중 하나")
            exit(.usage)
        }
    }
    print("\(display.identity.name) [id:\(display.id)] 상태별 색 프로파일")
    print("  SDR: \(name(preference.sdrProfilePath))")
    print("  HDR: \(name(preference.hdrProfilePath))")
    print("  현재: \(ColorProfileService.current(for: display.id)?.name ?? "확인 불가") (\(HDRService.isSupported(display.id) ? (HDRService.isEnabled(display.id) ? "HDR 켜짐" : "HDR 꺼짐") : "HDR 미지원"))")
}
