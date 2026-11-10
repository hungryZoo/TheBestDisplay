import CoreGraphics
import Foundation
import TBDCore

/// 디스플레이 프리셋 조회와 전환. 시스템 설정의 프리셋 선택과 같은 MonitorPanel 경로. (SRS-CLR-004)
/// 근거: `MPDisplay`의 `hasPresets`(B), `presets`(@), `activePreset`(@), `defaultPreset`(@), `setActivePreset:`(B, 객체 인자),
/// `MPDisplayPreset`의 `presetIndex`(Q), `presetName`(@), `presetDescription`(@), `presetGroup`(q), `isValid`(B), `isWritable`(B) 형식 부호 실측 (T24).
public enum PresetService {
    static func presetObjects(_ bridge: MPDisplayBridge) -> [NSObject] {
        guard bridge.bool("hasPresets") == true, bridge.object.responds(to: NSSelectorFromString("presets")) else { return [] }
        return bridge.object.value(forKey: "presets") as? [NSObject] ?? []
    }

    static func index(of preset: NSObject?) -> Int? {
        guard let preset, preset.responds(to: NSSelectorFromString("presetIndex")) else { return nil }
        return (preset.value(forKey: "presetIndex") as? NSNumber)?.intValue
    }

    public static func presets(for display: CGDirectDisplayID) -> [DisplayPreset] {
        guard let bridge = MPDisplayBridge(display: display) else { return [] }
        func object(_ key: String) -> NSObject? {
            bridge.object.responds(to: NSSelectorFromString(key)) ? bridge.object.value(forKey: key) as? NSObject : nil
        }
        let active = index(of: object("activePreset"))
        let fallback = index(of: object("defaultPreset"))
        return presetObjects(bridge).compactMap { preset in
            guard let number = index(of: preset) else { return nil }
            func string(_ key: String) -> String {
                preset.responds(to: NSSelectorFromString(key)) ? preset.value(forKey: key) as? String ?? "" : ""
            }
            func flag(_ key: String) -> Bool {
                preset.responds(to: NSSelectorFromString(key)) && (preset.value(forKey: key) as? Bool) == true
            }
            let group = preset.responds(to: NSSelectorFromString("presetGroup")) ? (preset.value(forKey: "presetGroup") as? NSNumber)?.intValue ?? 0 : 0
            return DisplayPreset(
                index: number, name: string("presetName"), detail: string("presetDescription"), group: group,
                isActive: number == active, isDefault: number == fallback, isValid: flag("isValid"), isWritable: flag("isWritable")
            )
        }
    }

    public static func setActive(index target: Int, on display: CGDirectDisplayID) throws {
        guard let bridge = MPDisplayBridge(display: display) else { throw DisplayChangeError.unavailable("MonitorPanel 사용 불가") }
        guard let preset = presetObjects(bridge).first(where: { index(of: $0) == target }) else {
            throw DisplayChangeError.unavailable("프리셋 번호 \(target) 없음")
        }
        let selector = NSSelectorFromString("setActivePreset:")
        guard bridge.object.responds(to: selector) else { throw DisplayChangeError.unavailable("프리셋 전환 메서드 없음") }
        typealias Fn = @convention(c) (NSObject, Selector, NSObject) -> Bool
        let accepted = unsafeBitCast(bridge.object.method(for: selector), to: Fn.self)(bridge.object, selector, preset)
        guard accepted else { throw DisplayChangeError.system(operation: "프리셋 전환", code: -1) }
    }
}
