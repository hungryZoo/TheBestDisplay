import CoreGraphics
import Foundation
import TBDCore

/// 밝기 조회와 설정. 제어 방식 선택 순서: 시스템 밝기 제어, DDC, 소프트웨어 디밍. (SRS-BRT-001)
public enum BrightnessService {
    // 시그니처 근거: spikes 문서 S6(실측), DisplayServices 디스어셈블(T10).
    typealias GetFn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    typealias SetFn = @convention(c) (CGDirectDisplayID, Float) -> Int32
    typealias QueryFn = @convention(c) (CGDirectDisplayID) -> Bool
    typealias GetBoolFn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Bool>) -> Int32
    typealias SetBoolFn = @convention(c) (CGDirectDisplayID, Bool) -> Int32

    static let appleVendorID: UInt32 = 0x610

    /// 시스템 밝기 제어 대상 여부. 내장 패널과 Apple 디스플레이만 해당.
    /// 타사 외장 디스플레이도 `DisplayServicesCanChangeBrightness`가 참을 돌려주는 경우가 있어(LG TV 실측) 제조사로 한정.
    public static func supportsNative(_ display: DisplaySummary, symbols: PrivateSymbols = .shared) -> Bool {
        guard display.identity.isBuiltin || display.identity.vendorID == appleVendorID,
              let can = symbols.function("DisplayServicesCanChangeBrightness", in: .displayServices, as: QueryFn.self)
        else { return false }
        return can(display.id)
    }

    /// 제어 방식 결정. DDC 탐지 결과가 없으면 DDC는 후보에서 제외.
    public static func method(for display: DisplaySummary, ddc: DDCProbe?, symbols: PrivateSymbols = .shared) -> BrightnessMethod {
        if supportsNative(display, symbols: symbols) { return .native }
        if ddc?.status == .supported, ddc?.values[VCPCode.brightness.rawValue] != nil { return .ddc }
        return .software
    }

    /// 시스템 밝기 (0-1).
    public static func nativeBrightness(_ display: CGDirectDisplayID, symbols: PrivateSymbols = .shared) -> Double? {
        guard let get = symbols.function("DisplayServicesGetBrightness", in: .displayServices, as: GetFn.self) else { return nil }
        var value: Float = 0
        return get(display, &value) == 0 ? Double(value) : nil
    }

    public static func setNativeBrightness(_ value: Double, on display: CGDirectDisplayID, symbols: PrivateSymbols = .shared) throws {
        guard let set = symbols.function("DisplayServicesSetBrightness", in: .displayServices, as: SetFn.self) else {
            throw DisplayChangeError.unavailable("DisplayServicesSetBrightness 없음")
        }
        let result = set(display, Float(min(max(value, 0), 1)))
        guard result == 0 else { throw DisplayChangeError.system(operation: "밝기 지정", code: result) }
    }

    /// DDC 밝기 (0-1). 최댓값으로 정규화.
    public static func ddcBrightness(for display: DisplaySummary) -> Double? {
        guard let service = SignalService.avService(for: display), let reply = DDCService.read(VCPCode.brightness.rawValue, service: service), reply.maximum > 0 else { return nil }
        return Double(reply.current) / Double(reply.maximum)
    }

    public static func setDDCBrightness(_ value: Double, for display: DisplaySummary, maximum: UInt16) throws {
        guard let service = SignalService.avService(for: display) else { throw DisplayChangeError.displayNotFound }
        let raw = UInt16((min(max(value, 0), 1) * Double(maximum)).rounded())
        guard DDCService.write(VCPCode.brightness.rawValue, value: raw, service: service) else {
            throw DisplayChangeError.system(operation: "DDC 밝기 쓰기", code: -1)
        }
    }

    // MARK: - 자동 밝기 (PRD-BRT-004)

    /// 내장 패널의 현재 휘도. 내장 디스플레이가 아니거나 프레임버퍼 노드에 값이 없으면 nil. (SRS-BRT-005)
    /// 외장 디스플레이의 같은 속성은 백라이트와 무관한 고정값(200 cd/m²)이라 제외 (T52 실측).
    public static func backlightLuminance(for display: DisplaySummary) -> BacklightLuminance? {
        guard display.identity.isBuiltin, let node = SignalService.framebufferNode(for: display) else { return nil }
        defer { IOObjectRelease(node.service) }
        var properties: [String: Any] = [:]
        for key in ["IOMFBBrightnessLevel", "BLNitsCap", "IOMFBIndicatorNitsCap"] {
            properties[key] = IORegistry.property(node.service, key)
        }
        return BacklightLuminance(framebufferProperties: properties)
    }

    public static func hasAutoBrightness(_ display: CGDirectDisplayID, symbols: PrivateSymbols = .shared) -> Bool {
        symbols.function("DisplayServicesHasAmbientLightCompensation", in: .displayServices, as: QueryFn.self)?(display) ?? false
    }

    public static func autoBrightnessEnabled(_ display: CGDirectDisplayID, symbols: PrivateSymbols = .shared) -> Bool? {
        guard let get = symbols.function("DisplayServicesAmbientLightCompensationEnabled", in: .displayServices, as: GetBoolFn.self) else { return nil }
        var enabled = false
        return get(display, &enabled) == 0 ? enabled : nil
    }

    public static func setAutoBrightness(_ enabled: Bool, on display: CGDirectDisplayID, symbols: PrivateSymbols = .shared) throws {
        guard let set = symbols.function("DisplayServicesEnableAmbientLightCompensation", in: .displayServices, as: SetBoolFn.self) else {
            throw DisplayChangeError.unavailable("DisplayServicesEnableAmbientLightCompensation 없음")
        }
        let result = set(display, enabled)
        guard result == 0 else { throw DisplayChangeError.system(operation: "자동 밝기 지정", code: result) }
    }
}
