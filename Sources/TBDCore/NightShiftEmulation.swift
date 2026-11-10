import Foundation

/// Night Shift 연동 색온도. Night Shift가 적용되지 않는 디스플레이(TV 등)에 같은 시점에 따뜻한 색온도를 소프트웨어로 적용. (PRD-CLR-006)
public enum NightShiftEmulation {
    /// 강도 0과 1에 대응하는 색온도 (K). 시스템 Night Shift의 내부 값은 공개되지 않아 근사 범위를 사용.
    public static let coolestKelvin = 5200.0
    public static let warmestKelvin = 2800.0

    /// Night Shift 상태에서 적용할 색온도. 꺼져 있으면 6500 K (변화 없음).
    public static func kelvin(isEnabled: Bool, strength: Double?) -> Double {
        guard isEnabled else { return 6500 }
        let s = min(max(strength ?? 0.5, 0), 1)
        return coolestKelvin + (warmestKelvin - coolestKelvin) * s
    }

    /// 현재 조정 값에 Night Shift 연동 색온도를 반영. 값이 같으면 nil (다시 적용할 필요 없음).
    public static func adjusted(_ current: ColorAdjustment, isEnabled: Bool, strength: Double?) -> ColorAdjustment? {
        let target = kelvin(isEnabled: isEnabled, strength: strength)
        guard abs(current.temperature - target) >= 1 else { return nil }
        var next = current
        next.temperature = target
        return next
    }
}
