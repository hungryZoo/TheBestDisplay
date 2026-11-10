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

    @ObservationIgnored private var pendingWrite: Task<Void, Never>?

    func load(_ display: DisplaySummary) async {
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
            return
        }
        // DDC 탐지는 응답 대기가 있으므로 메인 스레드 밖에서 수행.
        isProbing = true
        let result = await Task.detached { DDCService.probe(for: display) }.value
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
        if let existing = ddcValues[code.rawValue] { ddcValues[code.rawValue] = (value, existing.maximum) }
        scheduleDDC {
            guard let service = SignalService.avService(for: display) else { return }
            DDCService.write(code.rawValue, value: UInt16(value.rounded()), service: service)
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
                    Slider(value: Binding(get: { model.brightness }, set: { model.setBrightness($0, display: display) }), in: sliderRange)
                        .disabled(model.isProbing || changes.isBusy)
                    Image(systemName: "sun.max")
                    Text("\(Int((model.brightness * 100).rounded()))%")
                        .monospacedDigit()
                        .frame(width: 44, alignment: .trailing)
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
                    if sync.isSource(display.id) {
                        ForEach(sync.lastResults, id: \.displayID) { result in
                            LabeledContent(result.displayName, value: "\(result.method.title) \(Int((result.level * 100).rounded()))%" + (result.failure.map { ", 실패: \($0)" } ?? ""))
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
        .task(id: display.id) { await model.load(display) }
    }

    private var sliderRange: ClosedRange<Double> {
        model.method == .software ? ColorAdjustment.dimmingRange : 0...1
    }

    @ViewBuilder
    private var ddcControls: some View {
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
}
