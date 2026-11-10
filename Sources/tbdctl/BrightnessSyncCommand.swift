import Foundation
import TBDCore
import TBDPlatform

/// `tbdctl brightness-sync <원본 디스플레이> [--seconds <초>] [--nits]` (PRD-BRT-006, PRD-BRT-010)
/// `--nits`는 휘도 기준: 원본의 휘도를 대상의 최대 휘도 기준값으로 나눠 대상 밝기를 정함.
/// 지정 시간(기본 30초) 동안 원본의 밝기를 다른 디스플레이에 맞춤. 소프트웨어 디밍 대상은 종료 시 원래 밝기로 복원.
func runBrightnessSync(_ command: ParsedCommand) {
    let (source, _) = resolveDisplay(command.positionals[0])
    var seconds = 30.0
    if let text = command.options["--seconds"] {
        guard let value = Double(text), (1...3600).contains(value) else {
            writeError("오류: --seconds 값은 1-3600 범위의 초")
            exit(.usage)
        }
        seconds = value
    }
    guard BrightnessSyncService.sourceLevel(source) != nil else {
        writeError("오류: 원본 디스플레이의 밝기를 읽을 수 없음")
        exit(.unsupported)
    }
    let normalize = command.flags.contains("--nits")
    let service = BrightnessSyncService(normalizesLuminance: normalize)
    if normalize {
        guard let level = BrightnessSyncService.sourceLevel(source), let nits = service.sourceNits(source, level: level) else {
            writeError("오류: 원본 디스플레이의 휘도를 알 수 없음. `tbdctl luminance-reference <디스플레이> <cd/m²>`로 최대 휘도 지정")
            exit(.unsupported)
        }
        print("휘도 기준 동기화. 원본 휘도 \(BacklightLuminance.format(nits)) cd/m²")
        for target in DisplayCatalog.displays() where target.id != source.id {
            if let reference = service.reference(for: target) {
                print("  \(target.identity.name): 최대 휘도 \(BacklightLuminance.format(reference.maximumNits)) cd/m² (\(reference.source.title))")
            } else {
                print("  \(target.identity.name): 최대 휘도 기준값 없음. 비율 기준으로 처리")
            }
        }
    }
    let deadline = Date().addingTimeInterval(seconds)
    print("\(source.identity.name) 밝기를 다른 디스플레이에 동기화. \(Int(seconds))초 동안 유지")
    var appliedCount = 0
    while Date() < deadline {
        let displays = DisplayCatalog.displays()
        guard let live = displays.first(where: { $0.id == source.id }) else {
            writeError("오류: 원본 디스플레이가 온라인 상태가 아님")
            break
        }
        for result in service.syncOnce(source: live, displays: displays) {
            appliedCount += 1
            let percent = Int((result.level * 100).rounded())
            if let failure = result.failure {
                print("  \(result.displayName): \(result.method.title) \(percent)% 적용 실패: \(failure)")
            } else {
                let table = GammaService.currentTableMaximum(result.displayID).map { String(format: ", 전달 테이블 최댓값 %.3f", $0) } ?? ""
                let nits = result.targetNits.map { ", 목표 \(BacklightLuminance.format($0)) cd/m²" } ?? ""
                print("  \(result.displayName): \(result.method.title) \(percent)%\(nits)\(result.method == .software ? table : "")")
            }
            fflush(stdout)
        }
        usleep(500_000)
    }
    service.stop()
    print("동기화 종료. 적용 \(appliedCount)회")
}

struct LuminanceReferenceOutput: Encodable {
    var display: DisplayIdentity
    var userMaximumNits: Double?
    var edidMaximumNits: Double?
    var reference: LuminanceReference?
}

/// `tbdctl luminance-reference <디스플레이> [<cd/m²> | reset] [--json]` (PRD-BRT-010)
/// 디스플레이의 최대 휘도 기준값 조회, 지정, 해제. 추정 휘도 표시와 휘도 기준 동기화에 사용.
func runLuminanceReference(_ command: ParsedCommand, json: Bool) {
    let (display, _) = resolveDisplay(command.positionals[0])
    let store = LuminanceReferenceStore.standard
    if command.positionals.count > 1 {
        let text = command.positionals[1].lowercased()
        do {
            if text == "reset" {
                try store.set(nil, for: display.identity)
            } else {
                guard let value = Double(text) else {
                    writeError("오류: 값은 cd/m² 숫자 또는 reset")
                    exit(.usage)
                }
                try store.set(value, for: display.identity)
            }
        } catch let error as LuminanceReferenceError {
            writeError("오류: \(error.localizedDescription)")
            exit(.usage)
        } catch {
            writeError("오류: \(RevertCoordinator.describe(error))")
            exit(.failure)
        }
    }
    let edid = BrightnessSyncService.edidMaximum(display)
    let output = LuminanceReferenceOutput(display: display.identity, userMaximumNits: store.userValue(for: display.identity), edidMaximumNits: edid, reference: store.reference(for: display.identity, edidMaximum: edid))
    if json {
        printJSON(output)
        return
    }
    print("\(display.identity.name) [id:\(display.id)] 최대 휘도 기준값")
    print("  사용자 지정: \(output.userMaximumNits.map { "\(BacklightLuminance.format($0)) cd/m²" } ?? "없음")")
    print("  EDID: \(edid.map { "\(BacklightLuminance.format($0)) cd/m²" } ?? "미보고")")
    print("  적용 값: \(output.reference.map { "\(BacklightLuminance.format($0.maximumNits)) cd/m² (\($0.source.title))" } ?? "없음")")
    if BrightnessService.backlightLuminance(for: display) != nil {
        print("  이 디스플레이는 백라이트 휘도를 직접 읽으므로 원본으로 쓸 때 기준값을 쓰지 않음")
    }
}
