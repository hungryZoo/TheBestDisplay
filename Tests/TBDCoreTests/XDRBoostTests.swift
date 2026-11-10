import Foundation
import Testing
@testable import TBDCore

/// TC-BRT-004: XDR 밝기 업스케일의 전달 테이블 계산.
@Suite("TC-BRT-004 XDR 업스케일 테이블")
struct XDRBoostTests {
    @Test func 배율은_허용_범위로_잘림() {
        var adjustment = ColorAdjustment()
        adjustment.xdrBoost = 3
        #expect(adjustment.clamped().xdrBoost == 2)
        adjustment.xdrBoost = 0.5
        #expect(adjustment.clamped().xdrBoost == 1)
        adjustment.xdrBoost = 1.3
        #expect(!adjustment.isIdentity)
        #expect(ColorAdjustment().isIdentity)
    }

    @Test func 합성_테이블은_배율과_무관하게_0과_1_사이() {
        var adjustment = ColorAdjustment()
        adjustment.xdrBoost = 1.5
        let table = GammaTable.make(adjustment)
        #expect(table == GammaTable.linear())
        #expect(table.red.max() == 1)
    }

    @Test func 기준_테이블_합성_뒤_배율_적용은_1을_넘음() {
        var adjustment = ColorAdjustment()
        adjustment.xdrBoost = 1.3
        // 기준 테이블: 최댓값 0.9의 선형 보정.
        let baseline = GammaTable.linear().scaled(by: 0.9)
        let table = GammaTable.make(adjustment, size: 256).composed(over: baseline).scaled(by: adjustment.xdrBoost)
        #expect(abs(Double(table.red.last ?? 0) - 0.9 * 1.3) < 0.0001)
        #expect(table.red.first == 0)
        #expect(table.isMonotonic)
        // 디밍과 함께 쓰면 두 배율의 곱.
        adjustment.dimming = 0.5
        let dimmed = GammaTable.make(adjustment, size: 256).composed(over: .linear()).scaled(by: adjustment.xdrBoost)
        #expect(abs(Double(dimmed.red.last ?? 0) - 0.65) < 0.0001)
    }
}
