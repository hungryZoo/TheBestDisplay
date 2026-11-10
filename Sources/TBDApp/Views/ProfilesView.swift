import SwiftUI
import TBDCore
import TBDPlatform

/// 프로파일 화면: 현재 구성 저장, 적용, 이름 변경, 삭제, 적용 결과, 구성 보호. (PRD-PRF-001-004)
struct ProfilesView: View {
    @Environment(DisplayStore.self) private var store
    @Environment(ChangeController.self) private var changes
    @Environment(ProtectionController.self) private var protection
    @State private var profiles: [DisplayProfile] = []
    @State private var newName = ""
    @State private var renaming: DisplayProfile?
    @State private var renameText = ""
    @State private var results: [ProfileStepResult] = []
    @State private var resultTitle = ""
    @State private var message: String?

    private let profileStore = ProfileStore.standard

    var body: some View {
        Form {
            Section("현재 구성 저장") {
                HStack {
                    TextField("프로파일 이름", text: $newName)
                    Button("저장") { save() }
                        .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                Text("저장 항목: 디스플레이별 해상도와 주사율, 색 모드, HDR, 회전, 위치, 메인 지정, 미러, 밝기(시스템 밝기 제어 대상)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("프로파일") {
                if profiles.isEmpty {
                    Text("저장된 프로파일 없음").foregroundStyle(.secondary)
                }
                ForEach(profiles) { profile in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(profile.name).fontWeight(.medium)
                            Text(profile.createdAt, format: .dateTime.year().month().day().hour().minute())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            if protection.setting?.profileID == profile.id { Badge(text: "보호 중", color: .blue) }
                            Button("적용") { apply(profile) }
                                .disabled(changes.isBusy)
                            if protection.setting?.profileID == profile.id {
                                Button("보호 해제") { protection.disable() }
                            } else {
                                Button("보호") { protection.enable(profile: profile) }
                                    .help("구성이 이 프로파일에서 벗어나면 다시 적용 (해상도, 색 모드, HDR, 회전, 미러, 배치)")
                            }
                            Button("이름 변경") {
                                renameText = profile.name
                                renaming = profile
                            }
                            Button("삭제", systemImage: "trash", role: .destructive) {
                                if protection.setting?.profileID == profile.id { protection.disable() }
                                perform { try profileStore.delete(profile.id) }
                            }
                                .labelStyle(.iconOnly)
                                .buttonStyle(.borderless)
                        }
                        ForEach(profile.displays, id: \.ref) { entry in
                            let online = entry.ref.resolve(in: store.displays) != nil
                            Label(entry.summary + (online ? "" : " (연결되지 않음)"), systemImage: online ? "display" : "display.trianglebadge.exclamationmark")
                                .font(.caption)
                                .foregroundStyle(online ? .secondary : .tertiary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            Section("구성 보호") {
                LabeledContent("상태", value: protection.statusText)
                if protection.isSuspended {
                    Button("보호 다시 켜기") { protection.resume() }
                }
                if let at = protection.lastRestoreAt {
                    LabeledContent("마지막 복원") {
                        Text(at, format: .dateTime.hour().minute().second())
                    }
                    ForEach(protection.lastResults) { result in
                        LabeledContent {
                            Text(result.detail).font(.callout)
                        } label: {
                            HStack(spacing: 6) {
                                Badge(text: result.outcome.title, color: Self.color(result.outcome))
                                Text("\(result.kind.title), \(result.displayName)")
                            }
                        }
                    }
                }
                Text("시스템이나 다른 프로그램이 구성을 바꾸면 보호 중인 프로파일의 해상도, 색 모드, HDR, 회전, 미러, 배치를 다시 적용. 앱 실행 중에만 동작. 이 앱에서 구성을 바꾸면 일시 중지, 60초 안에 3회 복원해도 다시 바뀌면 일시 중지")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !results.isEmpty {
                Section("적용 결과: \(resultTitle)") {
                    ForEach(results) { result in
                        LabeledContent {
                            Text(result.detail).font(.callout)
                        } label: {
                            HStack(spacing: 6) {
                                Badge(text: result.outcome.title, color: Self.color(result.outcome))
                                Text("\(result.kind.title), \(result.displayName)")
                            }
                        }
                    }
                }
            }
            if let message {
                Section { Label(message, systemImage: "exclamationmark.triangle").foregroundStyle(.red) }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("프로파일")
        .navigationSubtitle("저장 \(profiles.count)개")
        .onAppear { profiles = profileStore.load() }
        .alert("이름 변경", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("새 이름", text: $renameText)
            Button("변경") {
                if let target = renaming { perform { try profileStore.rename(target.id, to: renameText) } }
                renaming = nil
            }
            Button("취소", role: .cancel) { renaming = nil }
        }
    }

    private func save() {
        perform {
            try profileStore.add(ProfileApplier.capture(name: newName, displays: store.displays))
            newName = ""
        }
    }

    private func perform(_ action: () throws -> Void) {
        do {
            try action()
            message = nil
        } catch {
            message = RevertCoordinator.describe(error)
        }
        profiles = profileStore.load()
    }

    /// 적용은 자동 복귀 안전장치 경유. 복귀는 적용 전 구성을 다시 적용.
    private func apply(_ profile: DisplayProfile) {
        let previous = ProfileApplier.capture(name: "적용 전", displays: store.displays)
        let plan = ProfilePlanner.plan(profile, current: previous, displays: store.displays)
        resultTitle = profile.name
        if plan.steps.isEmpty {
            // 바뀌는 것이 없으면 확인 대기 없이 결과만 표시.
            results = ProfileApplier.apply(profile)
            return
        }
        let change = RevertCoordinator.Change(
            summary: "프로파일 적용: \(profile.name) (\(plan.steps.count)단계)",
            pending: nil,
            apply: { results = ProfileApplier.apply(profile) },
            commit: {},
            restore: { _ = ProfileApplier.apply(previous) }
        )
        changes.request(change, targetDisplayID: nil)
    }

    static func color(_ outcome: ProfileStepResult.Outcome) -> Color {
        switch outcome {
        case .applied: .green
        case .unchanged: .gray
        case .skipped: .orange
        case .failed: .red
        }
    }
}
