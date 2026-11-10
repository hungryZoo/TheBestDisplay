import SwiftUI
import TBDCore

/// 사이드바 선택 항목.
enum SidebarItem: Hashable {
    case display(UInt32)
    case diagnostics
    case profiles
}

/// 사이드바와 상세 영역. (SRS-UI-001, PRD-APP-002)
struct ContentView: View {
    @Environment(DisplayStore.self) private var store
    @Environment(ChangeController.self) private var changes
    @State private var selection: SidebarItem?

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("디스플레이") {
                    ForEach(store.displays) { display in
                        DisplayRow(display: display)
                            .tag(SidebarItem.display(display.id))
                    }
                    if store.displays.isEmpty {
                        Text("온라인 디스플레이 없음")
                            .foregroundStyle(.secondary)
                    }
                }
                Section("도구") {
                    Label("연결 진단", systemImage: "cable.connector")
                        .tag(SidebarItem.diagnostics)
                    Label("프로파일", systemImage: "square.stack.3d.up")
                        .tag(SidebarItem.profiles)
                }
            }
            .navigationSplitViewColumnWidth(min: 230, ideal: 260)
        } detail: {
            detail
                .safeAreaInset(edge: .top, spacing: 0) {
                    if let banner = changes.banner {
                        BannerView(banner: banner) { changes.dismissBanner() }
                    }
                }
        }
        .sheet(item: confirmationBinding) { item in
            ChangeConfirmationSheet(confirmation: item.value)
        }
        .alert("이전 실행에서 확인하지 않은 변경", isPresented: pendingBinding, presenting: changes.pendingFromPreviousRun) { _ in
            Button("복귀") { changes.applyPendingFromPreviousRun(displays: store.displays) }
            Button("현재 설정 유지", role: .cancel) { changes.discardPendingFromPreviousRun() }
        } message: { pending in
            Text(pending.summary)
        }
        .toolbar {
            ToolbarItem {
                Button("새로 고침", systemImage: "arrow.clockwise") { store.refresh() }
                    .help("디스플레이 상태 다시 읽기 (Command + R)")
            }
        }
        .onAppear(perform: selectDefault)
        .onChange(of: store.displays.map(\.id)) { _, _ in selectDefault() }
    }

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .display(let id):
            if let display = store.display(id: id) {
                DisplayDetailView(display: display)
            } else {
                ContentUnavailableView("디스플레이 연결 해제됨", systemImage: "display.trianglebadge.exclamationmark")
            }
        case .diagnostics:
            PendingFeatureView(title: "연결 진단", systemImage: "cable.connector", stage: "P3")
        case .profiles:
            PendingFeatureView(title: "프로파일", systemImage: "square.stack.3d.up", stage: "P5")
        case nil:
            ContentUnavailableView("디스플레이 선택", systemImage: "display")
        }
    }

    private struct ConfirmationItem: Identifiable {
        let value: ChangeController.Confirmation
        var id: String { value.summary }
    }

    private var confirmationBinding: Binding<ConfirmationItem?> {
        Binding(get: { changes.confirmation.map(ConfirmationItem.init) }, set: { _ in })
    }

    private var pendingBinding: Binding<Bool> {
        Binding(get: { changes.pendingFromPreviousRun != nil && changes.confirmation == nil }, set: { _ in })
    }

    /// 선택이 없거나 선택한 디스플레이가 사라진 경우 첫 디스플레이 선택.
    private func selectDefault() {
        if case .display(let id) = selection, store.display(id: id) != nil { return }
        if case .diagnostics = selection { return }
        if case .profiles = selection { return }
        selection = store.displays.first.map { .display($0.id) }
    }
}

private struct DisplayRow: View {
    let display: DisplaySummary

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(display.identity.name)
                    if display.isMain {
                        Text("메인")
                            .font(.caption2)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(.quaternary, in: Capsule())
                    }
                }
                Text("\(display.identity.isBuiltin ? "내장" : "외장"), \(display.modeDescription)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: display.identity.isBuiltin ? "laptopcomputer" : "display")
        }
        .padding(.vertical, 2)
    }
}

/// 이후 단계에서 구현될 화면의 자리 표시.
struct PendingFeatureView: View {
    let title: String
    let systemImage: String
    let stage: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text("개발 단계 \(stage)에서 제공 예정")
        }
    }
}
