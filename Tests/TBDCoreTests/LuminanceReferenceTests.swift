import Foundation
import Testing
@testable import TBDCore

/// TC-BRT-014: 최대 휘도 기준값과 휘도 기준 동기화 계산.
@Suite("TC-BRT-014 휘도 기준값과 휘도 기준 변환")
struct LuminanceReferenceTests {
    static func store() -> LuminanceReferenceStore {
        LuminanceReferenceStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("tbd-luminance-\(UUID().uuidString).json"))
    }

    static let tv = DisplayIdentity(displayID: 2, uuid: nil, vendorID: 0x1E6D, productID: 0xC0C8, serialNumber: 16843009, name: "LG TV", isBuiltin: false)
    static let other = DisplayIdentity(displayID: 3, uuid: nil, vendorID: 0x10AC, productID: 0x1234, serialNumber: 1, name: "모니터", isBuiltin: false)

    @Test func 지정값_저장과_해제() throws {
        let store = Self.store()
        #expect(store.userValue(for: Self.tv) == nil)
        try store.set(400, for: Self.tv)
        try store.set(250, for: Self.other)
        #expect(store.userValue(for: Self.tv) == 400)
        #expect(store.userValue(for: Self.other) == 250)
        try store.set(nil, for: Self.tv)
        #expect(store.userValue(for: Self.tv) == nil)
        #expect(store.userValue(for: Self.other) == 250)
    }

    @Test func 범위_밖_값은_거부() {
        let store = Self.store()
        #expect(throws: LuminanceReferenceError.self) { try store.set(5, for: Self.tv) }
        #expect(throws: LuminanceReferenceError.self) { try store.set(20000, for: Self.tv) }
        #expect(store.userValue(for: Self.tv) == nil)
    }

    @Test func 사용자_지정값이_EDID_값보다_우선() throws {
        let store = Self.store()
        #expect(store.reference(for: Self.tv, edidMaximum: nil) == nil)
        #expect(store.reference(for: Self.tv, edidMaximum: 0) == nil)
        #expect(store.reference(for: Self.tv, edidMaximum: 603) == LuminanceReference(maximumNits: 603, source: .edid))
        try store.set(400, for: Self.tv)
        #expect(store.reference(for: Self.tv, edidMaximum: 603) == LuminanceReference(maximumNits: 400, source: .user))
    }

    @Test func 추정_휘도와_표기() {
        let reference = LuminanceReference(maximumNits: 400, source: .user)
        #expect(reference.estimatedNits(level: 0.425) == 170)
        #expect(reference.estimatedNits(level: 1.5) == 400)
        #expect(reference.estimatedNits(level: -1) == 0)
        #expect(reference.summary(level: 0.425) == "추정 170 cd/m² (최대 400 cd/m², 사용자 지정)")
        #expect(LuminanceReference(maximumNits: 603, source: .edid).summary(level: 0.1) == "추정 60.3 cd/m² (최대 603 cd/m², EDID)")
    }

    @Test func 휘도_기준_변환() {
        // 원본 170 cd/m², 대상 최대 400 cd/m²: 대상 밝기 42.5%.
        #expect(BrightnessSync.normalizedLevel(sourceNits: 170, targetMaximumNits: 400, method: .ddc) == 0.425)
        // 원본이 대상의 최대보다 밝으면 최대 밝기.
        #expect(BrightnessSync.normalizedLevel(sourceNits: 500, targetMaximumNits: 400, method: .native) == 1)
        // 소프트웨어 디밍은 하한 10%.
        #expect(BrightnessSync.normalizedLevel(sourceNits: 8, targetMaximumNits: 400, method: .software) == 0.1)
        #expect(BrightnessSync.normalizedLevel(sourceNits: 8, targetMaximumNits: 400, method: .ddc) == 0.02)
        #expect(BrightnessSync.normalizedLevel(sourceNits: 100, targetMaximumNits: 0, method: .ddc) == nil)
        #expect(BrightnessSync.normalizedLevel(sourceNits: -1, targetMaximumNits: 400, method: .ddc) == nil)
    }

    @Test func 비율_기준과_휘도_기준의_차이() {
        // 원본 밝기 61%가 170 cd/m²인 패널과 최대 400 cd/m² 대상: 비율 기준 61%, 휘도 기준 42.5%.
        #expect(BrightnessSync.targetLevel(source: 0.61, method: .software) == 0.61)
        #expect(BrightnessSync.normalizedLevel(sourceNits: 170, targetMaximumNits: 400, method: .software) == 0.425)
    }
}
