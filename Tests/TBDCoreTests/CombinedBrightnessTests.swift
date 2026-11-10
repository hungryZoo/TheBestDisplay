import Foundation
import Testing
@testable import TBDCore

/// TC-BRT-012: 결합 밝기 분해와 역산.
@Suite("TC-BRT-012 결합 밝기 계산")
struct CombinedBrightnessTests {
    static func close(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 1e-9 }

    @Test func 위쪽_구간은_하드웨어_밝기() {
        let full = CombinedBrightness.levels(for: 1, hardwareFloor: 0)
        #expect(full == .init(hardware: 1, dimming: 1))
        let mid = CombinedBrightness.levels(for: 0.625, hardwareFloor: 0)
        #expect(Self.close(mid.hardware, 0.5) && mid.dimming == 1)
        // 경계에서는 하드웨어 하한, 디밍 없음.
        let edge = CombinedBrightness.levels(for: 0.25, hardwareFloor: 0)
        #expect(edge == .init(hardware: 0, dimming: 1))
    }

    @Test func 아래쪽_구간은_하드웨어_하한과_디밍() {
        let zero = CombinedBrightness.levels(for: 0, hardwareFloor: 0)
        #expect(zero.hardware == 0 && Self.close(zero.dimming, 0.1))
        let half = CombinedBrightness.levels(for: 0.125, hardwareFloor: 0)
        #expect(half.hardware == 0 && Self.close(half.dimming, 0.55))
    }

    @Test func 시스템_밝기_제어는_하한을_0보다_크게_유지() {
        let floor = CombinedBrightness.hardwareFloor(for: .native)
        #expect(floor == 0.0625)
        #expect(CombinedBrightness.hardwareFloor(for: .ddc) == 0)
        #expect(CombinedBrightness.levels(for: 0, hardwareFloor: floor).hardware == 0.0625)
        #expect(CombinedBrightness.levels(for: 0.2, hardwareFloor: floor).hardware == 0.0625)
        let mid = CombinedBrightness.levels(for: 0.625, hardwareFloor: floor)
        #expect(Self.close(mid.hardware, 0.0625 + 0.5 * 0.9375))
        #expect(CombinedBrightness.levels(for: 1, hardwareFloor: floor).hardware == 1)
    }

    @Test func 범위_밖_값은_잘림() {
        #expect(CombinedBrightness.levels(for: 1.7, hardwareFloor: 0) == CombinedBrightness.levels(for: 1, hardwareFloor: 0))
        #expect(CombinedBrightness.levels(for: -0.3, hardwareFloor: 0) == CombinedBrightness.levels(for: 0, hardwareFloor: 0))
    }

    @Test func 분해와_역산_왕복() {
        for floor in [0, 0.0625] {
            for step in 0...40 {
                let value = Double(step) / 40
                let levels = CombinedBrightness.levels(for: value, hardwareFloor: floor)
                let back = CombinedBrightness.combined(hardware: levels.hardware, dimming: levels.dimming, hardwareFloor: floor)
                #expect(abs(back - value) < 1e-6, "값 \(value), 하한 \(floor)")
            }
        }
    }

    @Test func 결합_값은_밝기_순서_유지() {
        // 결합 값이 커지면 하드웨어 밝기와 디밍의 곱이 줄지 않음.
        var previous = -1.0
        for step in 0...100 {
            let levels = CombinedBrightness.levels(for: Double(step) / 100, hardwareFloor: 0.0625)
            let product = levels.hardware * levels.dimming
            #expect(product >= previous - 1e-12)
            previous = product
        }
    }

    @Test func 하한_아래의_하드웨어_값_역산은_경계값() {
        #expect(CombinedBrightness.combined(hardware: 0, dimming: 1, hardwareFloor: 0.0625) == 0.25)
        #expect(CombinedBrightness.combined(hardware: 1, dimming: 1, hardwareFloor: 0.0625) == 1)
    }

    @Test func 입력_해석과_표기() {
        #expect(CombinedBrightness.parsePercent("10") == 0.1)
        #expect(CombinedBrightness.parsePercent("100") == 1)
        #expect(CombinedBrightness.parsePercent("101") == nil)
        #expect(CombinedBrightness.parsePercent("-1") == nil)
        #expect(CombinedBrightness.parsePercent("abc") == nil)
        #expect(CombinedBrightness.describe(.init(hardware: 0.0625, dimming: 0.55)) == "하드웨어 6%, 디밍 55%")
        #expect(CombinedBrightness.describe(.init(hardware: 0.5, dimming: 1)) == "하드웨어 50%, 디밍 없음")
    }
}
