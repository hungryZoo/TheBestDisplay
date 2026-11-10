import Foundation
import Testing
@testable import TBDCore

/// TC-MOD-015: 프레임버퍼 한도 해석.
@Suite("TC-MOD-015 프레임버퍼 한도 해석")
struct FramebufferLimitsTests {
    /// 실측 (T59): LG TV가 연결된 외장 프레임버퍼 노드.
    static let external: [String: Any] = [
        "IOMFBMaxSrcPixels": [
            "MaxSrcRectHeightForPipe": [4320, 4320, 4320, 4320], "MaxSrcRectWidthForPipe": [6144, 7680, 7680, 7680],
            "MaxSrcBufferHeight": 16384, "MaxSrcBufferWidth": 16384, "MaxVideoSrcDownscalingWidth": 0, "PixelClock": 0,
        ] as [String: Any],
        "IOMFBScalingLimits": ["YUVLayer_MaxScale": 4, "YUVLayer_MinScaleFraction": 2, "RGBLayer_MinScaleFraction": 2, "RGBLayer_MaxScale": 4],
    ]
    /// 실측 (T59): 내장 패널 프레임버퍼 노드.
    static let builtin: [String: Any] = [
        "IOMFBMaxSrcPixels": [
            "MaxSrcRectHeightForPipe": [4320, 4320, 4320, 4320], "MaxSrcRectWidthForPipe": [5120, 0, 0, 0],
            "MaxSrcBufferHeight": 16384, "MaxSrcBufferWidth": 16384, "MaxVideoSrcDownscalingWidth": 5120,
        ] as [String: Any],
        "IOMFBScalingLimits": ["RGBLayer_MinScaleFraction": 2, "RGBLayer_MaxScale": 4],
    ]

    @Test func 외장_실측_해석() throws {
        let limits = try #require(FramebufferLimits(properties: Self.external))
        #expect(limits.maxSourceWidths == [6144, 7680, 7680, 7680])
        #expect(limits.primarySourceWidth == 6144 && limits.primarySourceHeight == 4320)
        #expect(limits.largestSourceWidth == 7680)
        #expect(limits.maxBufferWidth == 16384 && limits.maxBufferHeight == 16384)
        #expect(limits.maxVideoDownscalingWidth == nil)
        #expect(limits.summary == "소스 최대 6144 x 4320 (파이프별 폭 6144, 7680, 7680, 7680), 버퍼 최대 16384 x 16384, 스케일 1/2-4배")
    }

    @Test func 내장_실측_해석() throws {
        let limits = try #require(FramebufferLimits(properties: Self.builtin))
        #expect(limits.primarySourceWidth == 5120)
        #expect(limits.summary == "소스 최대 5120 x 4320, 버퍼 최대 16384 x 16384, 스케일 1/2-4배, 영상 축소 최대 폭 5120")
    }

    @Test func 한도_판정과_안내() throws {
        let limits = try #require(FramebufferLimits(properties: Self.external))
        // LG TV 모드 목록의 최대 백킹 6016 x 3384와 T51에서 등록한 5600 x 3150은 한도 안.
        #expect(limits.allows(pixelWidth: 6016, pixelHeight: 3384) == true)
        #expect(limits.allows(pixelWidth: 5600, pixelHeight: 3150) == true)
        #expect(limits.excessNotice(pixelWidth: 5600, pixelHeight: 3150) == nil)
        // 3200 x 1800 HiDPI의 백킹 6400 x 3600은 폭 초과.
        #expect(limits.allows(pixelWidth: 6400, pixelHeight: 3600) == false)
        #expect(limits.excessNotice(pixelWidth: 6400, pixelHeight: 3600) == "백킹 6400 x 3600은 프레임버퍼 소스 한도 6144 x 4320 초과. 등록해도 모드 목록에 나오지 않을 수 있음")
        #expect(limits.allows(pixelWidth: 6000, pixelHeight: 4400) == false)
    }

    @Test func 속성이_없으면_nil() {
        #expect(FramebufferLimits(properties: [:]) == nil)
        #expect(FramebufferLimits(properties: ["IOMFBScalingLimits": ["RGBLayer_MaxScale": 4]]) == nil)
        #expect(FramebufferLimits(properties: ["IOMFBMaxSrcPixels": ["MaxSrcRectWidthForPipe": [0, 0], "MaxSrcRectHeightForPipe": [0, 0]] as [String: Any]]) == nil)
    }

    @Test func 한도를_모르면_판정_없음() {
        let limits = FramebufferLimits(maxSourceWidths: [0, 7680], maxSourceHeights: [0, 4320])
        #expect(limits.allows(pixelWidth: 100, pixelHeight: 100) == nil)
        #expect(limits.excessNotice(pixelWidth: 99999, pixelHeight: 99999) == nil)
        #expect(limits.summary == "")
    }
}
