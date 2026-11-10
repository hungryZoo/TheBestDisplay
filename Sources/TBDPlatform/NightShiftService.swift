import Foundation
import TBDCore

/// Night Shift 제어. `CBBlueLightClient` 동적 호출. 형식 부호는 T11 실측. (SRS-CLR-003)
public enum NightShiftService {
    typealias StatusFn = @convention(c) (NSObject, Selector, UnsafeMutableRawPointer) -> Bool
    typealias GetFloatFn = @convention(c) (NSObject, Selector, UnsafeMutablePointer<Float>) -> Bool
    typealias SetBoolFn = @convention(c) (NSObject, Selector, Bool) -> Bool
    typealias SetStrengthFn = @convention(c) (NSObject, Selector, Float, Bool) -> Bool

    static func client(_ symbols: PrivateSymbols) -> NSObject? {
        guard let cls = symbols.objcClass("CBBlueLightClient", in: .coreBrightness) as? NSObject.Type else { return nil }
        return cls.init()
    }

    static func method<T>(_ object: NSObject, _ name: String, as type: T.Type) -> (T, Selector)? {
        let selector = NSSelectorFromString(name)
        guard object.responds(to: selector) else { return nil }
        return (unsafeBitCast(object.method(for: selector), to: T.self), selector)
    }

    public static func status(symbols: PrivateSymbols = .shared) -> NightShiftStatus? {
        guard let client = client(symbols), let (get, selector) = method(client, "getBlueLightStatus:", as: StatusFn.self) else { return nil }
        // 구조체보다 넉넉한 버퍼.
        var buffer = [UInt8](repeating: 0, count: 64)
        guard get(client, selector, &buffer) else { return nil }
        var strength: Double?
        if let (getStrength, strengthSelector) = method(client, "getStrength:", as: GetFloatFn.self) {
            var value: Float = 0
            if getStrength(client, strengthSelector, &value) { strength = Double(value) }
        }
        return NightShiftStatus.decodeStatus(buffer, strength: strength)
    }

    public static func setEnabled(_ enabled: Bool, symbols: PrivateSymbols = .shared) throws {
        guard let client = client(symbols), let (set, selector) = method(client, "setEnabled:", as: SetBoolFn.self) else {
            throw DisplayChangeError.unavailable("CBBlueLightClient setEnabled: 없음")
        }
        guard set(client, selector, enabled) else { throw DisplayChangeError.system(operation: "Night Shift 전환", code: -1) }
    }

    /// 강도 0-1.
    public static func setStrength(_ strength: Double, symbols: PrivateSymbols = .shared) throws {
        guard let client = client(symbols), let (set, selector) = method(client, "setStrength:commit:", as: SetStrengthFn.self) else {
            throw DisplayChangeError.unavailable("CBBlueLightClient setStrength:commit: 없음")
        }
        guard set(client, selector, Float(min(max(strength, 0), 1)), true) else { throw DisplayChangeError.system(operation: "Night Shift 강도 지정", code: -1) }
    }
}

/// True Tone 제어. `CBTrueToneClient` 동적 호출.
public enum TrueToneService {
    typealias GetBoolFn = @convention(c) (NSObject, Selector) -> Bool
    typealias SetBoolFn = @convention(c) (NSObject, Selector, Bool) -> Bool

    static func client(_ symbols: PrivateSymbols) -> NSObject? {
        guard let cls = symbols.objcClass("CBTrueToneClient", in: .coreBrightness) as? NSObject.Type else { return nil }
        return cls.init()
    }

    public static func status(symbols: PrivateSymbols = .shared) -> TrueToneStatus? {
        guard let client = client(symbols) else { return nil }
        func query(_ name: String) -> Bool? {
            NightShiftService.method(client, name, as: GetBoolFn.self).map { $0.0(client, $0.1) }
        }
        guard let supported = query("supported") else { return nil }
        return TrueToneStatus(isSupported: supported, isAvailable: query("available") ?? false, isEnabled: query("enabled") ?? false)
    }

    public static func setEnabled(_ enabled: Bool, symbols: PrivateSymbols = .shared) throws {
        guard let client = client(symbols), let (set, selector) = NightShiftService.method(client, "setEnabled:", as: SetBoolFn.self) else {
            throw DisplayChangeError.unavailable("CBTrueToneClient setEnabled: 없음")
        }
        guard set(client, selector, enabled) else { throw DisplayChangeError.system(operation: "True Tone 전환", code: -1) }
    }
}
