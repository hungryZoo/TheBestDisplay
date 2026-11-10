import CoreGraphics
import Foundation
import TBDCore

/// MonitorPanel의 `MPDisplay` 동적 호출. 시스템 설정이 쓰는 판정(모드 표시 여부, 원본 모드 등) 조회.
/// 근거: spikes 문서 4절의 메서드 목록, 구현 중 실측(T04).
final class MPDisplayBridge {
    let object: NSObject

    init?(display: CGDirectDisplayID, symbols: PrivateSymbols = .shared) {
        guard let cls = symbols.objcClass("MPDisplay", in: .monitorPanel) as? NSObject.Type else { return nil }
        let selector = NSSelectorFromString("initWithCGSDisplayID:")
        guard cls.instancesRespond(to: selector),
              let allocated = cls.perform(NSSelectorFromString("alloc"))?.takeUnretainedValue() as? NSObject
        else { return nil }
        typealias InitFn = @convention(c) (NSObject, Selector, UInt32) -> Unmanaged<NSObject>?
        let implementation = unsafeBitCast(allocated.method(for: selector), to: InitFn.self)
        guard let created = implementation(allocated, selector, display)?.takeRetainedValue() else { return nil }
        object = created
    }

    struct ModeTraits {
        var isUserVisible: Bool
        var isNative: Bool
        var isDefault: Bool
        var isSafe: Bool
    }

    /// 모드 번호별 판정. 키-값 접근이 실패하는 항목은 건너뜀.
    func modeTraits() -> [Int32: ModeTraits] {
        guard object.responds(to: NSSelectorFromString("allModes")),
              let modes = object.value(forKey: "allModes") as? [NSObject]
        else { return [:] }
        var result: [Int32: ModeTraits] = [:]
        for mode in modes {
            guard mode.responds(to: NSSelectorFromString("modeNumber")),
                  let number = mode.value(forKey: "modeNumber") as? NSNumber
            else { continue }
            func flag(_ key: String) -> Bool {
                mode.responds(to: NSSelectorFromString(key)) && (mode.value(forKey: key) as? Bool) == true
            }
            result[number.int32Value] = ModeTraits(isUserVisible: flag("isUserVisible"), isNative: flag("isNativeMode"), isDefault: flag("isDefaultMode"), isSafe: flag("isSafeMode"))
        }
        return result
    }

    /// 시스템 설정과 같은 경로의 모드 전환. 형식 부호 `i20@0:8i16` (int 반환, int 인자) 실측.
    /// 반환값은 오류 코드(0 성공). 메서드가 없으면 nil.
    func setModeNumber(_ number: Int32) -> Int32? {
        let selector = NSSelectorFromString("setModeNumber:")
        guard object.responds(to: selector) else { return nil }
        typealias Fn = @convention(c) (NSObject, Selector, Int32) -> Int32
        return unsafeBitCast(object.method(for: selector), to: Fn.self)(object, selector, number)
    }

    func bool(_ key: String) -> Bool? {
        guard object.responds(to: NSSelectorFromString(key)) else { return nil }
        return object.value(forKey: key) as? Bool
    }
}
