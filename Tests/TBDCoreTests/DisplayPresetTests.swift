import Foundation
import Testing
@testable import TBDCore

/// TC-CLR-003: 디스플레이 프리셋 지정 해석.
@Suite("TC-CLR-003 프리셋 지정 해석")
struct DisplayPresetTests {
    static let presets = [
        DisplayPreset(index: 0, name: "Apple XDR Display (P3-1600 nits)", detail: "", group: 0, isActive: true, isDefault: true, isValid: true, isWritable: false),
        DisplayPreset(index: 1, name: "Apple Display (P3-600 nits)", detail: "", group: 0, isActive: false, isDefault: false, isValid: true, isWritable: false),
        DisplayPreset(index: 10, name: "Internet & Web (sRGB)", detail: "", group: 0, isActive: false, isDefault: false, isValid: true, isWritable: false),
    ]

    @Test func 번호와_이름으로_찾기() {
        #expect(DisplayPreset.resolve("1", in: Self.presets)?.index == 1)
        #expect(DisplayPreset.resolve("10", in: Self.presets)?.name == "Internet & Web (sRGB)")
        #expect(DisplayPreset.resolve("srgb", in: Self.presets)?.index == 10)
        #expect(DisplayPreset.resolve("P3-600", in: Self.presets)?.index == 1)
        #expect(DisplayPreset.resolve("apple display (p3-600 nits)", in: Self.presets)?.index == 1)
    }

    @Test func 없는_번호와_여러_개와_맞는_이름은_거부() {
        #expect(DisplayPreset.resolve("99", in: Self.presets) == nil)
        #expect(DisplayPreset.resolve("Apple", in: Self.presets) == nil)
        #expect(DisplayPreset.resolve("없는 이름", in: Self.presets) == nil)
        #expect(DisplayPreset.resolve("0", in: []) == nil)
    }
}
