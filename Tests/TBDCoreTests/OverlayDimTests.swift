import Foundation
import Testing
@testable import TBDCore

/// TC-BRT-008: 오버레이 디밍 계산.
@Suite("TC-BRT-008 오버레이 디밍 계산")
struct OverlayDimTests {
    @Test func 강도_범위와_남는_밝기() {
        #expect(OverlayDim.clamped(0.5) == 0.5)
        #expect(OverlayDim.clamped(1.5) == 0.9)
        #expect(OverlayDim.clamped(-1) == 0)
        #expect(abs(OverlayDim.remainingBrightness(0.3) - 0.7) < 1e-9)
        #expect(abs(OverlayDim.remainingBrightness(2) - 0.1) < 1e-9)
    }

    @Test func 백분율_해석() {
        #expect(OverlayDim.parsePercent("30") == 0.3)
        #expect(OverlayDim.parsePercent("0") == 0)
        #expect(OverlayDim.parsePercent("90") == 0.9)
        #expect(OverlayDim.parsePercent("95") == nil)
        #expect(OverlayDim.parsePercent("abc") == nil)
    }
}
