import SwiftUI
import TBDCore
import TBDPlatform

/// 밝기 탭의 상태. 디스플레이마다 탭이 열릴 때 조회.
@MainActor
@Observable
final class BrightnessViewModel {
    var method: BrightnessMethod = .software
    /// 하드웨어 밝기 (0-1). 소프트웨어 방식이면 디밍 값.
    var brightness: Double = 1
    var autoAvailable = false
    var autoEnabled = false
    var probe: DDCProbe?
    var isProbing = false
    var message: String?
    /// DDC 연속 값 (코드별 현재값과 최댓값).
    var ddcValues: [UInt8: (current: Double, maximum: Double)] = [:]
    /// capabilities 기반 제어 구성. capabilities를 읽지 못하면 빈 배열 (고정 구성 사용). (PRD-DDC-005)
    var ddcControls: [DDCControl] = []
    var ddcOtherCodes: [UInt8] = []
    /// 화면 구성 미리 보기: 실행 인자 `-ddcCapabilitiesPreview <문자열>`로 준 capabilities로 DDC 구역을 구성. 모니터에 쓰지 않음.
    var ddcPreview = false
    var rawCode = "0x10"
    var rawValue = ""
    var rawResult: String?
    /// XDR 밝기 업스케일. (PRD-BRT-005)
    var xdrSupported = false
    var xdrMaximum = 1.0
    var xdrBoost = 1.0
    var xdrMessage: String?
    /// 오버레이 디밍 강도 (0-0.9). (PRD-BRT-007)
    var overlayStrength = 0.0
    /// 내장 패널의 현재 휘도. (PRD-BRT-008)
    var luminance: BacklightLuminance?
    /// 최대 휘도 기준값: 휘도를 직접 읽을 수 없는 디스플레이의 추정 휘도와 휘도 기준 동기화에 사용. (PRD-BRT-010)
    var reference: LuminanceReference?
    var referenceText = ""
    /// 결합 밝기: 하드웨어 밝기와 전달 테이블 디밍을 한 값으로 조절. (PRD-BRT-009)
    var combinedEnabled = false
    var combined = 1.0

    @ObservationIgnored private var pendingWrite: Task<Void, Never>?
    /// 조회 순번. DDC 탐지를 기다리는 사이 다른 디스플레이로 넘어가면 늦게 끝난 탐지 결과를 버림. (T52 실측)
    @ObservationIgnored private var loadGeneration = 0

    func load(_ display: DisplaySummary) async {
        loadGeneration += 1
        let generation = loadGeneration
        isProbing = false
        loadReference(display)
        ddcControls = []
        ddcOtherCodes = []
        ddcPreview = false
        luminance = BrightnessService.backlightLuminance(for: display)
        message = nil
        xdrSupported = XDRBoostService.isSupported(display.id)
        xdrMaximum = XDRBoostService.maximumBoost(display.id)
        xdrBoost = XDRBoostService.shared.boost(for: display.id)
        overlayStrength = OverlayDimService.shared.strength(for: display.id)
        xdrMessage = nil
        rawResult = nil
        autoAvailable = BrightnessService.hasAutoBrightness(display.id)
        autoEnabled = BrightnessService.autoBrightnessEnabled(display.id) ?? false
        if BrightnessService.supportsNative(display) {
            method = .native
            brightness = BrightnessService.nativeBrightness(display.id) ?? 1
            probe = DDCProbe(status: .notApplicable)
            loadCombined(display)
            return
        }
        // DDC 탐지는 응답 대기가 있으므로 메인 스레드 밖에서 수행.
        isProbing = true
        let result = await Task.detached { DDCService.probe(for: display) }.value
        guard generation == loadGeneration else { return }
        isProbing = false
        probe = result
        ddcValues = [:]
        for (code, values) in result.values where values.count == 2 && values[1] > 0 {
            ddcValues[code] = (Double(values[0]), Double(values[1]))
        }
        method = BrightnessService.method(for: display, ddc: result)
        switch method {
        case .ddc:
            if let b = ddcValues[VCPCode.brightness.rawValue] { brightness = b.current / b.maximum }
        default:
            brightness = GammaService.shared.adjustment(for: display.id).dimming
        }
        loadCombined(display)
        if result.status == .supported {
            await loadDDCControls(display, generation: generation)
        } else if let text = Self.previewCapabilities, !text.isEmpty {
            // DDC 응답이 없는 외장 디스플레이에서 화면 구성만 확인하는 용도. 값은 임의의 중간값.
            let capabilities = DDCCapabilities.parse(text)
            ddcControls = DDCControlPlan.controls(for: capabilities)
            ddcOtherCodes = DDCControlPlan.otherCodes(in: capabilities)
            for control in ddcControls where control.isContinuous { ddcValues[control.code] = (50, 100) }
            probe = DDCProbe(status: .supported)
            ddcPreview = true
        }
    }

    /// capabilities를 읽어 제어 항목을 구성하고, 탐지에서 읽지 않은 연속 값 코드의 현재값을 읽음. (PRD-DDC-005)
    private func loadDDCControls(_ display: DisplaySummary, generation: Int) async {
        let known = Set(ddcValues.keys)
        let loaded = await Task.detached { () -> (controls: [DDCControl], others: [UInt8], values: [UInt8: (Double, Double)])? in
            guard let service = SignalService.avService(for: display), let capabilities = DDCService.capabilities(service: service) else { return nil }
            let controls = DDCControlPlan.controls(for: capabilities)
            var values: [UInt8: (Double, Double)] = [:]
            for control in controls where control.isContinuous && !known.contains(control.code) {
                if let reply = DDCService.read(control.code, service: service), reply.maximum > 0 {
                    values[control.code] = (Double(reply.current), Double(reply.maximum))
                }
            }
            return (controls, DDCControlPlan.otherCodes(in: capabilities), values)
        }.value
        guard generation == loadGeneration, let loaded else { return }
        for (code, value) in loaded.values { ddcValues[code] = (value.0, value.1) }
        ddcControls = loaded.controls
        ddcOtherCodes = loaded.others
    }

    /// 실행 인자 `-ddcCapabilitiesPreview <문자열>`의 값. 괄호로 시작하는 값은 기본값 저장소가 배열로 해석하므로 인자 목록에서 직접 읽음.
    private static let previewCapabilities: String? = {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-ddcCapabilitiesPreview"), index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
    }()

    private func loadReference(_ display: DisplaySummary) {
        let store = LuminanceReferenceStore.standard
        reference = store.reference(for: display.identity, edidMaximum: BrightnessSyncService.edidMaximum(display))
        referenceText = store.userValue(for: display.identity).map { BacklightLuminance.format($0) } ?? ""
    }

    /// 최대 휘도 기준값 지정. 빈 문자열이면 해제.
    func applyReference(display: DisplaySummary) {
        let text = referenceText.trimmingCharacters(in: .whitespaces)
        do {
            if text.isEmpty {
                try LuminanceReferenceStore.standard.set(nil, for: display.identity)
            } else {
                guard let value = Double(text) else {
                    message = "최대 휘도는 숫자로 입력"
                    return
                }
                try LuminanceReferenceStore.standard.set(value, for: display.identity)
            }
            message = nil
        } catch {
            message = RevertCoordinator.describe(error)
        }
        loadReference(display)
    }

    private static func combinedKey(_ display: DisplaySummary) -> String {
        "combinedBrightness.\(display.identity.uuid ?? String(display.id))"
    }

    private var hardwareFloor: Double { CombinedBrightness.hardwareFloor(for: method) }

    /// 저장된 결합 밝기 사용 여부와 현재 값 반영. 소프트웨어 방식은 대상 아님.
    private func loadCombined(_ display: DisplaySummary) {
        combinedEnabled = method != .software && UserDefaults.standard.bool(forKey: Self.combinedKey(display))
        combined = CombinedBrightness.combined(hardware: brightness, dimming: GammaService.shared.adjustment(for: display.id).dimming, hardwareFloor: hardwareFloor)
    }

    func setCombinedEnabled(_ enabled: Bool, display: DisplaySummary) {
        combinedEnabled = enabled && method != .software
        UserDefaults.standard.set(combinedEnabled, forKey: Self.combinedKey(display))
        if combinedEnabled {
            combined = CombinedBrightness.combined(hardware: brightness, dimming: GammaService.shared.adjustment(for: display.id).dimming, hardwareFloor: hardwareFloor)
        } else {
            // 끄면 디밍만 해제하고 하드웨어 밝기는 그대로 둠.
            var adjustment = GammaService.shared.adjustment(for: display.id)
            adjustment.dimming = 1
            do { try GammaService.shared.apply(adjustment, to: display.id) } catch { message = RevertCoordinator.describe(error) }
        }
    }

    func setCombined(_ value: Double, display: DisplaySummary) {
        combined = value
        let levels = CombinedBrightness.levels(for: value, hardwareFloor: hardwareFloor)
        brightness = levels.hardware
        do {
            switch method {
            case .native:
                try BrightnessService.applyCombined(value, to: display, method: .native)
            case .ddc:
                // 디밍은 바로, DDC 쓰기는 모아서 적용.
                var adjustment = GammaService.shared.adjustment(for: display.id)
                adjustment.dimming = levels.dimming
                try GammaService.shared.apply(adjustment, to: display.id)
                let maximum = UInt16(ddcValues[VCPCode.brightness.rawValue]?.maximum ?? 100)
                scheduleDDC { try? BrightnessService.setDDCBrightness(levels.hardware, for: display, maximum: maximum) }
            case .software:
                break
            }
            message = nil
        } catch {
            message = RevertCoordinator.describe(error)
        }
    }

    /// 결합 밝기의 현재 분해 결과 표기.
    var combinedDescription: String {
        CombinedBrightness.describe(CombinedBrightness.levels(for: combined, hardwareFloor: hardwareFloor))
    }

    func setBrightness(_ value: Double, display: DisplaySummary) {
        brightness = value
        do {
            switch method {
            case .native:
                try BrightnessService.setNativeBrightness(value, on: display.id)
            case .ddc:
                let maximum = UInt16(ddcValues[VCPCode.brightness.rawValue]?.maximum ?? 100)
                scheduleDDC { try? BrightnessService.setDDCBrightness(value, for: display, maximum: maximum) }
            case .software:
                var adjustment = GammaService.shared.adjustment(for: display.id)
                adjustment.dimming = value
                try GammaService.shared.apply(adjustment, to: display.id)
            }
            message = nil
        } catch {
            message = RevertCoordinator.describe(error)
        }
    }

    func setXDRBoost(_ value: Double, display: DisplaySummary) {
        xdrBoost = value
        do {
            try XDRBoostService.shared.setBoost(value, for: display.id)
            xdrMessage = nil
        } catch {
            xdrMessage = RevertCoordinator.describe(error)
        }
    }

    func setOverlay(_ value: Double, display: DisplaySummary) {
        overlayStrength = value
        do {
            try OverlayDimService.shared.setStrength(value, for: display.id)
            message = nil
        } catch {
            message = RevertCoordinator.describe(error)
        }
    }

    func setAuto(_ enabled: Bool, display: DisplaySummary) {
        do {
            try BrightnessService.setAutoBrightness(enabled, on: display.id)
            autoEnabled = BrightnessService.autoBrightnessEnabled(display.id) ?? enabled
        } catch {
            message = RevertCoordinator.describe(error)
        }
    }

    func setDDC(_ code: VCPCode, value: Double, display: DisplaySummary) {
        setDDC(code: code.rawValue, value: value, display: display)
    }

    func setDDC(code: UInt8, value: Double, display: DisplaySummary) {
        if let existing = ddcValues[code] { ddcValues[code] = (value, existing.maximum) }
        guard !ddcPreview else { return }
        scheduleDDC {
            guard let service = SignalService.avService(for: display) else { return }
            DDCService.write(code, value: UInt16(value.rounded()), service: service)
        }
    }

    func readRaw(display: DisplaySummary) async {
        guard let code = VCPCode.parse(rawCode) else {
            rawResult = "코드 형식 오류"
            return
        }
        let reply = await Task.detached { SignalService.avService(for: display).flatMap { DDCService.read(code, service: $0) } }.value
        rawResult = reply.map { "현재 \($0.current), 최대 \($0.maximum)" } ?? "응답 없음 또는 미지원 코드"
    }

    func writeRaw(display: DisplaySummary) async {
        guard let code = VCPCode.parse(rawCode), let value = UInt16(rawValue) else {
            rawResult = "코드 또는 값 형식 오류"
            return
        }
        let ok = await Task.detached { SignalService.avService(for: display).map { DDCService.write(code, value: value, service: $0) } ?? false }.value
        rawResult = ok ? "쓰기 완료" : "쓰기 실패"
    }

    /// 슬라이더를 끄는 동안의 연속 쓰기를 150 ms 간격으로 묶어 마지막 값만 전송.
    private func scheduleDDC(_ work: @escaping @Sendable () -> Void) {
        pendingWrite?.cancel()
        pendingWrite = Task.detached {
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            work()
        }
    }
}

/// 밝기 탭: 밝기, 자동 밝기, 밝기 동기화, XDR 밝기 업스케일, DDC 기능. (PRD-BRT-001-006, PRD-DDC-001-003)
struct BrightnessTab: View {
    @Environment(ChangeController.self) private var changes
    @Environment(DisplayStore.self) private var store
    @Environment(BrightnessSyncController.self) private var sync
    let display: DisplaySummary
    @State private var model = BrightnessViewModel()

    var body: some View {
        Form {
            Section("밝기") {
                LabeledContent("제어 방식", value: model.isProbing ? "확인 중" : model.method.title)
                HStack(spacing: 10) {
                    Image(systemName: "sun.min")
                    if model.combinedEnabled {
                        Slider(value: Binding(get: { model.combined }, set: { model.setCombined($0, display: display) }), in: 0...1)
                            .disabled(model.isProbing || changes.isBusy)
                    } else {
                        Slider(value: Binding(get: { model.brightness }, set: { model.setBrightness($0, display: display) }), in: sliderRange)
                            .disabled(model.isProbing || changes.isBusy)
                    }
                    Image(systemName: "sun.max")
                    Text("\(Int(((model.combinedEnabled ? model.combined : model.brightness) * 100).rounded()))%")
                        .monospacedDigit()
                        .frame(width: 44, alignment: .trailing)
                }
                if let luminance = model.luminance {
                    LabeledContent("휘도", value: luminance.summary)
                        .help("백라이트 드라이버가 보고하는 현재 휘도. 자동 밝기와 HDR 표시 상태에 따라 변함")
                }
                if model.luminance == nil, !model.isProbing {
                    if let reference = model.reference {
                        LabeledContent("휘도", value: reference.summary(level: model.brightness))
                            .help("밝기 비율과 최대 휘도 기준값을 곱한 추정값. 측정값 아님")
                    }
                    LabeledContent("최대 휘도 기준값") {
                        HStack(spacing: 6) {
                            TextField("최대 휘도", text: $model.referenceText, prompt: Text("미지정"))
                                .labelsHidden()
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                                .onSubmit { model.applyReference(display: display) }
                            Text("cd/m²").foregroundStyle(.secondary)
                            Button("적용") { model.applyReference(display: display) }
                                .controlSize(.small)
                        }
                    }
                    .help("추정 휘도 표시와 휘도 기준 밝기 동기화에 사용. 비우고 적용하면 해제 (EDID가 알린 값이 있으면 그 값 사용)")
                }
                if model.method != .software, !model.isProbing {
                    Toggle("결합 밝기 (하드웨어 최저 아래는 소프트웨어 디밍)", isOn: Binding(get: { model.combinedEnabled }, set: { model.setCombinedEnabled($0, display: display) }))
                        .help("조절 범위의 아래쪽 25%는 하드웨어 밝기를 최저에 둔 채 전달 테이블로 더 어둡게 함. 디밍은 앱 실행 중에만 유지")
                    if model.combinedEnabled {
                        LabeledContent("현재 구성", value: model.combinedDescription)
                    }
                }
                if model.method == .software, !model.isProbing {
                    Text("하드웨어 밝기 제어를 쓸 수 없어 전달 테이블로 화면 출력값을 낮춤. 백라이트는 그대로이며 앱을 종료하면 원래 밝기로 복귀")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if model.autoAvailable {
                    Toggle("자동 밝기 (주변광 반응)", isOn: Binding(get: { model.autoEnabled }, set: { model.setAuto($0, display: display) }))
                }
                if let message = model.message {
                    Label(message, systemImage: "exclamationmark.triangle").foregroundStyle(.red)
                }
            }
            Section("오버레이 디밍") {
                HStack(spacing: 10) {
                    Image(systemName: "circle.lefthalf.filled")
                    Slider(value: Binding(get: { model.overlayStrength }, set: { model.setOverlay($0, display: display) }), in: OverlayDim.range)
                    Text("\(Int((model.overlayStrength * 100).rounded()))%")
                        .monospacedDigit()
                        .frame(width: 44, alignment: .trailing)
                    Button("끄기") { model.setOverlay(0, display: display) }
                        .disabled(model.overlayStrength <= 0.001)
                }
                Text("화면 위에 검은 창을 덮어 어둡게 함. 하드웨어 밝기 0%보다 더 어둡게 할 때와 전달 테이블을 쓸 수 없는 디스플레이에 사용. 앱을 종료하면 해제")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if store.displays.count > 1 {
                Section("밝기 동기화") {
                    Toggle("이 디스플레이의 밝기를 다른 디스플레이에 동기화", isOn: Binding(
                        get: { sync.isSource(display.id) },
                        set: { isOn in
                            if isOn { sync.start(source: display.id) } else { sync.stop() }
                        }
                    ))
                    Toggle("휘도 기준으로 맞춤", isOn: Binding(get: { sync.normalizesLuminance }, set: { sync.normalizesLuminance = $0 }))
                        .help("원본의 휘도(cd/m²)를 대상의 최대 휘도 기준값으로 나눠 대상 밝기를 정함. 휘도를 알 수 없는 디스플레이는 비율 기준으로 처리")
                    if sync.isSource(display.id) {
                        ForEach(sync.lastResults, id: \.displayID) { result in
                            LabeledContent(result.displayName, value: "\(result.method.title) \(Int((result.level * 100).rounded()))%" + (result.targetNits.map { ", 목표 \(BacklightLuminance.format($0)) cd/m²" } ?? "") + (result.failure.map { ", 실패: \($0)" } ?? ""))
                        }
                    }
                    Text("1초마다 이 디스플레이의 밝기를 읽어 나머지 디스플레이에 같은 비율로 적용. 대상은 시스템 밝기 제어, DDC, 소프트웨어 디밍 순으로 방식 선택. 앱 실행 중에만 동작")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if model.xdrSupported {
                Section("XDR 밝기 업스케일") {
                    HStack(spacing: 10) {
                        Image(systemName: "sun.max")
                        Slider(value: Binding(get: { model.xdrBoost }, set: { model.setXDRBoost($0, display: display) }), in: 1.0...max(1.01, model.xdrMaximum))
                        Image(systemName: "sun.max.fill")
                        Text("\(Int((model.xdrBoost * 100).rounded()))%")
                            .monospacedDigit()
                            .frame(width: 44, alignment: .trailing)
                        Button("끄기") { model.setXDRBoost(1, display: display) }
                            .disabled(model.xdrBoost <= 1.001)
                    }
                    Text("EDR 헤드룸을 써서 SDR 화면을 최대 밝기보다 밝게 출력. HDR 콘텐츠의 밝은 영역은 잘릴 수 있고 전력 소모와 발열이 늘어남. 앱을 종료하면 해제")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let message = model.xdrMessage {
                        Label(message, systemImage: "exclamationmark.triangle").foregroundStyle(.red)
                    }
                }
            }
            Section("DDC") {
                if model.isProbing {
                    HStack { ProgressView().controlSize(.small); Text("DDC 응답 확인 중") }
                } else if let probe = model.probe {
                    LabeledContent("상태") {
                        HStack(spacing: 8) {
                            Text(probe.status == .supported ? "지원" : "사용 불가")
                            if probe.status != .notApplicable {
                                Button("다시 확인") { Task { await model.load(display) } }
                            }
                        }
                    }
                    if probe.status != .supported {
                        Text(probe.reason).font(.callout).foregroundStyle(.secondary)
                    } else {
                        ddcControls
                    }
                }
            }
        }
        .formStyle(.grouped)
        .task(id: display.id) {
            await model.load(display)
            // 휘도는 밝기 조절, 자동 밝기, HDR 표시에 따라 변하므로 탭이 보이는 동안 1초 간격으로 다시 읽음.
            while !Task.isCancelled {
                model.luminance = BrightnessService.backlightLuminance(for: display)
                guard model.luminance != nil else { break }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private var sliderRange: ClosedRange<Double> {
        model.method == .software ? ColorAdjustment.dimmingRange : 0...1
    }

    /// capabilities가 알린 코드로 구성한 제어 항목. (PRD-DDC-005)
    @ViewBuilder
    private var plannedDDCControls: some View {
        if model.ddcPreview {
            Label("화면 구성 미리 보기: 실행 인자로 준 capabilities 사용. 모니터에 쓰지 않음", systemImage: "eye")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        ForEach(model.ddcControls.filter(\.isContinuous)) { control in
            if let value = model.ddcValues[control.code] {
                HStack(spacing: 10) {
                    Text(control.title).frame(width: 110, alignment: .leading)
                    Slider(value: Binding(get: { value.current }, set: { model.setDDC(code: control.code, value: $0, display: display) }), in: 0...value.maximum)
                    Text("\(Int(value.current.rounded()))").monospacedDigit().frame(width: 44, alignment: .trailing)
                }
            } else {
                LabeledContent(control.title, value: "현재값 응답 없음 (\(control.codeLabel))")
            }
        }
        ForEach(model.ddcControls.filter { !$0.isContinuous }) { control in
            LabeledContent(control.title) {
                if control.options.count > 5 {
                    Menu("선택") {
                        ForEach(control.options, id: \.value) { option in
                            Button(option.name) { model.setDDC(code: control.code, value: Double(option.value), display: display) }
                        }
                    }
                    .fixedSize()
                } else {
                    HStack(spacing: 6) {
                        ForEach(control.options, id: \.value) { option in
                            Button(option.name) { model.setDDC(code: control.code, value: Double(option.value), display: display) }
                                .controlSize(.small)
                        }
                    }
                }
            }
        }
        if model.ddcControls.contains(where: \.isDisruptive) {
            Text("입력 소스나 전원 모드를 바꾸면 이 Mac의 화면이 꺼질 수 있음. 되돌리려면 디스플레이의 버튼이나 리모컨 사용")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        if !model.ddcOtherCodes.isEmpty {
            Text("그 밖의 지원 코드 \(model.ddcOtherCodes.count)개: " + model.ddcOtherCodes.map { String(format: "%02X", $0) }.joined(separator: " ") + ". 아래 임의 VCP 코드로 접근")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var ddcControls: some View {
        if !model.ddcControls.isEmpty {
            plannedDDCControls
        } else {
            fixedDDCControls
        }
        DisclosureGroup("임의 VCP 코드") {
            HStack {
                TextField("코드 (예: 0x10)", text: $model.rawCode).frame(width: 130)
                TextField("값", text: $model.rawValue).frame(width: 90)
                Button("읽기") { Task { await model.readRaw(display: display) } }
                Button("쓰기") { Task { await model.writeRaw(display: display) } }
                if let result = model.rawResult { Text(result).foregroundStyle(.secondary) }
            }
        }
    }

    /// capabilities를 읽지 못한 모니터용 고정 구성.
    @ViewBuilder
    private var fixedDDCControls: some View {
        ForEach([VCPCode.contrast, .volume], id: \.self) { code in
            if let value = model.ddcValues[code.rawValue] {
                HStack(spacing: 10) {
                    Text(code.title).frame(width: 70, alignment: .leading)
                    Slider(value: Binding(get: { value.current }, set: { model.setDDC(code, value: $0, display: display) }), in: 0...value.maximum)
                    Text("\(Int(value.current.rounded()))").monospacedDigit().frame(width: 44, alignment: .trailing)
                }
            }
        }
        ForEach([VCPCode.inputSource, .mute, .powerMode], id: \.self) { code in
            LabeledContent(code.title) {
                HStack(spacing: 6) {
                    ForEach(code.options, id: \.value) { option in
                        Button(option.name) { model.setDDC(code, value: Double(option.value), display: display) }
                            .controlSize(.small)
                    }
                }
            }
        }
        Text("입력 소스나 전원 모드를 바꾸면 이 Mac의 화면이 꺼질 수 있음. 되돌리려면 디스플레이의 버튼이나 리모컨 사용")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
