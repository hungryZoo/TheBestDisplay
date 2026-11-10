import SwiftUI
import TBDCore

/// 연결 진단 화면: 발견 항목, 포트별 연결 경로와 점검 단계, 이벤트 기록, 보고서 내보내기. (PRD-PRT-001-003, PRD-DGN-001-006)
struct DiagnosticsView: View {
    @Environment(DisplayStore.self) private var store
    @State private var redact = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                findingsSection
                portsSection
                eventsSection
            }
            .padding(16)
        }
        .navigationTitle("연결 진단")
        .navigationSubtitle("포트 \(store.connectionPaths.count)개, 디스플레이 연결 \(store.connectionPaths.filter(\.reachesDisplay).count)개, 발견 항목 \(store.diagnosis.findings.count)건")
        .toolbar {
            ToolbarItem {
                Menu("보고서 내보내기", systemImage: "square.and.arrow.up") {
                    Button("JSON으로 저장") { ReportSaver.save(store: store, redact: redact, asText: false) }
                    Button("텍스트로 저장") { ReportSaver.save(store: store, redact: redact, asText: true) }
                    Divider()
                    Toggle("일련번호 가림", isOn: $redact)
                }
                .help("진단 보고서 내보내기 (Command + E)")
            }
        }
    }

    private var findingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("발견 항목").font(.title3.bold())
            if store.diagnosis.findings.isEmpty {
                Label("발견된 문제 없음", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
            }
            ForEach(store.diagnosis.findings) { finding in
                FindingCard(finding: finding)
            }
        }
    }

    private var portsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("포트와 연결 경로").font(.title3.bold())
            if store.connectionPaths.isEmpty {
                Text("이 기기의 포트 컨트롤러 노드를 찾지 못함").foregroundStyle(.secondary)
            }
            ForEach(store.connectionPaths) { path in
                PortPathCard(path: path, diagnosis: store.diagnosis.portDiagnoses.first { $0.port == path.port.key })
            }
        }
    }

    private var eventsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("이벤트 기록").font(.title3.bold())
            if store.eventLog.events.isEmpty {
                Text("앱을 연 뒤 감지된 변화 없음. 케이블 연결과 분리, 모드와 색 모드 변경, 링크 변화가 여기에 기록됨")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            ForEach(store.eventLog.events.reversed()) { event in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(event.date, format: .dateTime.hour().minute().second())
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Badge(text: event.kind.title, color: Self.color(event.kind))
                    Text(event.subject).fontWeight(.medium)
                    Text(event.detail).foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
                .textSelection(.enabled)
            }
        }
    }

    static func color(_ kind: DisplayEvent.Kind) -> Color {
        switch kind {
        case .displayConnected, .portConnected: .green
        case .displayDisconnected, .portDisconnected: .red
        case .linkChanged, .hpdChanged: .orange
        case .modeChanged, .colorModeChanged, .hdrChanged: .blue
        }
    }
}

private struct FindingCard: View {
    let finding: Finding

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if let subject = finding.subject { Badge(text: subject, color: .gray) }
                    Text(finding.title).fontWeight(.semibold)
                }
                Text(finding.detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("조치").font(.caption.bold()).foregroundStyle(color)
                    Text(finding.remedy).font(.callout)
                }
                Text(finding.code).font(.caption2.monospaced()).foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
        }
        .textSelection(.enabled)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(color.opacity(0.3)))
    }

    private var color: Color {
        switch finding.severity {
        case .error: .red
        case .warning: .orange
        case .info: .blue
        }
    }

    private var symbol: String {
        switch finding.severity {
        case .error: "xmark.octagon.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .info: "info.circle.fill"
        }
    }
}

private struct PortPathCard: View {
    let path: ConnectionPath
    let diagnosis: PortDiagnosis?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(path.isConnected ? Color.accentColor : .secondary)
                Text(path.port.key.label).font(.headline)
                if path.reachesDisplay {
                    Badge(text: "디스플레이 연결", color: .green)
                } else if path.steps.contains(where: { $0.status == .broken }) {
                    Badge(text: "문제 발견", color: .red)
                } else if !path.isConnected {
                    Badge(text: "연결 없음", color: .gray)
                }
                Spacer()
                Text(path.port.transportsSupported.isEmpty ? "데이터 전송 없음" : "지원: " + path.port.transportsSupported.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if path.isConnected {
                // 경로 요약: 단계 이름을 화살표로 연결.
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(path.steps.enumerated()), id: \.element.id) { index, step in
                            if index > 0 {
                                Image(systemName: "arrow.right").font(.caption).foregroundStyle(.tertiary)
                            }
                            StepChip(step: step)
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(path.steps) { step in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Image(systemName: StepChip.symbol(step.status))
                                .foregroundStyle(StepChip.color(step.status))
                                .frame(width: 16)
                            Text(Self.kindName(step.kind))
                                .foregroundStyle(.secondary)
                                .frame(width: 64, alignment: .leading)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(step.title)
                                Text(step.detail).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .textSelection(.enabled)
                if let diagnosis, !diagnosis.isIdle {
                    Divider()
                    // 미출력 점검 단계. (PRD-DGN-001)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("화면 출력 점검: " + (diagnosis.isFullyPassed ? "전 단계 통과" : "\(diagnosis.firstFailure?.title ?? "") 단계 미통과"))
                            .font(.callout.weight(.medium))
                        HStack(spacing: 6) {
                            ForEach(diagnosis.checks) { check in
                                Label(check.stage.title, systemImage: Self.checkSymbol(check.result))
                                    .font(.caption)
                                    .foregroundStyle(Self.checkColor(check.result))
                                    .help(check.detail)
                            }
                        }
                        if let failed = diagnosis.checks.first(where: { $0.result == .fail }) {
                            Text(failed.detail).font(.caption).foregroundStyle(.red)
                        }
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
    }

    private var icon: String {
        switch path.port.key.type {
        case "HDMI": "tv"
        case "MagSafe 3": "powerplug"
        default: "cable.connector"
        }
    }

    static func kindName(_ kind: PathStep.Kind) -> String {
        switch kind {
        case .port: "포트"
        case .cable: "케이블"
        case .dock: "독, 허브"
        case .link: "영상 링크"
        case .display: "디스플레이"
        }
    }

    static func checkSymbol(_ result: PortDiagnosis.Result) -> String {
        switch result {
        case .pass: "checkmark.circle.fill"
        case .fail: "xmark.circle.fill"
        case .skipped: "minus.circle"
        }
    }

    static func checkColor(_ result: PortDiagnosis.Result) -> Color {
        switch result {
        case .pass: .green
        case .fail: .red
        case .skipped: .secondary
        }
    }
}

struct StepChip: View {
    let step: PathStep

    var body: some View {
        Text(step.title)
            .font(.callout)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Self.color(step.status).opacity(0.16), in: Capsule())
            .overlay(Capsule().strokeBorder(Self.color(step.status).opacity(0.5)))
    }

    static func color(_ status: PathStep.Status) -> Color {
        switch status {
        case .ok: .green
        case .unknown: .gray
        case .broken: .red
        }
    }

    static func symbol(_ status: PathStep.Status) -> String {
        switch status {
        case .ok: "checkmark.circle.fill"
        case .unknown: "questionmark.circle"
        case .broken: "xmark.octagon.fill"
        }
    }
}
