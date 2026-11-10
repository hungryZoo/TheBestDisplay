import Foundation

/// 주사율 측정 결과. 화면 갱신 콜백의 시각 간격으로 계산한 소프트웨어 관측값이며 패널 계측값이 아님. (PRD-MOD-008)
public struct RefreshMeasurement: Codable, Hashable, Sendable {
    /// 현재 모드의 공칭 주사율 (Hz).
    public var nominalHz: Double
    /// 갱신 콜백이 보고한 프레임 주기에서 구한 주사율 (Hz). 표본이 없으면 nil.
    public var reportedHz: Double?
    /// 콜백 시각 간격의 평균으로 구한 주사율 (Hz). 표본이 2개 미만이면 nil.
    public var measuredHz: Double?
    public var minIntervalMs: Double?
    public var maxIntervalMs: Double?
    public var sampleCount: Int
    public var durationSeconds: Double

    /// 콜백 시각 목록과 보고 주기 목록에서 계산.
    public static func compute(nominalHz: Double, timestamps: [Double], reportedDurations: [Double]) -> RefreshMeasurement {
        let intervals = zip(timestamps.dropFirst(), timestamps).map { $0 - $1 }.filter { $0 > 0 }
        let span = (timestamps.last ?? 0) - (timestamps.first ?? 0)
        let durations = reportedDurations.filter { $0 > 0 }.sorted()
        return RefreshMeasurement(
            nominalHz: nominalHz,
            // 보고 주기는 중앙값 사용.
            reportedHz: durations.isEmpty ? nil : 1 / durations[durations.count / 2],
            measuredHz: intervals.isEmpty || span <= 0 ? nil : Double(intervals.count) / span,
            minIntervalMs: intervals.min().map { $0 * 1000 },
            maxIntervalMs: intervals.max().map { $0 * 1000 },
            sampleCount: timestamps.count,
            durationSeconds: max(span, 0)
        )
    }

    /// 예: "측정 119.98 Hz (보고 120.00 Hz, 공칭 120 Hz, 표본 240개)"
    public var summary: String {
        guard let measuredHz else { return "측정 불가 (표본 \(sampleCount)개)" }
        let reported = reportedHz.map { String(format: "보고 %.2f Hz, ", $0) } ?? ""
        return String(format: "측정 %.2f Hz (", measuredHz) + reported + "공칭 \(DisplaySummary.formatHz(nominalHz)) Hz, 표본 \(sampleCount)개)"
    }
}
