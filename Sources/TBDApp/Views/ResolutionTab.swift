import SwiftUI
import TBDCore
import TBDPlatform

/// 해상도 탭: 전체 모드 목록, 필터, 모드 전환. (PRD-MOD-001-006)
struct ResolutionTab: View {
    @Environment(DisplayStore.self) private var store
    @Environment(ChangeController.self) private var changes
    let display: DisplaySummary

    @State private var filter = ModeFilter()

    var body: some View {
        let modes = store.modes[display.id] ?? []
        let current = store.currentModes[display.id]
        let groups = ModeCatalog.groups(modes, filter: filter)

        VStack(spacing: 0) {
            header(modes: modes, current: current, shown: groups.reduce(0) { $0 + $1.modes.count })
            Divider()
            if groups.isEmpty {
                ContentUnavailableView("조건에 맞는 모드 없음", systemImage: "line.3.horizontal.decrease.circle")
            } else {
                List(groups) { group in
                    ModeGroupRow(group: group, current: current, isBusy: changes.isBusy, isMirrored: display.mirrorsDisplayID != nil) { mode in
                        apply(mode, current: current)
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    private func header(modes: [DisplayMode], current: DisplayMode?, shown: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("현재 모드").font(.caption).foregroundStyle(.secondary)
                    Text(current?.label ?? "확인 불가").font(.headline)
                }
                Spacer()
                Text("표시 \(shown)개, 전체 \(modes.count)개")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 14) {
                Picker("배율", selection: $filter.hiDPI) {
                    ForEach(ModeFilter.HiDPI.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .fixedSize()
                Picker("주사율", selection: $filter.refreshRate) {
                    Text("전체").tag(Int?.none)
                    ForEach(ModeCatalog.refreshRates(modes), id: \.self) { Text("\($0) Hz").tag(Int?.some($0)) }
                }
                .fixedSize()
                Picker("종횡비", selection: $filter.aspectRatio) {
                    Text("전체").tag(String?.none)
                    ForEach(ModeCatalog.aspectRatios(modes), id: \.self) { Text($0).tag(String?.some($0)) }
                }
                .fixedSize()
                Toggle("시스템 설정 목록 밖만", isOn: $filter.onlyOutsideSystemDefaultList)
                Spacer()
            }
            if display.mirrorsDisplayID != nil {
                Label("미러 대상 디스플레이는 모드 전환 불가. 미러 원본에서 전환", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
    }

    private func apply(_ mode: DisplayMode, current: DisplayMode?) {
        guard let current, mode.modeNumber != current.modeNumber else { return }
        changes.request(DisplayChanges.modeChange(display: display, from: current, to: mode), targetDisplayID: display.id)
    }
}

private struct ModeGroupRow: View {
    let group: ModeGroup
    let current: DisplayMode?
    let isBusy: Bool
    let isMirrored: Bool
    let select: (DisplayMode) -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(group.label)
                        .font(.body.monospacedDigit())
                        .fontWeight(containsCurrent ? .semibold : .regular)
                    if containsCurrent { Badge(text: "현재", color: .accentColor) }
                    if group.modes.contains(where: \.isNative) { Badge(text: "원본", color: .green) }
                    if group.modes.contains(where: \.isDefault) { Badge(text: "기본", color: .gray) }
                    if group.isOutsideSystemDefaultList { Badge(text: "시스템 설정 목록 밖", color: .orange) }
                }
                Text("픽셀 \(group.pixelWidth) x \(group.pixelHeight), \(group.aspectRatio)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)
            HStack(spacing: 4) {
                ForEach(group.modes) { mode in
                    let isCurrent = mode.modeNumber == current?.modeNumber
                    Button {
                        select(mode)
                    } label: {
                        Text(DisplaySummary.formatHz(mode.refreshRate) + (mode.isVRR ? "v" : ""))
                            .monospacedDigit()
                            .frame(minWidth: 30)
                    }
                    .buttonStyle(.bordered)
                    .tint(isCurrent ? .accentColor : nil)
                    .controlSize(.small)
                    .disabled(isBusy || isMirrored || isCurrent)
                    .help("\(mode.label)로 전환, 모드 번호 \(mode.modeNumber)" + (mode.isVRR ? ", 가변 주사율" : "") + (mode.isInSystemDefaultList ? "" : ", 시스템 설정 목록 밖"))
                }
            }
        }
        .padding(.vertical, 3)
    }

    private var containsCurrent: Bool {
        group.modes.contains { $0.modeNumber == current?.modeNumber }
    }
}

struct Badge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .foregroundStyle(color)
            .background(color.opacity(0.15), in: Capsule())
    }
}
