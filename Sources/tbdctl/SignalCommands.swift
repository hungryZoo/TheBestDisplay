import Foundation
import TBDCore
import TBDPlatform

struct SignalOutput: Encodable {
    var display: DisplayIdentity
    var transport: String?
    var currentTimingID: Int?
    var currentColorID: Int?
    var currentTiming: TimingElement?
    var currentColor: ColorElement?
    var linkData: VideoLinkData?
    var selectableColorModes: [ColorElement]
    var dsc: DSCAssessment
    var timings: [TimingElement]?
}

func loadSignal(_ display: DisplaySummary, displays: [DisplaySummary]) -> (SignalInfo, DSCAssessment) {
    guard let info = SignalService.signalInfo(for: display) else {
        writeError("오류: 신호 정보를 읽을 수 없음 (프레임버퍼 노드 대응 실패)")
        exit(.unsupported)
    }
    let edidDSC = EDIDSource.record(for: display, among: displays)?.parsed.sinkCapabilities.supportsDSC
    return (info, DSCAssessment.assess(signal: info, edidSupportsDSC: edidDSC, sourceSupportsDSC: SignalService.sourceSupportsDSC()))
}

/// `tbdctl signal <디스플레이> [--timings] [--json]` (PRD-COL-001, PRD-COL-002, PRD-COL-004, PRD-COL-005)
func runSignal(_ command: ParsedCommand, json: Bool) {
    let (display, displays) = resolveDisplay(command.positionals[0])
    let (info, dsc) = loadSignal(display, displays: displays)
    let timing = info.currentTiming
    let current = info.currentColor

    if json {
        printJSON(SignalOutput(
            display: display.identity, transport: info.transport,
            currentTimingID: info.currentTimingID, currentColorID: info.currentColorID,
            currentTiming: timing, currentColor: current, linkData: info.linkData,
            selectableColorModes: info.selectableColorModes, dsc: dsc,
            timings: command.has("--timings") ? info.timings : nil
        ))
        return
    }

    print("\(display.identity.name) [id:\(display.id)] 전송 \(info.transport ?? "미확인")")
    if let link = info.linkData {
        print("송출 신호 (링크 데이터)")
        print("  \(link.colorLabel), 색 공간 \(Colorimetry.name(link.colorimetry))")
        print("  \(link.hActive) x \(link.vActive), \(DisplaySummary.formatHz(link.refreshRate)) Hz, 총 \(link.hTotal) x \(link.vTotal), 픽셀 클록 \(String(format: "%.2f", link.pixelClockHz / 1e6)) MHz")
    } else {
        print("송출 신호 (링크 데이터): \(display.identity.isBuiltin ? "내장 패널은 해당 없음" : "읽기 실패")")
    }
    if let timing {
        print("현재 타이밍 [id:\(timing.id)]: \(timing.label), 총 \(timing.hTotal) x \(timing.vTotal), 픽셀 클록 \(String(format: "%.2f", timing.pixelClockHz / 1e6)) MHz")
    }
    if let current {
        print("현재 색 모드 [id:\(current.id)]: \(current.label), 색 공간 \(Colorimetry.name(current.colorimetry))")
    }
    if let mode = ModeService.currentMode(for: display.id, in: ModeService.modes(for: display.id)), let bits = info.linkData?.bitsPerComponent ?? current?.bitsPerComponent {
        print("심도 비교: \(DepthComparison.note(framebufferBits: mode.bitsPerSample, linkBits: bits))")
    }
    print("DSC: \(dsc.summary). 소스 \(describe(dsc.sourceSupportsDSC)), 싱크 \(describe(dsc.sinkSupportsDSC)). DSC 필요 모드 \(dsc.dscRequiredModeCount)개, 불필요 모드 \(dsc.dscFreeModeCount)개")
    print("선택 가능한 색 모드 \(info.selectableColorModes.count)개 (현재 타이밍 기준)")
    for element in info.selectableColorModes.sorted(by: colorOrder) {
        var tags: [String] = []
        if element.id == info.currentColorID { tags.append("현재") }
        if timing?.requiresDSC(element.id) == true { tags.append("DSC") }
        if timing?.unsafeColorElementIDs.contains(element.id) == true { tags.append("안전하지 않음") }
        let idText = "id:\(element.id)".padding(toLength: 7, withPad: " ", startingAt: 0)
        print("  \(idText) \(element.label), \(Colorimetry.name(element.colorimetry))\(tags.isEmpty ? "" : "  [\(tags.joined(separator: ", "))]")")
    }
    if command.has("--timings") {
        print("타이밍 \(info.timings.count)개")
        for t in info.timings.sorted(by: { ($0.hActive * $0.vActive, $0.refreshRate) > ($1.hActive * $1.vActive, $1.refreshRate) }) {
            let colors = t.colorModes.filter { !$0.isVirtual }.count
            print("  id:\(t.id)\t\(t.label), 총 \(t.hTotal) x \(t.vTotal), \(String(format: "%.2f", t.pixelClockHz / 1e6)) MHz, 색 모드 \(colors)개\(t.dscRequiredColorElementIDs.isEmpty ? "" : ", DSC 필요 \(t.dscRequiredColorElementIDs.count)개")\(t.isPreferred ? " [선호]" : "")\(t.id == info.currentTimingID ? " [현재]" : "")")
        }
    }
}

func describe(_ value: Bool?) -> String {
    value.map { $0 ? "지원" : "미지원" } ?? "미확인"
}

/// 표시 순서: SDR 먼저, RGB 먼저, 비트 심도 내림차순, Full 먼저.
func colorOrder(_ a: ColorElement, _ b: ColorElement) -> Bool {
    func key(_ e: ColorElement) -> (Int, Int, Int, Int, Int) {
        (e.eotf.rawValue, e.pixelEncoding.isRGB ? 0 : e.pixelEncoding.rawValue == 3 ? 1 : e.pixelEncoding.rawValue == 2 ? 2 : 3, -e.bitsPerComponent, e.dynamicRange.rawValue, e.colorimetry)
    }
    return key(a) < key(b)
}

/// `tbdctl set-timing <디스플레이> <id:번호 | 폭x높이@주사율> [--timeout <초>] [--yes]` (PRD-COL-007, PRD-CLI-002)
/// 타이밍 목록은 `tbdctl signal <디스플레이> --timings`로 확인.
func runSetTiming(_ command: ParsedCommand) {
    let (display, displays) = resolveDisplay(command.positionals[0])
    guard !display.identity.isBuiltin else {
        writeError("오류: 내장 디스플레이는 타이밍 직접 선택 대상이 아님")
        exit(.unsupported)
    }
    let (info, _) = loadSignal(display, displays: displays)
    guard let target = TimingSelection.resolve(command.positionals[1], in: info.timings) else {
        writeError("오류: 일치하는 타이밍 없음: \(command.positionals[1]). 형식은 id:<번호> 또는 <폭>x<높이>@<주사율>, 목록은 `tbdctl signal --timings`")
        exit(.unsupported)
    }
    switch TimingSelection.plan(signal: info, target: target) {
    case .failure(.alreadyCurrent):
        print("이미 현재 타이밍: \(target.label)")
    case .failure(let error):
        writeError("오류: \(error.localizedDescription)")
        exit(.unsupported)
    case .success(let color):
        guard let current = info.currentTiming, let currentColor = info.currentColor else {
            writeError("오류: 현재 타이밍과 색 모드를 확인할 수 없음")
            exit(.unsupported)
        }
        print("타이밍 [id:\(target.id)] \(target.label), 색 모드 [id:\(color.id)] \(color.label)")
        let change = DisplayChanges.timingChange(display: display, from: current, previousColor: currentColor, to: target, color: color)
        performGuardedChange(change, timeout: timeoutOption(command), assumeYes: command.has("--yes"))
    }
}

/// `tbdctl set-color <디스플레이> <색 모드> [--timeout <초>] [--yes]` (PRD-COL-003, PRD-CLI-002)
func runSetColor(_ command: ParsedCommand) {
    let (display, displays) = resolveDisplay(command.positionals[0])
    guard let spec = ColorSpec.parse(command.positionals[1]) else {
        writeError("오류: 색 모드 형식은 id:<번호> 또는 <rgb|ycbcr444|ycbcr422|ycbcr420>[:<bpc>][:<full|limited>][:<sdr|pq|hlg>]")
        exit(.usage)
    }
    let (info, _) = loadSignal(display, displays: displays)
    guard let timingID = info.currentTimingID, let current = info.currentColor else {
        writeError("오류: 현재 타이밍과 색 모드를 확인할 수 없음")
        exit(.unsupported)
    }
    guard let target = spec.resolve(in: info.selectableColorModes, current: current) else {
        writeError("오류: 현재 타이밍에서 선택할 수 없는 색 모드: \(command.positionals[1]). `tbdctl signal`로 목록 확인")
        exit(.unsupported)
    }
    if target.id == current.id {
        print("이미 현재 색 모드: \(target.label)")
        return
    }
    let change = DisplayChanges.colorChange(display: display, timingID: timingID, from: current, to: target)
    performGuardedChange(change, timeout: timeoutOption(command), assumeYes: command.has("--yes"))
}
