import CoreGraphics
import Foundation
import TBDCore

/// 밝기 동기화 실행. 원본의 밝기를 읽어 나머지 디스플레이에 적용. (SRS-BRT-003)
/// 대상의 제어 방식: 시스템 밝기 제어가 되면 그 방식, 아니면 DDC 탐지 결과에 따라 DDC 또는 소프트웨어 디밍.
/// 소프트웨어 디밍은 프로세스 수명 동안만 유지.
public final class BrightnessSyncService {
    private var methods: [UInt32: BrightnessMethod] = [:]
    private var ddcMaximums: [UInt32: UInt16] = [:]
    private var lastApplied: [UInt32: Double] = [:]

    public init() {}

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
        var results: [BrightnessSyncResult] = []
        for target in displays where target.id != source.id && target.mirrorsDisplayID == nil {
            let method = method(for: target)
            let value = BrightnessSync.targetLevel(source: level, method: method)
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
            results.append(BrightnessSyncResult(displayID: target.id, displayName: target.identity.name, method: method, level: value, failure: failure))
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
