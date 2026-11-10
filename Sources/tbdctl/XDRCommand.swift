import AppKit
import Foundation
import TBDCore
import TBDPlatform

struct XDROutput: Encodable {
    var display: DisplayIdentity
    var supported: Bool
    var potentialHeadroom: Double
    var currentHeadroom: Double
    var maximumBoostPercent: Int
    /// 적용 중 측정값. 조회만 하면 nil.
    var appliedBoostPercent: Int?
    var transferTableMaximum: Double?
}

/// `tbdctl xdr <디스플레이> [<배율 %>] [--seconds <초>] [--json]` (PRD-BRT-005)
/// 업스케일은 프로세스 수명에 종속이므로 지정 시간(기본 10초) 동안 유지한 뒤 해제.
@MainActor
func runXDR(_ command: ParsedCommand, json: Bool) {
    let (display, _) = resolveDisplay(command.positionals[0])
    // 화면 정보(NSScreen)와 EDR 유지 창에 AppKit 연결 필요.
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    RunLoop.current.run(until: Date().addingTimeInterval(0.2))

    var output = XDROutput(
        display: display.identity,
        supported: XDRBoostService.isSupported(display.id),
        potentialHeadroom: XDRBoostService.potentialHeadroom(display.id),
        currentHeadroom: XDRBoostService.currentHeadroom(display.id),
        maximumBoostPercent: Int((XDRBoostService.maximumBoost(display.id) * 100).rounded())
    )

    guard command.positionals.count > 1 else {
        if json {
            printJSON(output)
            return
        }
        print("\(display.identity.name) [id:\(display.id)] XDR 밝기 업스케일: \(output.supported ? "가능" : "불가 (EDR 헤드룸 없음)")")
        print("  EDR 헤드룸: 현재 \(String(format: "%.2f", output.currentHeadroom))배, 최대 \(String(format: "%.2f", output.potentialHeadroom))배")
        if output.supported { print("  배율 범위: 100-\(output.maximumBoostPercent)%") }
        return
    }

    guard let percent = Double(command.positionals[1]), (100...200).contains(percent) else {
        writeError("오류: 배율은 100-200 범위의 백분율")
        exit(.usage)
    }
    var seconds = 10.0
    if let text = command.options["--seconds"] {
        guard let value = Double(text), (1...3600).contains(value) else {
            writeError("오류: --seconds 값은 1-3600 범위의 초")
            exit(.usage)
        }
        seconds = value
    }
    guard output.supported else {
        writeError("오류: 이 디스플레이는 EDR 헤드룸이 없어 XDR 밝기 업스케일 불가")
        exit(.unsupported)
    }
    do {
        try XDRBoostService.shared.setBoost(percent / 100, for: display.id)
    } catch {
        writeError("오류: \(RevertCoordinator.describe(error))")
        exit(.failure)
    }
    RunLoop.current.run(until: Date().addingTimeInterval(1.0))
    let applied = XDRBoostService.shared.boost(for: display.id)
    output.appliedBoostPercent = Int((applied * 100).rounded())
    output.transferTableMaximum = GammaService.currentTableMaximum(display.id)
    output.currentHeadroom = XDRBoostService.currentHeadroom(display.id)
    if json {
        printJSON(output)
    } else {
        print("\(display.identity.name) XDR 밝기 업스케일 \(output.appliedBoostPercent ?? 0)% 적용. 전달 테이블 최댓값 \(String(format: "%.3f", output.transferTableMaximum ?? 0)), 현재 EDR 헤드룸 \(String(format: "%.2f", output.currentHeadroom))배")
        print("\(Int(seconds))초 동안 유지한 뒤 해제")
    }
    RunLoop.current.run(until: Date().addingTimeInterval(max(0, seconds - 1)))
    XDRBoostService.shared.resetAll()
    RunLoop.current.run(until: Date().addingTimeInterval(0.3))
    if !json { print("해제 완료. 전달 테이블 최댓값 \(String(format: "%.3f", GammaService.currentTableMaximum(display.id) ?? 0))") }
}
