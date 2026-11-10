import Foundation
import TBDCore
import TBDPlatform

struct DSCOutput: Encodable {
    var display: DisplayIdentity
    var assessment: DSCAssessment
    var canEnable: Bool
    var canDisable: Bool
    var enableTarget: ColorElement?
    var disableTarget: ColorElement?
    var enableRefusal: String?
    var disableRefusal: String?
}

/// `tbdctl dsc <디스플레이> [on|off] [--timeout <초>] [--yes] [--json]` (PRD-COL-006, PRD-CLI-002)
func runDSC(_ command: ParsedCommand, json: Bool) {
    let (display, displays) = resolveDisplay(command.positionals[0])
    let (info, assessment) = loadSignal(display, displays: displays)
    let enablePlan = DSCControl.plan(signal: info, enable: true)
    let disablePlan = DSCControl.plan(signal: info, enable: false)

    func target(_ plan: Result<ColorElement, DSCControl.Unavailable>) -> ColorElement? {
        if case .success(let element) = plan { return element }
        return nil
    }
    func refusal(_ plan: Result<ColorElement, DSCControl.Unavailable>) -> String? {
        if case .failure(let error) = plan { return error.localizedDescription }
        return nil
    }

    guard command.positionals.count > 1 else {
        if json {
            printJSON(DSCOutput(
                display: display.identity, assessment: assessment,
                canEnable: target(enablePlan) != nil, canDisable: target(disablePlan) != nil,
                enableTarget: target(enablePlan), disableTarget: target(disablePlan),
                enableRefusal: refusal(enablePlan), disableRefusal: refusal(disablePlan)
            ))
            return
        }
        print("\(display.identity.name) [id:\(display.id)] DSC: \(assessment.summary)")
        print("  소스 \(describe(assessment.sourceSupportsDSC)), 싱크 \(describe(assessment.sinkSupportsDSC))")
        print("  현재 타이밍의 색 모드: DSC 필요 \(assessment.dscRequiredModeCount)개, 불필요 \(assessment.dscFreeModeCount)개")
        print("  켜기: \(target(enablePlan).map { "가능. 색 모드 [id:\($0.id)] \($0.label)로 전환" } ?? "불가. \(refusal(enablePlan) ?? "")")")
        print("  끄기: \(target(disablePlan).map { "가능. 색 모드 [id:\($0.id)] \($0.label)로 전환" } ?? "불가. \(refusal(disablePlan) ?? "")")")
        return
    }

    guard let enable = Toggle.parse(command.positionals[1]) else {
        writeError("오류: 두 번째 인자는 on 또는 off")
        exit(.usage)
    }
    switch enable ? enablePlan : disablePlan {
    case .failure(.alreadyInState(let enabled)):
        print("이미 DSC \(enabled ? "사용" : "미사용") 상태")
    case .failure(let error):
        writeError("오류: \(error.localizedDescription)")
        exit(.unsupported)
    case .success(let element):
        guard let timingID = info.currentTimingID, let current = info.currentColor else {
            writeError("오류: 현재 타이밍과 색 모드를 확인할 수 없음")
            exit(.unsupported)
        }
        print("DSC \(enable ? "켜기" : "끄기"): 색 모드 [id:\(element.id)] \(element.label)")
        let change = DisplayChanges.colorChange(display: display, timingID: timingID, from: current, to: element)
        performGuardedChange(change, timeout: timeoutOption(command), assumeYes: command.has("--yes"))
    }
}
