import AppKit
import SwiftUI
import TBDCore
import TBDPlatform
import UniformTypeIdentifiers

/// 개요 탭의 EDID 오버라이드 구역: 편집 항목 선택, 편집 전후 비교, 가상 EDID 적용과 해제. (PRD-EDO-001-003, PRD-EDO-004)
struct EDIDOverrideSection: View {
    @Environment(DisplayStore.self) private var store
    @Environment(ChangeController.self) private var changes
    let display: DisplaySummary
    let record: EDIDRecord

    @State private var selected: Set<EDIDPatch> = []
    @State private var frlLimit: Int?
    @State private var message: String?

    private var patches: [EDIDPatch] {
        EDIDPatch.simpleCases.filter(selected.contains) + (frlLimit.map { [.limitFRLRate($0)] } ?? [])
    }

    var body: some View {
        let available = store.status(.edidOverride).isAvailable
        let preview = patches.isEmpty ? nil : try? EDIDEditor.apply(patches, to: record.data)
        Section("EDID 오버라이드") {
            Text("시스템이 인식하는 EDID를 편집본으로 교체. 디스플레이의 저장 장치는 바뀌지 않으며 재시동하면 원본 EDID로 돌아옴. 화면이 나오지 않으면 제한 시간 뒤 원본으로 복귀")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(EDIDPatch.simpleCases, id: \.self) { patch in
                Toggle(patch.title, isOn: Binding(
                    get: { selected.contains(patch) },
                    set: { isOn in
                        if isOn { selected.insert(patch) } else { selected.remove(patch) }
                    }
                ))
            }
            if record.parsed.cta?.hdmiForum != nil {
                Picker("FRL 최대 속도 단계 제한", selection: $frlLimit) {
                    Text("제한 없음").tag(Int?.none)
                    ForEach(0...6, id: \.self) { Text("\($0) 이하").tag(Int?.some($0)) }
                }
            }
            if let preview {
                ForEach(preview.results, id: \.title) { result in
                    LabeledContent(result.title, value: result.changed ? result.changes.joined(separator: ", ") : "대상 선언 없음 (변경 없음)")
                }
                let before = record.parsed.sinkCapabilities.comparisonRows
                let after = EDIDParser.parse(preview.data).sinkCapabilities.comparisonRows
                ForEach(Array(zip(before, after)).filter { $0.0.value != $0.1.value }, id: \.0.label) { a, b in
                    LabeledContent(a.label, value: "\(a.value) → \(b.value)")
                }
            }
            HStack {
                Button("편집본 적용") {
                    guard let preview else { return }
                    apply(preview.data, detail: patches.map(\.title).joined(separator: ", "))
                }
                .disabled(!available || changes.isBusy || preview?.results.contains(where: \.changed) != true)
                Button("편집본 저장…") {
                    guard let preview else { return }
                    save(preview.data)
                }
                .disabled(preview == nil)
                Button("파일에서 적용…") { applyFromFile() }
                    .disabled(!available || changes.isBusy)
                Button("원본 EDID로 복원") { reset() }
                    .disabled(!available || changes.isBusy)
                Button("디스플레이 재감지") {
                    message = EDIDOverrideService.redetect() ? "재감지 요청 완료" : "재감지 요청 실패"
                }
                .disabled(!store.status(.redetect).isAvailable)
            }
            if !available {
                Text(store.status(.edidOverride).unavailableReason ?? "사용 불가").font(.caption).foregroundStyle(.secondary)
            }
            if let message {
                Text(message).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func apply(_ data: Data, detail: String) {
        do {
            let change = try DisplayChanges.edidOverrideChange(display: display, among: store.displays, edid: data, detail: detail)
            message = nil
            // 적용 뒤 디스플레이 ID가 바뀔 수 있어 대상 디스플레이의 분리 감시는 하지 않음.
            changes.request(change, targetDisplayID: nil)
        } catch {
            message = "적용 불가: \(RevertCoordinator.describe(error))"
        }
    }

    private func applyFromFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.data]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let data = try? Data(contentsOf: url) else {
            message = "파일을 읽을 수 없음"
            return
        }
        let issues = EDIDEditor.validate(data)
        guard issues.isEmpty else {
            message = "EDID 검증 실패: \(issues.joined(separator: ", "))"
            return
        }
        apply(data, detail: url.lastPathComponent)
    }

    private func save(_ data: Data) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(display.identity.name)-편집.edid.bin"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try data.write(to: url)
            message = "저장 완료: \(url.lastPathComponent)"
        } catch {
            message = "저장 실패: \(error.localizedDescription)"
        }
    }

    private func reset() {
        do {
            let entryID = EDIDOverrideService.service(for: display, among: store.displays)?.registryEntryID
            try EDIDOverrideService.reset(registryEntryID: entryID)
            message = "원본 EDID 복원 요청 완료"
        } catch {
            message = "복원 실패: \(RevertCoordinator.describe(error))"
        }
    }
}
