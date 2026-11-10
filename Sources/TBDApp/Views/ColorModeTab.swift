import SwiftUI
import TBDCore
import TBDPlatform

/// 색 모드 탭: 현재 신호 형식, 색 모드 선택, DSC 정보와 전환, 타이밍 목록과 직접 선택. (PRD-COL-001-007)
struct ColorModeTab: View {
    @Environment(DisplayStore.self) private var store
    @Environment(ChangeController.self) private var changes
    let display: DisplaySummary

    enum RangeFilter: String, CaseIterable {
        case all, sdr, hdr
        var title: String {
            switch self {
            case .all: "전체"
            case .sdr: "SDR"
            case .hdr: "HDR"
            }
        }
    }

    enum DSCFilter: String, CaseIterable {
        case all, with, without
        var title: String {
            switch self {
            case .all: "전체"
            case .with: "DSC 사용"
            case .without: "DSC 미사용"
            }
        }
    }

    @State private var rangeFilter: RangeFilter = .all
    @State private var dscFilter: DSCFilter = .all

    var body: some View {
        if let info = store.signals[display.id] {
            Form {
                if let hdr = store.hdrStatuses[display.id] { hdrSection(hdr) }
                currentSignal(info)
                if let dsc = store.dscAssessments[display.id] { dscSection(dsc, info: info) }
                colorModes(info)
                timings(info)
            }
            .formStyle(.grouped)
        } else {
            ContentUnavailableView("신호 정보를 읽을 수 없음", systemImage: "waveform.slash", description: Text("이 디스플레이의 프레임버퍼 노드를 찾지 못함"))
        }
    }

    @ViewBuilder
    private func currentSignal(_ info: SignalInfo) -> some View {
        Section("현재 송출 신호") {
            if let link = info.linkData {
                LabeledContent("픽셀 인코딩", value: link.pixelEncoding.name)
                LabeledContent("비트 심도", value: "\(link.bitsPerComponent) bpc (픽셀당 \(Self.trim(link.bitsPerPixel))비트)")
                LabeledContent("레인지", value: link.dynamicRange.name)
                LabeledContent("EOTF", value: link.eotf.name)
                LabeledContent("색 공간", value: Colorimetry.name(link.colorimetry))
                LabeledContent("타이밍", value: "\(link.hActive) x \(link.vActive), \(DisplaySummary.formatHz(link.refreshRate)) Hz (총 \(link.hTotal) x \(link.vTotal))")
                LabeledContent("픽셀 클록", value: String(format: "%.2f MHz", link.pixelClockHz / 1e6))
                LabeledContent("출처", value: "링크 데이터 (실제 송출값)")
            } else if let color = info.currentColor {
                LabeledContent("픽셀 인코딩", value: color.pixelEncoding.name)
                LabeledContent("비트 심도", value: "\(color.bitsPerComponent) bpc")
                LabeledContent("레인지", value: color.dynamicRange.name)
                LabeledContent("EOTF", value: color.eotf.name)
                LabeledContent("색 공간", value: Colorimetry.name(color.colorimetry))
                if let timing = info.currentTiming {
                    LabeledContent("타이밍", value: "\(timing.label) (총 \(timing.hTotal) x \(timing.vTotal))")
                    LabeledContent("픽셀 클록", value: String(format: "%.2f MHz", timing.pixelClockHz / 1e6))
                }
                LabeledContent("출처", value: display.identity.isBuiltin ? "프레임버퍼 설정값 (내장 패널)" : "프레임버퍼 설정값 (링크 데이터 읽기 실패)")
            } else {
                Text("현재 색 모드를 확인할 수 없음").foregroundStyle(.secondary)
            }
            LabeledContent("전송 방식", value: info.transport ?? "미확인")
        }
    }

    /// HDR 상태, 전환, 정보. (PRD-HDR-001-003)
    private func hdrSection(_ hdr: HDRStatus) -> some View {
        Section("HDR") {
            LabeledContent("상태") {
                HStack(spacing: 10) {
                    Text(hdr.stateLabel)
                    if hdr.isSupported {
                        Button(hdr.isEnabled ? "HDR 끄기" : "HDR 켜기") {
                            changes.request(DisplayChanges.hdrChange(display: display, enable: !hdr.isEnabled), targetDisplayID: display.id)
                        }
                        .disabled(changes.isBusy)
                    }
                }
            }
            LabeledContent("지원 EOTF", value: hdr.supportedEOTFs.isEmpty ? "EDID 미보고" : hdr.supportedEOTFs.joined(separator: ", "))
            LabeledContent("최대 휘도", value: hdr.maxLuminance.map { String(format: "%.0f cd/m²", $0) } ?? "EDID 미보고")
            LabeledContent("EDR 헤드룸", value: "현재 \(hdr.currentEDRHeadroom.map { String(format: "%.2f", $0) } ?? "미확인")배, 최대 \(hdr.maxEDRHeadroom.map { String(format: "%.2f", $0) } ?? "미확인")배")
            if hdr.isSupported {
                Text("HDR을 켜거나 끄면 시스템이 색 모드를 다시 선택. 높은 주사율에서 대역폭이 부족하면 HDR 상태의 형식은 YCbCr 4:2:2로 제한될 수 있음")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// DSC 정보와 켜기, 끄기. (PRD-COL-004, PRD-COL-006)
    private func dscSection(_ dsc: DSCAssessment, info: SignalInfo) -> some View {
        let enablePlan = DSCControl.plan(signal: info, enable: true)
        let disablePlan = DSCControl.plan(signal: info, enable: false)
        return Section("DSC 압축") {
            LabeledContent("현재 상태") {
                HStack(spacing: 10) {
                    Text(dsc.summary)
                    Button("DSC 켜기") { applyDSC(enablePlan, info: info) }
                        .disabled(changes.isBusy || !Self.isPossible(enablePlan))
                        .help(Self.planHelp(enablePlan))
                    Button("DSC 끄기") { applyDSC(disablePlan, info: info) }
                        .disabled(changes.isBusy || !Self.isPossible(disablePlan))
                        .help(Self.planHelp(disablePlan))
                }
            }
            LabeledContent("소스 (Mac)", value: Self.support(dsc.sourceSupportsDSC))
            LabeledContent("싱크 (디스플레이)", value: Self.support(dsc.sinkSupportsDSC))
            LabeledContent("현재 타이밍의 색 모드", value: "DSC 필요 \(dsc.dscRequiredModeCount)개, 불필요 \(dsc.dscFreeModeCount)개")
            if dsc.isActive != true, case .failure(let error) = enablePlan, case .noCandidate = error {
                Text("켜기 불가: \(error.localizedDescription)").font(.caption).foregroundStyle(.secondary)
            }
            if dsc.isActive == true, case .failure(let error) = disablePlan, case .noCandidate = error {
                Text("끄기 불가: \(error.localizedDescription)").font(.caption).foregroundStyle(.secondary)
            }
            Text("DSC 전환은 현재 타이밍을 유지하고 DSC 사용 색 모드와 미사용 색 모드 사이를 바꾸는 방식. 시스템이 제공하지 않는 조합의 강제는 불가")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private static func isPossible(_ plan: Result<ColorElement, DSCControl.Unavailable>) -> Bool {
        if case .success = plan { return true }
        return false
    }

    private static func planHelp(_ plan: Result<ColorElement, DSCControl.Unavailable>) -> String {
        switch plan {
        case .success(let element): "색 모드 \(element.label)로 전환"
        case .failure(let error): error.localizedDescription
        }
    }

    private func applyDSC(_ plan: Result<ColorElement, DSCControl.Unavailable>, info: SignalInfo) {
        guard case .success(let element) = plan, let timingID = info.currentTimingID, let current = info.currentColor else { return }
        changes.request(DisplayChanges.colorChange(display: display, timingID: timingID, from: current, to: element), targetDisplayID: display.id)
    }

    @ViewBuilder
    private func colorModes(_ info: SignalInfo) -> some View {
        let timing = info.currentTiming
        let elements = info.selectableColorModes.filter { element in
            switch rangeFilter {
            case .all: break
            case .sdr: if element.eotf.isHDR { return false }
            case .hdr: if !element.eotf.isHDR { return false }
            }
            let needsDSC = timing?.requiresDSC(element.id) ?? false
            switch dscFilter {
            case .all: return true
            case .with: return needsDSC
            case .without: return !needsDSC
            }
        }.sorted(by: Self.order)

        Section {
            HStack(spacing: 10) {
                Text("밝기 범위").foregroundStyle(.secondary)
                Picker("밝기 범위", selection: $rangeFilter) {
                    ForEach(RangeFilter.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                Spacer(minLength: 8)
                Text("DSC").foregroundStyle(.secondary)
                Picker("DSC", selection: $dscFilter) {
                    ForEach(DSCFilter.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
            if elements.isEmpty {
                Text("조건에 맞는 색 모드 없음").foregroundStyle(.secondary)
            }
            ForEach(elements) { element in
                ColorModeRow(
                    element: element,
                    isCurrent: element.id == info.currentColorID,
                    needsDSC: timing?.requiresDSC(element.id) ?? false,
                    isUnsafe: timing?.unsafeColorElementIDs.contains(element.id) ?? false,
                    isMismatched: store.hdrStatuses[display.id]?.isMismatched(with: element.eotf) ?? false,
                    isDisabled: changes.isBusy || !store.status(.signalWrite).isAvailable
                ) {
                    apply(element, info: info)
                }
            }
        } header: {
            Text("색 모드 (\(timing?.label ?? "현재 타이밍") 기준 \(info.selectableColorModes.count)개)")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text("목록은 현재 해상도와 주사율에서 연결이 제공하는 형식. 주사율을 낮추면 선택 가능한 형식이 늘어날 수 있음")
                Text("해상도나 주사율 변경, 재연결 뒤에는 시스템이 색 모드를 선호값으로 되돌릴 수 있음")
                Text("HDR 불일치 표시가 있는 형식은 현재 HDR 상태와 전달 함수가 달라 화면 이상 가능. HDR 전환을 먼저 권장")
                if let reason = store.status(.signalWrite).unavailableReason { Text(reason) }
            }
            .font(.caption)
        }
    }

    private func timings(_ info: SignalInfo) -> some View {
        Section {
            DisclosureGroup("싱크 타이밍 \(info.timings.count)개") {
                let sorted = info.timings.sorted { ($0.hActive * $0.vActive, $0.refreshRate, $0.id) > ($1.hActive * $1.vActive, $1.refreshRate, $1.id) }
                ForEach(sorted) { t in
                    LabeledContent {
                        HStack(spacing: 8) {
                            Text("총 \(t.hTotal) x \(t.vTotal), \(String(format: "%.2f", t.pixelClockHz / 1e6)) MHz, 색 모드 \(t.colorModes.filter { !$0.isVirtual }.count)개" + (t.dscRequiredColorElementIDs.isEmpty ? "" : ", DSC 필요 \(t.dscRequiredColorElementIDs.count)개"))
                                .font(.caption.monospacedDigit())
                            if !display.identity.isBuiltin, !t.isVirtual {
                                Button("적용") { applyTiming(t, info: info) }
                                    .controlSize(.small)
                                    .disabled(changes.isBusy || t.id == info.currentTimingID)
                                    .help("이 타이밍을 직접 선택. 시스템 모드 목록에 없는 주사율의 타이밍도 선택 가능")
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(t.label).monospacedDigit()
                            if t.id == info.currentTimingID { Badge(text: "현재", color: .accentColor) }
                            if t.isPreferred { Badge(text: "선호", color: .green) }
                        }
                    }
                }
            }
        }
    }

    /// 연결 수준 타이밍 직접 선택. (PRD-COL-007)
    private func applyTiming(_ target: TimingElement, info: SignalInfo) {
        guard case .success(let color) = TimingSelection.plan(signal: info, target: target), let current = info.currentTiming, let currentColor = info.currentColor else { return }
        changes.request(DisplayChanges.timingChange(display: display, from: current, previousColor: currentColor, to: target, color: color), targetDisplayID: display.id)
    }

    private func apply(_ element: ColorElement, info: SignalInfo) {
        guard let timingID = info.currentTimingID, let current = info.currentColor, element.id != current.id else { return }
        changes.request(DisplayChanges.colorChange(display: display, timingID: timingID, from: current, to: element), targetDisplayID: display.id)
    }

    static func order(_ a: ColorElement, _ b: ColorElement) -> Bool {
        func key(_ e: ColorElement) -> (Int, Int, Int, Int, Int) {
            (e.eotf.rawValue, e.pixelEncoding.isRGB ? 0 : e.pixelEncoding.rawValue == 3 ? 1 : e.pixelEncoding.rawValue == 2 ? 2 : 3, -e.bitsPerComponent, e.dynamicRange.rawValue, e.colorimetry)
        }
        return key(a) < key(b)
    }

    static func support(_ value: Bool?) -> String {
        value.map { $0 ? "지원" : "미지원" } ?? "미확인"
    }

    static func trim(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }
}

private struct ColorModeRow: View {
    let element: ColorElement
    let isCurrent: Bool
    let needsDSC: Bool
    let isUnsafe: Bool
    let isMismatched: Bool
    let isDisabled: Bool
    let select: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("\(element.pixelEncoding.name), \(element.bitsPerComponent) bpc")
                        .fontWeight(isCurrent ? .semibold : .regular)
                    Badge(text: element.dynamicRange.name, color: element.dynamicRange == .full ? .blue : .gray)
                    Badge(text: element.eotf.name, color: element.eotf.isHDR ? .purple : .gray)
                    if needsDSC { Badge(text: "DSC", color: .orange) }
                    if isUnsafe { Badge(text: "안전하지 않음", color: .red) }
                    if isMismatched { Badge(text: "HDR 불일치", color: .red) }
                    if isCurrent { Badge(text: "현재", color: .accentColor) }
                }
                Text("색 공간 \(Colorimetry.name(element.colorimetry)), 픽셀당 \(ColorModeTab.trim(element.bitsPerPixel))비트, 색 모드 번호 \(element.id)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("적용", action: select)
                .disabled(isDisabled || isCurrent)
        }
    }
}
