import SwiftUI
import TBDCore
import TBDPlatform

/// 색 조정 탭의 상태.
@MainActor
@Observable
final class ColorAdjustViewModel {
    var profiles: [ColorProfileInfo] = []
    var currentProfilePath = ""
    var adjustment = ColorAdjustment()
    var nightShift: NightShiftStatus?
    var trueTone: TrueToneStatus?
    var message: String?
    /// 디스플레이 프리셋 (사용 가능한 것만). (PRD-CLR-005)
    var presets: [DisplayPreset] = []

    func load(_ display: DisplaySummary) {
        presets = PresetService.presets(for: display.id).filter(\.isValid)
        profiles = ColorProfileService.available(for: display.id)
        let current = ColorProfileService.current(for: display.id)
        currentProfilePath = current?.path ?? ""
        // 목록에 없는 프로파일이 적용 중이면 목록에 추가.
        if let current, !current.path.isEmpty, !profiles.contains(where: { $0.path == current.path }) { profiles.insert(current, at: 0) }
        adjustment = GammaService.shared.adjustment(for: display.id)
        nightShift = NightShiftService.status()
        trueTone = TrueToneService.status()
    }

    func perform(_ display: DisplaySummary, _ action: () throws -> Void) {
        do {
            try action()
            message = nil
        } catch {
            message = RevertCoordinator.describe(error)
        }
        load(display)
    }

    func applyAdjustment(_ display: DisplaySummary) {
        do {
            try GammaService.shared.apply(adjustment, to: display.id)
            message = nil
        } catch {
            message = RevertCoordinator.describe(error)
        }
    }
}

/// 색 조정 탭: 디스플레이 프리셋, 색 프로파일, 소프트웨어 조정, Night Shift, True Tone. (PRD-CLR-001-005)
struct ColorAdjustTab: View {
    @Environment(ChangeController.self) private var changes
    @Environment(NightShiftSyncController.self) private var nightShiftSync
    let display: DisplaySummary
    @State private var model = ColorAdjustViewModel()

    var body: some View {
        Form {
            if !model.presets.isEmpty {
                Section("디스플레이 프리셋") {
                    ForEach(model.presets) { preset in
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(preset.name).fontWeight(preset.isActive ? .semibold : .regular)
                                    if preset.isActive { Badge(text: "현재", color: .accentColor) }
                                    if preset.isDefault { Badge(text: "기본", color: .gray) }
                                }
                                if !preset.detail.isEmpty {
                                    Text(preset.detail).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                                }
                            }
                            Spacer(minLength: 12)
                            Button("적용") {
                                guard let current = model.presets.first(where: \.isActive) else { return }
                                changes.request(DisplayChanges.presetChange(display: display, from: current, to: preset), targetDisplayID: display.id)
                            }
                            .controlSize(.small)
                            .disabled(preset.isActive || changes.isBusy)
                        }
                    }
                    Text("프리셋은 밝기 범위, 색 공간, 전달 함수를 묶은 기준 모드. 프리셋에 따라 밝기 조절과 HDR 사용 범위가 달라짐")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Section("색 프로파일") {
                Picker("프로파일", selection: Binding(get: { model.currentProfilePath }, set: { path in
                    guard let profile = model.profiles.first(where: { $0.path == path }) else { return }
                    model.perform(display) { try ColorProfileService.set(profile, for: display.id) }
                })) {
                    ForEach(model.profiles) { profile in
                        Text(profile.name + (profile.isFactoryDefault ? " (기본)" : "")).tag(profile.path)
                    }
                }
                Text("지정한 프로파일은 시스템에 저장되어 앱을 종료해도 유지")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section {
                slider("디밍", value: $model.adjustment.dimming, range: ColorAdjustment.dimmingRange, format: { "\(Int(($0 * 100).rounded()))%" })
                slider("감마", value: $model.adjustment.gamma, range: ColorAdjustment.gammaRange, format: { String(format: "%.2f", $0) })
                slider("대비", value: $model.adjustment.contrast, range: ColorAdjustment.contrastRange, format: { String(format: "%.2f", $0) })
                slider("색온도", value: $model.adjustment.temperature, range: ColorAdjustment.temperatureRange, format: { "\(Int($0.rounded())) K" })
                slider("빨강", value: $model.adjustment.redGain, range: ColorAdjustment.gainRange, format: { "\(Int(($0 * 100).rounded()))%" })
                slider("초록", value: $model.adjustment.greenGain, range: ColorAdjustment.gainRange, format: { "\(Int(($0 * 100).rounded()))%" })
                slider("파랑", value: $model.adjustment.blueGain, range: ColorAdjustment.gainRange, format: { "\(Int(($0 * 100).rounded()))%" })
                Button("초기화") {
                    model.adjustment = .identity
                    model.applyAdjustment(display)
                }
                .disabled(model.adjustment.isIdentity)
            } header: {
                Text("소프트웨어 조정")
            } footer: {
                Text("전달 테이블로 화면 출력값을 바꾸는 조정. 앱 실행 중에만 유지되고 종료하면 원래대로 복귀")
                    .font(.caption)
            }
            Section("Night Shift") {
                if let status = model.nightShift, status.isSupported {
                    Toggle("Night Shift", isOn: Binding(get: { status.isEnabled }, set: { value in model.perform(display) { try NightShiftService.setEnabled(value) } }))
                    if let strength = status.strength {
                        HStack(spacing: 10) {
                            Text("강도").frame(width: 60, alignment: .leading)
                            Slider(value: Binding(get: { strength }, set: { value in model.perform(display) { try NightShiftService.setStrength(value) } }), in: 0...1)
                            Text("\(Int((strength * 100).rounded()))%").monospacedDigit().frame(width: 60, alignment: .trailing)
                        }
                    }
                    LabeledContent("일정", value: status.scheduleName)
                    Text("Night Shift는 시스템 전체 설정이며 지원 디스플레이 전부에 적용").font(.caption).foregroundStyle(.secondary)
                    Toggle("이 디스플레이에 Night Shift 연동 색온도 적용", isOn: Binding(get: { nightShiftSync.isEnabled(display.id) }, set: { value in
                        nightShiftSync.setEnabled(value, for: display.id)
                        model.load(display)
                    }))
                    Text("TV처럼 시스템 Night Shift가 적용되지 않는 디스플레이용. Night Shift가 켜져 있는 동안 강도에 맞춘 색온도를 전달 테이블로 적용. 앱 실행 중에만 동작")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("이 기기에서 Night Shift를 사용할 수 없음").foregroundStyle(.secondary)
                }
            }
            Section("True Tone") {
                if let status = model.trueTone, status.isSupported, status.isAvailable {
                    Toggle("True Tone", isOn: Binding(get: { status.isEnabled }, set: { value in model.perform(display) { try TrueToneService.setEnabled(value) } }))
                    Text("True Tone은 시스템 전체 설정이며 주변광 센서를 쓰는 디스플레이에 적용").font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("True Tone: \(model.trueTone?.stateLabel ?? "확인 불가")").foregroundStyle(.secondary)
                }
            }
            if let message = model.message {
                Section { Label(message, systemImage: "exclamationmark.triangle").foregroundStyle(.red) }
            }
        }
        .formStyle(.grouped)
        .task(id: display.id) { model.load(display) }
    }

    private func slider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, format: @escaping (Double) -> String) -> some View {
        HStack(spacing: 10) {
            Text(title).frame(width: 60, alignment: .leading)
            Slider(value: Binding(get: { value.wrappedValue }, set: { new in
                value.wrappedValue = new
                model.applyAdjustment(display)
            }), in: range)
            Text(format(value.wrappedValue)).monospacedDigit().frame(width: 60, alignment: .trailing)
        }
    }
}
