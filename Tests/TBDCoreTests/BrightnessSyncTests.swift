import Foundation
import Testing
@testable import TBDCore

/// TC-BRT-006: 밝기 동기화 계산.
@Suite("TC-BRT-006 밝기 동기화 계산")
struct BrightnessSyncTests {
    @Test func 대상_방식별_범위_변환() {
        #expect(BrightnessSync.targetLevel(source: 0.5, method: .native) == 0.5)
        #expect(BrightnessSync.targetLevel(source: 0.5, method: .ddc) == 0.5)
        #expect(BrightnessSync.targetLevel(source: 0.5, method: .software) == 0.5)
        // 소프트웨어 디밍은 하한 10%.
        #expect(BrightnessSync.targetLevel(source: 0.02, method: .software) == 0.1)
        #expect(BrightnessSync.targetLevel(source: 0.02, method: .native) == 0.02)
        // 범위 밖의 값은 잘림.
        #expect(BrightnessSync.targetLevel(source: 1.4, method: .ddc) == 1)
        #expect(BrightnessSync.targetLevel(source: -1, method: .native) == 0)
    }

    @Test func 임계값_이상_바뀔_때만_적용() {
        #expect(BrightnessSync.shouldApply(new: 0.5, last: nil))
        #expect(!BrightnessSync.shouldApply(new: 0.505, last: 0.5))
        #expect(BrightnessSync.shouldApply(new: 0.51, last: 0.5))
        #expect(BrightnessSync.shouldApply(new: 0.3, last: 0.5))
        #expect(!BrightnessSync.shouldApply(new: 0.5, last: 0.5))
    }
}
