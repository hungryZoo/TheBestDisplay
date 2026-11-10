import Foundation
import Testing
@testable import TBDCore

/// TC-BRT-010: 백라이트 휘도 해석.
@Suite("TC-BRT-010 백라이트 휘도 해석")
struct BacklightLuminanceTests {
    /// 내장 XDR 패널 프레임버퍼 노드 실측 값 (T52, 밝기 61%).
    static let measured: [String: Any] = [
        "IOMFBBrightnessLevel": 11_133_455,
        "BLNitsCap": 26_227_508,
        "IOMFBIndicatorNitsCap": 104_857_600,
        "Brightness_Scale": 65760,
    ]

    @Test func 실측_속성_해석() throws {
        let luminance = try #require(BacklightLuminance(framebufferProperties: Self.measured))
        #expect(luminance == BacklightLuminance(currentMilliNits: 169_883, capMilliNits: 400_200, peakMilliNits: 1_600_000))
        #expect(luminance.summary == "170 cd/m² (백라이트 상한 400 cd/m², 패널 최대 1600 cd/m²)")
    }

    /// 밝기 단계별 실측 값 (T52): 10%, 25%, 50%, 75%, 100%.
    @Test func 밝기_단계별_실측_값은_단조_증가() {
        let levels = [100_099, 544_815, 9_175_040, 14_729_231, 26_227_508]
        let nits = levels.compactMap { BacklightLuminance.milliNits(fixedPoint: $0) }
        #expect(nits == [1527, 8313, 140_000, 224_750, 400_200])
        #expect(nits == nits.sorted())
    }

    @Test func 밝기_0은_휘도_0() throws {
        let luminance = try #require(BacklightLuminance(framebufferProperties: ["IOMFBBrightnessLevel": 0, "BLNitsCap": 26_227_508]))
        #expect(luminance.currentMilliNits == 0)
        #expect(luminance.summary == "0.0 cd/m² (백라이트 상한 400 cd/m²)")
    }

    @Test func 현재_휘도_속성이_없으면_nil() {
        #expect(BacklightLuminance(framebufferProperties: [:]) == nil)
        #expect(BacklightLuminance(framebufferProperties: ["BLNitsCap": 26_227_508]) == nil)
        #expect(BacklightLuminance(framebufferProperties: ["IOMFBBrightnessLevel": "문자열"]) == nil)
        #expect(BacklightLuminance(framebufferProperties: ["IOMFBBrightnessLevel": -1]) == nil)
    }

    @Test func 상한과_최대가_없으면_현재_값만_표기() throws {
        let luminance = try #require(BacklightLuminance(framebufferProperties: ["IOMFBBrightnessLevel": 3_276_800, "BLNitsCap": 0]))
        #expect(luminance.capMilliNits == nil)
        #expect(luminance.summary == "50.0 cd/m²")
    }

    @Test func 표기_자릿수() {
        #expect(BacklightLuminance.format(1.527) == "1.5")
        #expect(BacklightLuminance.format(99.94) == "99.9")
        #expect(BacklightLuminance.format(100) == "100")
        #expect(BacklightLuminance.format(1600) == "1600")
    }

    @Test func JSON_왕복() throws {
        let value = BacklightLuminance(currentMilliNits: 169_883, capMilliNits: 400_200, peakMilliNits: 1_600_000)
        let decoded = try JSONDecoder().decode(BacklightLuminance.self, from: JSONEncoder().encode(value))
        #expect(decoded == value)
    }
}
