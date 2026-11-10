import AppKit
import Foundation
import TBDCore
import TBDPlatform

/// `tbdctl combined-brightness <디스플레이> <0-100> [--seconds <초>]` (PRD-BRT-009)
/// 디밍은 프로세스 수명에 종속이므로 지정 시간(기본 10초) 동안 유지한 뒤 하드웨어 밝기와 디밍을 원래 값으로 복원.
@MainActor
func runCombinedBrightness(_ command: ParsedCommand) {
    let (display, _) = resolveDisplay(command.positionals[0])
    guard let value = CombinedBrightness.parsePercent(command.positionals[1]) else {
        writeError("오류: 결합 밝기 값은 0-100")
        exit(.usage)
    }
    var seconds = 10.0
    if let text = command.options["--seconds"] {
        guard let parsed = Double(text), (1...3600).contains(parsed) else {
            writeError("오류: --seconds 값은 1-3600 범위의 초")
            exit(.usage)
        }
        seconds = parsed
    }
    let probe = BrightnessService.supportsNative(display) ? nil : DDCService.probe(for: display)
    let method = BrightnessService.method(for: display, ddc: probe)
    guard method != .software else {
        writeError("오류: 이 디스플레이는 하드웨어 밝기 제어가 없어 결합 밝기 대상 아님. \(probe?.reason ?? "")")
        exit(.unsupported)
    }
    let ddcPair = probe?.values[VCPCode.brightness.rawValue]
    let ddcMaximum = ddcPair.flatMap { $0.count == 2 && $0[1] > 0 ? $0[1] : nil } ?? 100
    let original: Double? = method == .native
        ? BrightnessService.nativeBrightness(display.id)
        : ddcPair.flatMap { $0.count == 2 && $0[1] > 0 ? Double($0[0]) / Double($0[1]) : nil }
    do {
        let levels = try BrightnessService.applyCombined(value, to: display, method: method, ddcMaximum: ddcMaximum)
        RunLoop.current.run(until: Date().addingTimeInterval(1.0))
        let tableMaximum = GammaService.currentTableMaximum(display.id)
        let hardware = method == .native ? BrightnessService.nativeBrightness(display.id) : nil
        print("\(display.identity.name) 결합 밝기 \(Int((value * 100).rounded()))% 적용 (\(method.title)): \(CombinedBrightness.describe(levels))")
        print("  측정: 하드웨어 밝기 \(hardware.map { String(format: "%.1f%%", $0 * 100) } ?? "미확인"), 전달 테이블 최댓값 \(tableMaximum.map { String(format: "%.3f", $0) } ?? "미확인")")
        if let luminance = BrightnessService.backlightLuminance(for: display) { print("  휘도: \(luminance.summary)") }
    } catch {
        writeError("오류: \(RevertCoordinator.describe(error))")
        exit(.failure)
    }
    print("\(Int(seconds))초 동안 유지한 뒤 복원")
    RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    GammaService.shared.resetAll()
    if let original {
        switch method {
        case .native: try? BrightnessService.setNativeBrightness(original, on: display.id)
        case .ddc: try? BrightnessService.setDDCBrightness(original, for: display, maximum: ddcMaximum)
        case .software: break
        }
    }
    RunLoop.current.run(until: Date().addingTimeInterval(0.5))
    print("복원 완료" + (original.map { String(format: " (하드웨어 밝기 %.1f%%)", $0 * 100) } ?? ""))
}
