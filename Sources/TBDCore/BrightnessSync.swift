import Foundation

/// 밝기 동기화 계산: 원본 디스플레이의 밝기를 다른 디스플레이에 같은 비율로 적용. (PRD-BRT-006, SRS-BRT-003)
public enum BrightnessSync {
    /// 다시 적용하는 최소 변화량.
    public static let threshold = 0.01

    /// 원본 밝기(0-1)를 대상의 제어 방식이 허용하는 범위로 변환.
    /// 소프트웨어 디밍은 하한이 있어 그 아래로 내려가지 않음.
    public static func targetLevel(source: Double, method: BrightnessMethod) -> Double {
        let level = min(max(source, 0), 1)
        switch method {
        case .native, .ddc: return level
        case .software: return max(level, ColorAdjustment.dimmingRange.lowerBound)
        }
    }

    /// 휘도 기준 변환: 원본의 휘도(cd/m²)를 대상의 최대 휘도로 나눈 비율을 대상 밝기로 사용. (PRD-BRT-010)
    /// 원본이 대상의 최대 휘도보다 밝으면 대상은 최대 밝기. 대상의 최대 휘도가 0 이하면 nil.
    public static func normalizedLevel(sourceNits: Double, targetMaximumNits: Double, method: BrightnessMethod) -> Double? {
        guard targetMaximumNits > 0, sourceNits >= 0 else { return nil }
        return targetLevel(source: sourceNits / targetMaximumNits, method: method)
    }

    /// 마지막 적용값과의 차이가 임계값 이상이면 적용.
    public static func shouldApply(new: Double, last: Double?) -> Bool {
        guard let last else { return true }
        return abs(new - last) >= threshold
    }
}

/// 동기화 1회의 대상별 결과.
public struct BrightnessSyncResult: Codable, Hashable, Sendable {
    public var displayID: UInt32
    public var displayName: String
    public var method: BrightnessMethod
    public var level: Double
    /// 실패 사유. 성공이면 nil.
    public var failure: String?
    /// 휘도 기준으로 계산한 경우의 목표 휘도 (cd/m²). 비율 기준이면 nil.
    public var targetNits: Double?

    public init(displayID: UInt32, displayName: String, method: BrightnessMethod, level: Double, failure: String?, targetNits: Double? = nil) {
        self.displayID = displayID
        self.displayName = displayName
        self.method = method
        self.level = level
        self.failure = failure
        self.targetNits = targetNits
    }
}
