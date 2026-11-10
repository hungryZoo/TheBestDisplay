import SwiftUI
import TBDCore
import TBDPlatform

/// 링크 탭: 링크 속도, 레인, 대역폭, DSC와 FEC, 색 형식별 필요 대역폭, DPCD. (PRD-LNK-001-005)
struct LinkTab: View {
    @Environment(DisplayStore.self) private var store
    let display: DisplaySummary

    var body: some View {
        if let report = store.linkReports[display.id] {
            Form {
                linkSection(report)
                bandwidthSection(report)
                if !report.colorModeBudgets.isEmpty { budgetSection(report) }
                dpcdSection(store.linkDetails[display.id])
            }
            .formStyle(.grouped)
        } else {
            ContentUnavailableView("링크 정보를 읽을 수 없음", systemImage: "point.3.connected.trianglepath.dotted")
        }
    }

    private func linkSection(_ report: LinkReport) -> some View {
        Section("링크") {
            LabeledContent("전송 방식", value: report.transportName)
            if let state = report.state {
                LabeledContent("경로", value: state.transportDescription)
                LabeledContent("링크 속도", value: Self.rate(state))
                LabeledContent("레인", value: "\(state.laneCount)개 사용, 최대 \(state.maxLaneCount)개")
                LabeledContent("채널 부호화", value: report.encodingName ?? "미확인")
                LabeledContent("터널링", value: state.isTunneled ? "예 (Thunderbolt 또는 USB4)" : "아니요")
                LabeledContent("HPD", value: state.hpdDescription.isEmpty ? (state.hpdAsserted ? "감지" : "미감지") : state.hpdDescription)
                LabeledContent("싱크 수", value: String(state.sinkCount))
                if let type = state.downstreamPortType { LabeledContent("하류 포트 종류", value: type) }
            } else {
                Text("이 디스플레이의 전송 상태를 확인할 수 없음").foregroundStyle(.secondary)
            }
        }
    }

    private func bandwidthSection(_ report: LinkReport) -> some View {
        Section("대역폭") {
            if let utilization = report.utilization, let required = report.requiredGbps, let available = report.availableGbps {
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: min(utilization, 1))
                        .tint(utilization > 1 ? .red : utilization > 0.95 ? .orange : .accentColor)
                    Text(String(format: "현재 모드 %.2f Gbps / 유효 %.2f Gbps (사용률 %.1f%%)", required, available, utilization * 100))
                        .font(.callout.monospacedDigit())
                }
            }
            LabeledContent("원시 대역폭", value: Self.gbps(report.rawGbps))
            LabeledContent("유효 대역폭", value: Self.gbps(report.availableGbps))
            LabeledContent("현재 모드 필요 대역폭", value: Self.gbps(report.requiredGbps))
            LabeledContent("DSC", value: report.dscActive.map { $0 ? "사용" : "미사용" } ?? "미확인")
            LabeledContent("FEC", value: report.fecEnabled.map { $0 ? "사용" : "미사용" } ?? "미확인")
            ForEach(report.notes, id: \.self) { note in
                Label(note, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("필요 대역폭은 픽셀 클록 x 픽셀당 비트 수로 계산한 추정값. 유효 대역폭은 레인당 속도 x 레인 수 x 부호화 효율")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func budgetSection(_ report: LinkReport) -> some View {
        Section("색 형식별 필요 대역폭 (현재 타이밍, 무압축 기준)") {
            ForEach(report.colorModeBudgets) { budget in
                LabeledContent {
                    HStack(spacing: 8) {
                        Text(String(format: "%.2f Gbps", budget.requiredGbps)).monospacedDigit()
                        switch budget.verdict {
                        case .offered:
                            Badge(text: budget.needsDSC ? "선택 가능 (DSC)" : "선택 가능", color: .green)
                        case .exceedsBandwidth:
                            Badge(text: "대역폭 초과", color: .red)
                        case .notOffered:
                            Badge(text: "미제공", color: .gray)
                        }
                    }
                } label: {
                    Text(budget.descriptor.label)
                }
            }
            Text("대역폭 초과 형식은 주사율이나 해상도를 낮추거나, 더 빠른 링크(상위 케이블, 포트, 독) 또는 DSC 지원 디스플레이에서 선택 가능")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func dpcdSection(_ details: DisplayStore.LinkDetails?) -> some View {
        Section("DPCD (싱크 보고값)") {
            if let dpcd = details?.dpcd {
                LabeledContent("판", value: dpcd.revision ?? "미확인")
                LabeledContent("싱크 최대 링크", value: (dpcd.maxLaneRateGbps.map { String(format: "%.2f Gbps/레인 (%@)", $0, DPTransportState.rateName($0)) } ?? "미확인") + (dpcd.maxLaneCount.map { " x \($0)레인" } ?? ""))
                LabeledContent("채널 부호화", value: "8b/10b \(Self.support(dpcd.supports8b10b)), 128b/132b \(Self.support(dpcd.supports128b132b))")
                LabeledContent("DSC", value: Self.support(dpcd.supportsDSC) + (dpcd.dscRevision.map { " (판 \($0))" } ?? "") + (dpcd.dscEnabled.map { $0 ? ", 현재 사용" : ", 현재 미사용" } ?? ""))
                if display.identity.isBuiltin {
                    LabeledContent("레인 상태", value: "내장 패널은 상태 레지스터를 갱신하지 않아 표시 생략")
                } else if !dpcd.laneStatus.isEmpty {
                    LabeledContent("레인 상태", value: dpcd.laneStatus.map { "레인 \($0.lane) \($0.isGood ? "정상" : "미완료")" }.joined(separator: ", "))
                    LabeledContent("레인 간 정렬", value: dpcd.interlaneAlignDone == true ? "완료" : "미완료")
                }
            } else {
                Text("DPCD를 읽을 수 없음. 터널링 경로나 변환기에 따라 읽기가 거부될 수 있음")
                    .foregroundStyle(.secondary)
            }
            if let training = details?.training {
                LabeledContent("링크 훈련 결과", value: "레인 \(training.laneCount)개, 속도 부호 0x\(String(training.rateCode, radix: 16))" + (training.laneRateGbps.map { String(format: " (%.2f Gbps/레인%@)", $0, training.isStandardRate ? "" : ", 비표준") } ?? ""))
            }
        }
    }

    static func rate(_ state: DPTransportState) -> String {
        guard let rate = state.laneRateGbps else { return state.linkRateDescription.isEmpty ? "링크 없음" : state.linkRateDescription }
        let name = DPTransportState.rateName(rate)
        return String(format: "%.2f Gbps/레인", rate) + (name.hasSuffix("Gbps") ? " (비표준 속도)" : " (\(name))")
    }

    static func gbps(_ value: Double?) -> String {
        value.map { String(format: "%.2f Gbps", $0) } ?? "미확인"
    }

    static func support(_ value: Bool?) -> String {
        value.map { $0 ? "지원" : "미지원" } ?? "미확인"
    }
}
