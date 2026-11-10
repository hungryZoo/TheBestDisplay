import Foundation
import Testing
@testable import TBDCore

/// TC-CLR-005: Night Shift 연동 색온도 계산.
@Suite("TC-CLR-005 Night Shift 연동 색온도")
struct NightShiftEmulationTests {
    @Test func 강도에_따른_색온도() {
        #expect(NightShiftEmulation.kelvin(isEnabled: false, strength: 1) == 6500)
        #expect(NightShiftEmulation.kelvin(isEnabled: true, strength: 0) == 5200)
        #expect(NightShiftEmulation.kelvin(isEnabled: true, strength: 1) == 2800)
        #expect(NightShiftEmulation.kelvin(isEnabled: true, strength: 0.5) == 4000)
        // 강도를 모르면 중간값, 범위 밖은 잘림.
        #expect(NightShiftEmulation.kelvin(isEnabled: true, strength: nil) == 4000)
        #expect(NightShiftEmulation.kelvin(isEnabled: true, strength: 3) == 2800)
    }

    @Test func 조정_값_반영과_재적용_생략() {
        var current = ColorAdjustment()
        current.dimming = 0.8
        let warm = NightShiftEmulation.adjusted(current, isEnabled: true, strength: 0.5)
        #expect(warm?.temperature == 4000)
        #expect(warm?.dimming == 0.8)
        // 이미 같은 값이면 nil.
        #expect(NightShiftEmulation.adjusted(warm!, isEnabled: true, strength: 0.5) == nil)
        // 꺼지면 6500 K로 복귀.
        #expect(NightShiftEmulation.adjusted(warm!, isEnabled: false, strength: 0.5)?.temperature == 6500)
        #expect(NightShiftEmulation.adjusted(ColorAdjustment(), isEnabled: false, strength: nil) == nil)
        // 따뜻한 색온도는 파란 채널을 낮춤.
        let table = GammaTable.make(warm!)
        #expect((table.blue.last ?? 1) < (table.red.last ?? 0))
    }
}
