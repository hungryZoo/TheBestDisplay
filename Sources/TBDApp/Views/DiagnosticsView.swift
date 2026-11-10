import SwiftUI
import TBDCore

/// 연결 진단 화면: 포트별 연결 경로. (PRD-PRT-001-003)
struct DiagnosticsView: View {
    @Environment(DisplayStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if store.connectionPaths.isEmpty {
                    ContentUnavailableView("포트 정보를 읽을 수 없음", systemImage: "cable.connector.slash", description: Text("이 기기의 포트 컨트롤러 노드를 찾지 못함"))
                }
                ForEach(store.connectionPaths) { path in
                    PortPathCard(path: path)
                }
            }
            .padding(16)
        }
        .navigationTitle("연결 진단")
        .navigationSubtitle("포트 \(store.connectionPaths.count)개, 디스플레이 연결 \(store.connectionPaths.filter(\.reachesDisplay).count)개")
    }
}

private struct PortPathCard: View {
    let path: ConnectionPath

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
