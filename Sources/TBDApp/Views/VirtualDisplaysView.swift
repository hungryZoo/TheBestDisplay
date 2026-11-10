import SwiftUI
import TBDCore
import TBDPlatform

/// 가상 디스플레이 관리 화면: 구성 추가, 켜기와 끄기, 삭제, 실행 시 복원. (PRD-VRT-001, PRD-VRT-003)
struct VirtualDisplaysView: View {
    @Environment(DisplayStore.self) private var store
    @State private var name = "가상 디스플레이"
    @State private var width = "1920"
    @State private var height = "1080"
    @State private var hiDPI = true
    @State private var restoreAtLaunch = false
    @State private var hdr = false
    @State private var message: String?

    var body: some View {
        Form {
            Section {
                if store.virtualConfigs.isEmpty {
                    Text("저장된 가상 디스플레이 없음").foregroundStyle(.secondary)
                }
                ForEach(store.virtualConfigs) { config in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(config.name)
                            Text(config.label + (config.restoreAtLaunch ? ", 실행 시 복원" : "")).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let id = store.activeVirtualIDs[config.id] {
                            Badge(text: "켜짐 id:\(id)", color: .green)
                        }
                        let isOn = store.activeVirtualIDs[config.id] != nil
                        Button(isOn ? "끄기" : "켜기") {
                            Task { message = await store.setVirtual(config, active: !isOn) }
                        }
                        .controlSize(.small)
                        Button("삭제", systemImage: "trash", role: .destructive) { message = store.removeVirtual(config.id) }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.borderless)
                    }
                }
            } header: {
                Text("가상 디스플레이")
            } footer: {
                Text("가상 디스플레이는 이 앱이 실행 중인 동안만 존재. 앱을 종료하면 사라지고 창은 실제 디스플레이로 이동")
                    .font(.caption)
            }
            Section("새 가상 디스플레이") {
                TextField("이름", text: $name)
                HStack {
                    TextField("폭", text: $width).frame(width: 110)
                    Text("x")
                    TextField("높이", text: $height).frame(width: 110)
                    Spacer()
                    Menu("자주 쓰는 해상도") {
                        ForEach([(1280, 720), (1920, 1080), (2560, 1440), (3008, 1692), (3840, 2160)], id: \.0) { w, h in
                            Button("\(w) x \(h)") {
                                width = String(w)
                                height = String(h)
                            }
                        }
                    }
                    .fixedSize()
                }
                Toggle("HiDPI (백킹 해상도 2배)", isOn: $hiDPI)
                Toggle("HDR 가상 디스플레이", isOn: $hdr)
                Toggle("앱 실행 시 자동으로 켜기", isOn: $restoreAtLaunch)
                Button("추가하고 켜기") { add() }
            }
            if let message {
                Section { Label(message, systemImage: "exclamationmark.triangle").foregroundStyle(.red) }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("가상 디스플레이")
        .navigationSubtitle("저장 \(store.virtualConfigs.count)개, 켜짐 \(store.activeVirtualIDs.count)개")
    }

    private func add() {
        guard let w = Int(width), let h = Int(height) else {
            message = "폭과 높이는 정수"
            return
        }
        let config = VirtualDisplayConfig(name: name.trimmingCharacters(in: .whitespaces), width: w, height: h, hiDPI: hiDPI, restoreAtLaunch: restoreAtLaunch, hdr: hdr)
        let issues = config.validationIssues()
        guard issues.isEmpty else {
            message = issues.joined(separator: ", ")
            return
        }
        Task { message = await store.addVirtual(config) }
    }
}

/// 해상도 탭의 HiDPI 스케일링 영역. (PRD-VRT-002)
struct HiDPIScalingSection: View {
    @Environment(DisplayStore.self) private var store
    @Environment(ChangeController.self) private var changes
    let display: DisplaySummary
    let nativeWidth: Int
    let nativeHeight: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("HiDPI 스케일링").font(.callout.weight(.medium))
                if let active = store.scalingConfigs[display.id] {
                    Badge(text: "적용 중: \(active.width) x \(active.height)", color: .green)
                    Button("해제") { changes.request(store.scalingChange(display: display, logical: nil), targetDisplayID: nil) }
                        .controlSize(.small)
                        .disabled(changes.isBusy)
                }
                Spacer()
            }
            if store.scalingConfigs[display.id] == nil {
                HStack(spacing: 6) {
                    ForEach(HiDPIScaling.presets(nativeWidth: nativeWidth, nativeHeight: nativeHeight), id: \.width) { preset in
                        Button("\(preset.width) x \(preset.height)") {
                            changes.request(store.scalingChange(display: display, logical: (preset.width, preset.height)), targetDisplayID: nil)
                        }
                        .controlSize(.small)
                        .disabled(changes.isBusy)
                        .help(HiDPIScaling.sharpnessNote(logicalWidth: preset.width, nativeWidth: nativeWidth))
                    }
                }
            }
            Text("모드 목록에 없는 HiDPI 해상도를 쓰는 방법: HiDPI 가상 디스플레이를 만들고 이 디스플레이가 그 화면을 미러. 앱 실행 중에만 유지")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
    }
}
