import Foundation

/// 결합 밝기: 하드웨어 밝기와 소프트웨어 디밍을 한 값(0-1)으로 조절. (PRD-BRT-009)
///
/// 결합 값의 아래쪽 구간(`softwareSpan`)은 하드웨어 밝기를 하한에 둔 채 전달 테이블 디밍으로,
/// 그 위 구간은 디밍 없이 하드웨어 밝기로 대응.
public enum CombinedBrightness {
    /// 결합 값에서 소프트웨어 디밍 구간이 차지하는 폭.
    public static let softwareSpan = 0.25
    /// 시스템 밝기 제어 대상(내장 패널)의 하드웨어 하한. 0에서는 백라이트가 꺼지므로 (T52 실측: 0%는 0 cd/m²) 밝기 키 한 칸 값 유지.
    public static let nativeHardwareFloor = 1.0 / 16
    /// 디밍 하한. 전달 테이블 디밍 범위의 최솟값.
    public static var dimmingFloor: Double { ColorAdjustment.dimmingRange.lowerBound }

    public struct Levels: Equatable, Sendable {
        /// 하드웨어 밝기 (0-1).
        public var hardware: Double
        /// 전달 테이블 디밍 (디밍 하한-1). 1은 디밍 없음.
        public var dimming: Double

        public init(hardware: Double, dimming: Double) {
            self.hardware = hardware
            self.dimming = dimming
        }
    }

    /// 제어 방식별 하드웨어 하한. DDC 모니터는 0에서도 백라이트가 켜져 있으므로 0.
    public static func hardwareFloor(for method: BrightnessMethod) -> Double {
        method == .native ? nativeHardwareFloor : 0
    }

    /// 결합 값을 하드웨어 밝기와 디밍으로 분해. 범위 밖 값은 0-1로 자름.
    public static func levels(for combined: Double, hardwareFloor: Double) -> Levels {
        let value = min(max(combined, 0), 1)
        let floor = min(max(hardwareFloor, 0), 0.9)
        if value >= softwareSpan {
            let fraction = (value - softwareSpan) / (1 - softwareSpan)
            return Levels(hardware: floor + fraction * (1 - floor), dimming: 1)
        }
        return Levels(hardware: floor, dimming: dimmingFloor + (value / softwareSpan) * (1 - dimmingFloor))
    }

    /// 현재 하드웨어 밝기와 디밍에서 결합 값 계산. `levels`의 역.
    public static func combined(hardware: Double, dimming: Double, hardwareFloor: Double) -> Double {
        let floor = min(max(hardwareFloor, 0), 0.9)
        if dimming < 1 - 0.0005 {
            let fraction = (min(max(dimming, dimmingFloor), 1) - dimmingFloor) / (1 - dimmingFloor)
            return fraction * softwareSpan
        }
        let fraction = (min(max(hardware, floor), 1) - floor) / (1 - floor)
        return softwareSpan + fraction * (1 - softwareSpan)
    }

    /// 명령행 입력 해석: 0-100 범위의 백분율.
    public static func parsePercent(_ text: String) -> Double? {
        guard let value = Double(text), (0...100).contains(value) else { return nil }
        return value / 100
    }

    /// 예: "하드웨어 6%, 디밍 55%"
    public static func describe(_ levels: Levels) -> String {
        let hardware = "하드웨어 \(Int((levels.hardware * 100).rounded()))%"
        return levels.dimming >= 1 - 0.0005 ? "\(hardware), 디밍 없음" : "\(hardware), 디밍 \(Int((levels.dimming * 100).rounded()))%"
    }
}
