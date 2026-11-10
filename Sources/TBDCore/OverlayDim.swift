import Foundation

/// 오버레이 방식 디밍 계산. 화면 위에 검은 창을 덮어 어둡게 함. 전달 테이블을 쓰지 않아 색 조정과 독립. (PRD-BRT-007)
public enum OverlayDim {
    /// 디밍 강도 범위 (0은 끔, 0.9는 화면 밝기의 10%만 남김). 화면이 보이지 않게 되는 것을 막기 위한 상한.
    public static let range = 0.0...0.9

    public static func clamped(_ strength: Double) -> Double {
        min(max(strength, range.lowerBound), range.upperBound)
    }

    /// 강도에서 남는 밝기 비율.
    public static func remainingBrightness(_ strength: Double) -> Double { 1 - clamped(strength) }

    /// 백분율 표기(0-90) 해석.
    public static func parsePercent(_ text: String) -> Double? {
        guard let value = Double(text), (0...90).contains(value) else { return nil }
        return value / 100
    }
}
