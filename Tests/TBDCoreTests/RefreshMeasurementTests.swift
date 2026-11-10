import Foundation
import Testing
@testable import TBDCore

/// TC-MOD-008: 주사율 측정 계산.
@Suite("TC-MOD-008 주사율 측정 계산")
struct RefreshMeasurementTests {
    @Test func 일정한_간격의_표본() {
        let interval = 1.0 / 120
        let timestamps = (0..<241).map { Double($0) * interval + 1000 }
        let m = RefreshMeasurement.compute(nominalHz: 120, timestamps: timestamps, reportedDurations: [Double](repeating: interval, count: 241))
        #expect(abs((m.measuredHz ?? 0) - 120) < 0.001)
        #expect(abs((m.reportedHz ?? 0) - 120) < 0.001)
        #expect(m.sampleCount == 241)
        #expect(abs(m.durationSeconds - 2) < 0.001)
        #expect(abs((m.minIntervalMs ?? 0) - 8.333) < 0.01)
        #expect(m.summary == "측정 120.00 Hz (보고 120.00 Hz, 공칭 120 Hz, 표본 241개)")
    }

    @Test func 간격이_고르지_않은_표본은_평균과_최소_최대_보고() {
        // 60 Hz 화면에서 한 번 건너뛴 경우.
        let timestamps = [0.0, 1.0 / 60, 2.0 / 60, 4.0 / 60, 5.0 / 60]
        let m = RefreshMeasurement.compute(nominalHz: 60, timestamps: timestamps, reportedDurations: [1.0 / 60, 1.0 / 60, 1.0 / 30, 1.0 / 60, 1.0 / 60])
        #expect(abs((m.measuredHz ?? 0) - 48) < 0.001)
        #expect(abs((m.reportedHz ?? 0) - 60) < 0.001)
        #expect(abs((m.maxIntervalMs ?? 0) - 33.333) < 0.01)
        #expect(abs((m.minIntervalMs ?? 0) - 16.667) < 0.01)
    }

    @Test func 표본이_부족하면_측정_불가() {
        let none = RefreshMeasurement.compute(nominalHz: 60, timestamps: [], reportedDurations: [])
        #expect(none.measuredHz == nil && none.reportedHz == nil)
        #expect(none.summary == "측정 불가 (표본 0개)")
        let one = RefreshMeasurement.compute(nominalHz: 60, timestamps: [5], reportedDurations: [0])
        #expect(one.measuredHz == nil && one.reportedHz == nil)
        #expect(one.sampleCount == 1)
    }
}
