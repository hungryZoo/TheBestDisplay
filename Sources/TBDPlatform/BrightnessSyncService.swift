import CoreGraphics
import Foundation
import TBDCore

/// 밝기 동기화 실행. 원본의 밝기를 읽어 나머지 디스플레이에 적용. (SRS-BRT-003)
/// 대상의 제어 방식: 시스템 밝기 제어가 되면 그 방식, 아니면 DDC 탐지 결과에 따라 DDC 또는 소프트웨어 디밍.
/// 소프트웨어 디밍은 프로세스 수명 동안만 유지.
/// 호출은 한 번에 하나씩만 수행 (실행기가 차례로 호출). 대상의 DDC 탐지가 수 초 걸릴 수 있어 메인 스레드 밖에서 호출.
public final class BrightnessSyncService: @unchecked Sendable {
    private var methods: [UInt32: BrightnessMethod] = [:]
    private var ddcMaximums: [UInt32: UInt16] = [:]
    private var lastApplied: [UInt32: Double] = [:]
    /// 휘도 기준 동기화: 원본의 휘도를 대상의 최대 휘도로 나눠 대상 밝기를 정함. 휘도를 알 수 없는 쪽이 있으면 비율 기준으로 처리. (SRS-BRT-007)
    public var normalizesLuminance: Bool
    private let references: LuminanceReferenceStore
    private var edidMaximums: [UInt32: Double?] = [:]

    public init(normalizesLuminance: Bool = false, references: LuminanceReferenceStore = .standard) {
        self.normalizesLuminance = normalizesLuminance
        self.references = references
    }

    /// 디스플레이의 최대 휘도 기준값. EDID 값은 한 번 읽어 둠.
    public func reference(for display: DisplaySummary) -> LuminanceReference? {
        if edidMaximums[display.id] == nil {
            edidMaximums[display.id] = .some(Self.edidMaximum(display))
        }
        return references.reference(for: display.identity, edidMaximum: edidMaximums[display.id] ?? nil)
    }

    /// EDID의 HDR 정적 메타데이터가 알린 최대 휘도. 없으면 nil.
    public static func edidMaximum(_ display: DisplaySummary) -> Double? {
        EDIDSource.record(for: display, among: DisplayCatalog.displays())?.parsed.cta?.hdr?.maxLuminance
    }

    /// 원본의 현재 휘도 (cd/m²): 내장 패널은 백라이트 보고 값, 그 밖은 밝기 비율 x 최대 휘도 기준값.
    public func sourceNits(_ source: DisplaySummary, level: Double) -> Double? {
        if let luminance = BrightnessService.backlightLuminance(for: source) { return luminance.current }
        return reference(for: source)?.estimatedNits(level: level)
    }

    /// 원본 디스플레이의 현재 밝기 (0-1). 시스템 밝기 제어 대상이 아니면 소프트웨어 디밍 값.
    public static func sourceLevel(_ source: DisplaySummary) -> Double? {
        if BrightnessService.supportsNative(source) { return BrightnessService.nativeBrightness(source.id) }
        return GammaService.shared.adjustment(for: source.id).dimming
    }

    private func method(for display: DisplaySummary) -> BrightnessMethod {
        if let known = methods[display.id] { return known }
        let method: BrightnessMethod
        if BrightnessService.supportsNative(display) {
            method = .native
        } else {
            let probe = DDCService.probe(for: display)
            method = BrightnessService.method(for: display, ddc: probe)
            if method == .ddc, let maximum = probe.values[VCPCode.brightness.rawValue]?.last { ddcMaximums[display.id] = maximum }
        }
        methods[display.id] = method
        return method
    }

    /// 동기화 1회. 값이 임계값 이상 바뀐 대상만 적용하고 그 결과를 반환.
    public func syncOnce(source: DisplaySummary, displays: [DisplaySummary]) -> [BrightnessSyncResult] {
        guard let level = Self.sourceLevel(source) else { return [] }
        let nits = normalizesLuminance ? sourceNits(source, level: level) : nil
        var results: [BrightnessSyncResult] = []
        for target in displays where target.id != source.id && target.mirrorsDisplayID == nil {
            let method = method(for: target)
            var value = BrightnessSync.targetLevel(source: level, method: method)
            var targetNits: Double?
            if let nits, let reference = reference(for: target),
               let normalized = BrightnessSync.normalizedLevel(sourceNits: nits, targetMaximumNits: reference.maximumNits, method: method) {
                value = normalized
                targetNits = reference.estimatedNits(level: normalized)
            }
            guard BrightnessSync.shouldApply(new: value, last: lastApplied[target.id]) else { continue }
            var failure: String?
            do {
                switch method {
                case .native:
                    try BrightnessService.setNativeBrightness(value, on: target.id)
                case .ddc:
                    try BrightnessService.setDDCBrightness(value, for: target, maximum: ddcMaximums[target.id] ?? 100)
                case .software:
                    var adjustment = GammaService.shared.adjustment(for: target.id)
                    adjustment.dimming = value
                    try GammaService.shared.apply(adjustment, to: target.id)
                }
                lastApplied[target.id] = value
            } catch {
                failure = RevertCoordinator.describe(error)
            }
            results.append(BrightnessSyncResult(displayID: target.id, displayName: target.identity.name, method: method, level: value, failure: failure, targetNits: targetNits))
        }
        return results
    }

    /// 동기화 종료: 소프트웨어 디밍으로 낮춘 대상을 원래 밝기로 복원.
    public func stop() {
        for (id, method) in methods where method == .software {
            var adjustment = GammaService.shared.adjustment(for: id)
            adjustment.dimming = 1
            try? GammaService.shared.apply(adjustment, to: id)
        }
        lastApplied.removeAll()
    }
}
