import Foundation
import TBDCore
import TBDPlatform

struct LinkOutput: Encodable {
    var display: DisplayIdentity
    var report: LinkReport
    var dpcd: DPCDInfo?
    var linkTraining: LinkTrainingData?
    var frlLinkDataRaw: [UInt8]?
}

func gbps(_ value: Double?) -> String {
    value.map { String(format: "%.2f Gbps", $0) } ?? "미확인"
}

/// `tbdctl link <디스플레이> [--json]` (PRD-LNK-001-005)
func runLink(_ command: ParsedCommand, json: Bool) {
    let (display, displays) = resolveDisplay(command.positionals[0])
    let signal = SignalService.signalInfo(for: display)
    let edidDSC = EDIDSource.record(for: display, among: displays)?.parsed.sinkCapabilities.supportsDSC
    let dsc = signal.map { DSCAssessment.assess(signal: $0, edidSupportsDSC: edidDSC, sourceSupportsDSC: SignalService.sourceSupportsDSC()) }
    let report = LinkService.report(for: display, signal: signal, dsc: dsc)
    let dpcd = LinkService.dpcd(for: display)
    let training = LinkService.linkTraining(for: display)
    let frl = report.transportName.hasPrefix("HDMI") ? LinkService.frlLinkDataRaw(for: display) : nil

    if json {
        printJSON(LinkOutput(display: display.identity, report: report, dpcd: dpcd, linkTraining: training, frlLinkDataRaw: frl))
        return
    }

    print("\(display.identity.name) [id:\(display.id)] \(report.transportName)")
    if let state = report.state {
        print("링크")
        print("  경로: \(state.transportDescription)")
        print("  속도: \(state.laneRateGbps.map { rate in String(format: "%.2f Gbps/레인", rate) + (DPTransportState.rateName(rate).hasSuffix("Gbps") ? " (비표준 속도)" : " (\(DPTransportState.rateName(rate)))") } ?? state.linkRateDescription), 레인 \(state.laneCount)개 (최대 \(state.maxLaneCount)개), 부호화 \(report.encodingName ?? "미확인")")
        print("  터널링: \(state.isTunneled ? "예" : "아니요"), HPD: \(state.hpdDescription.isEmpty ? (state.hpdAsserted ? "감지" : "미감지") : state.hpdDescription), 싱크 수: \(state.sinkCount)")
        if let type = state.downstreamPortType { print("  하류 포트 종류: \(type)") }
    } else {
        print("링크: 전송 상태 확인 불가")
    }
    print("대역폭")
    print("  원시 \(gbps(report.rawGbps)), 유효 \(gbps(report.availableGbps)), 현재 모드 필요 \(gbps(report.requiredGbps))\(report.utilization.map { String(format: ", 사용률 %.1f%%", $0 * 100) } ?? "")")
    print("  DSC: \(report.dscActive.map { $0 ? "사용" : "미사용" } ?? "미확인"), FEC: \(report.fecEnabled.map { $0 ? "사용" : "미사용" } ?? "미확인")")
    for note in report.notes { print("  참고: \(note)") }
    if let frl { print("  HDMI FRL 링크 데이터 (원시): \(frl.map { String(format: "%02x", $0) }.joined(separator: " "))") }
    if !report.colorModeBudgets.isEmpty {
        print("색 형식별 필요 대역폭 (현재 타이밍, 무압축 기준)")
        for budget in report.colorModeBudgets {
            let verdict: String
            switch budget.verdict {
            case .offered: verdict = budget.needsDSC ? "선택 가능 (DSC)" : "선택 가능"
            case .exceedsBandwidth: verdict = "선택 불가: 유효 대역폭 \(gbps(report.availableGbps)) 초과"
            case .notOffered: verdict = "선택 불가: 현재 타이밍에서 미제공"
            }
            let label = budget.descriptor.label
            print("  \(label + String(repeating: " ", count: max(0, 50 - label.count))) \(String(format: "%6.2f Gbps", budget.requiredGbps))  \(verdict)")
        }
    }
    if let dpcd {
        print("DPCD")
        print("  판 \(dpcd.revision ?? "미확인"), 싱크 최대 \(dpcd.maxLaneRateGbps.map { String(format: "%.2f Gbps/레인 (%@)", $0, DPTransportState.rateName($0)) } ?? "미확인") x \(dpcd.maxLaneCount.map(String.init) ?? "미확인")레인")
        print("  채널 부호화: 8b/10b \(describe(dpcd.supports8b10b)), 128b/132b \(describe(dpcd.supports128b132b)). DSC \(describe(dpcd.supportsDSC))\(dpcd.dscRevision.map { " (판 \($0))" } ?? ""), 현재 DSC \(dpcd.dscEnabled.map { $0 ? "사용" : "미사용" } ?? "미확인")")
        print("  다운스프레드: \(describe(dpcd.supportsDownspread)), 확장 프레이밍: \(describe(dpcd.supportsEnhancedFraming)), TPS3: \(describe(dpcd.supportsTPS3))")
        print("  HDCP (싱크 능력): \(dpcd.hdcpSummary)")
        if display.identity.isBuiltin {
            print("  레인 상태: 내장 패널은 상태 레지스터를 갱신하지 않아 표시 생략")
        } else if !dpcd.laneStatus.isEmpty {
            print("  레인 상태: " + dpcd.laneStatus.map { "레인 \($0.lane) \($0.isGood ? "정상" : "미완료")" }.joined(separator: ", ") + ", 레인 간 정렬 \(dpcd.interlaneAlignDone == true ? "완료" : "미완료")")
        }
    } else {
        print("DPCD: 읽기 불가 (터널링 경로 또는 미지원)")
    }
    if let training {
        print("링크 훈련 결과: 레인 \(training.laneCount)개, 속도 부호 0x\(String(training.rateCode, radix: 16))\(training.laneRateGbps.map { String(format: " (%.2f Gbps/레인%@)", $0, training.isStandardRate ? "" : ", 비표준") } ?? "")")
    }
}
