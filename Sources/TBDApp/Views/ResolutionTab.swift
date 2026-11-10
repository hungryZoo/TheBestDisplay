import SwiftUI
import TBDCore
import TBDPlatform

/// 해상도 탭: 전체 모드 목록, 필터, 모드 전환, 즐겨찾기, 슬라이더, 렌더링 한계, 사용자 정의 스케일 해상도. (PRD-MOD-001-010)
struct ResolutionTab: View {
    @Environment(DisplayStore.self) private var store
    @Environment(ChangeController.self) private var changes
    let display: DisplaySummary

    @State private var filter = ModeFilter()
    @State private var favorites: [ModeDescriptor] = []
    @State private var sliderIndex: Double = 0
    @State private var showsHiDPIHelp = false

    private let favoriteStore = ModeFavoritesStore.standard

    var body: some View {
        let modes = store.modes[display.id] ?? []
        let current = store.currentModes[display.id]
        let groups = ModeCatalog.groups(modes, filter: filter)

        VStack(spacing: 0) {
            header(modes: modes, current: current, shown: groups.reduce(0) { $0 + $1.modes.count })
            Divider()
            quickAccess(modes: modes, current: current)
            Divider()
            if !store.isVirtual(display.id), let native = ModeCatalog.nativeModes(modes, nativeWidth: display.pixelWidth, nativeHeight: display.pixelHeight).first {
                HiDPIScalingSection(display: display, nativeWidth: native.pixelWidth, nativeHeight: native.pixelHeight)
                Divider()
            }
            if !store.isVirtual(display.id) {
                ScaledResolutionSection(display: display)
                Divider()
            }
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
                Button("해상도 용어", systemImage: "questionmark.circle") { showsHiDPIHelp = true }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .help("논리 해상도, 백킹 해상도, 패널 해상도의 뜻")
                    .popover(isPresented: $showsHiDPIHelp) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("해상도 용어").font(.headline)
                            Text("논리 해상도: 창과 글자의 크기를 정하는 좌표 크기 (포인트). 값이 작을수록 화면 요소가 크게 보임.")
                            Text("백킹 해상도: 시스템이 실제로 그리는 픽셀 크기. HiDPI 모드는 논리 해상도의 2배로 그림.")
                            Text("패널 해상도: 디스플레이로 보내는 신호의 픽셀 크기. 백킹 해상도와 다르면 시스템이 크기를 맞춰 보냄.")
                            Text("HiDPI: 논리 1포인트를 2 x 2 픽셀로 그리는 방식. 백킹 해상도가 패널 해상도와 같을 때 가장 선명하고, 더 크면 축소되어 약간 부드럽게 보임.")
                            Text("예: 4K 패널(3840 x 2160)에서 1920 x 1080 HiDPI는 백킹 3840 x 2160으로 1:1 표시, 2560 x 1440 HiDPI는 백킹 5120 x 2880을 3840 x 2160으로 축소해 표시.")
                        }
                        .font(.callout)
                        .frame(width: 420)
                        .padding(16)
                    }
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

    /// 즐겨찾기 모드, 해상도 슬라이더, 렌더링 한계. (PRD-MOD-009, PRD-MOD-010)
    private func quickAccess(modes: [DisplayMode], current: DisplayMode?) -> some View {
        let steps = current.map { ModeCatalog.sliderSteps(modes, current: $0) } ?? []
        let currentStep = steps.firstIndex { $0.width == current?.width && $0.height == current?.height } ?? 0
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("즐겨찾기").font(.callout.weight(.medium))
                ForEach(favorites, id: \.self) { favorite in
                    let match = favorite.find(in: modes)
                    let isCurrent = match != nil && match?.modeNumber == current?.modeNumber
                    Button("\(favorite.width) x \(favorite.height)\(favorite.isHiDPI ? " HiDPI" : ""), \(DisplaySummary.formatHz(favorite.refreshRate)) Hz") {
                        if let match { apply(match, current: current) }
                    }
                    .controlSize(.small)
                    .tint(isCurrent ? .accentColor : nil)
                    .disabled(match == nil || isCurrent || changes.isBusy || display.mirrorsDisplayID != nil)
                    .help(match == nil ? "현재 모드 목록에 없음" : "이 모드로 전환")
                }
                if favorites.isEmpty { Text("없음").font(.callout).foregroundStyle(.secondary) }
                Spacer()
                if let current {
                    let isFavorite = favorites.contains(current.descriptor)
                    Button(isFavorite ? "현재 모드 즐겨찾기 해제" : "현재 모드 즐겨찾기 추가") {
                        if isFavorite {
                            _ = try? favoriteStore.remove(current.descriptor, for: display.identity)
                        } else {
                            _ = try? favoriteStore.add(current.descriptor, for: display.identity)
                        }
                        favorites = favoriteStore.favorites(for: display.identity)
                    }
                    .controlSize(.small)
                }
            }
            if steps.count > 1 {
                HStack(spacing: 8) {
                    Text("해상도").font(.callout.weight(.medium))
                    Image(systemName: "textformat.size.larger")
                    Slider(value: $sliderIndex, in: 0...Double(steps.count - 1), step: 1) { editing in
                        // 손을 뗄 때 한 번만 전환.
                        guard !editing else { return }
                        let target = steps[min(max(Int(sliderIndex.rounded()), 0), steps.count - 1)]
                        if target.modeNumber != current?.modeNumber { apply(target, current: current) }
                    }
                    .disabled(changes.isBusy || display.mirrorsDisplayID != nil)
                    Image(systemName: "textformat.size.smaller")
                    let selected = steps[min(max(Int(sliderIndex.rounded()), 0), steps.count - 1)]
                    Text(selected.label).font(.callout.monospacedDigit()).frame(width: 190, alignment: .trailing)
                }
            }
            if let current, let pair = ModeCatalog.notchPair(modes, current: current) {
                let usesNotch = pair.full.modeNumber == current.modeNumber
                HStack(spacing: 8) {
                    Text("notch").font(.callout.weight(.medium))
                    Text(usesNotch ? "화면 전체 사용 (notch 영역 포함)" : "notch 아래 영역만 사용").font(.callout)
                    Button(usesNotch ? "notch 아래 영역만 사용" : "화면 전체 사용") {
                        apply(usesNotch ? pair.belowNotch : pair.full, current: current)
                    }
                    .controlSize(.small)
                    .disabled(changes.isBusy)
                }
            }
            if let limits = ModeCatalog.renderingLimits(modes) {
                Text("렌더링 한계 (모드 목록 기준): \(limits.summary)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .task(id: "\(display.id)-\(current?.modeNumber ?? -1)") {
            favorites = favoriteStore.favorites(for: display.identity)
            sliderIndex = Double(currentStep)
        }
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
