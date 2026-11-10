import ColorSync
import CoreGraphics
import Foundation
import Testing
import TBDCore
@testable import TBDPlatform

/// TC-CLR-010: 실제 디스플레이 프로파일로 만든 채도 조정 프로파일의 ColorSync 검사와 변환 결과. 디스플레이 설정은 바꾸지 않음.
@Suite("TC-CLR-010 채도 조정 프로파일 생성")
struct SaturationProfileGenerationTests {
    /// sRGB 색을 주어진 디스플레이 프로파일의 장치 값으로 변환.
    static func convert(_ rgb: [Float], to profile: ColorSyncProfile) throws -> [Float] {
        let source = try #require(ColorSyncProfileCreateWithName(kColorSyncSRGBProfile.takeUnretainedValue())?.takeRetainedValue())
        func step(_ profile: ColorSyncProfile, _ tag: CFString) -> [String: Any] {
            [
                kColorSyncProfile.takeUnretainedValue() as String: profile,
                kColorSyncRenderingIntent.takeUnretainedValue() as String: kColorSyncRenderingIntentRelative.takeUnretainedValue(),
                kColorSyncTransformTag.takeUnretainedValue() as String: tag,
            ]
        }
        let sequence = [step(source, kColorSyncTransformDeviceToPCS.takeUnretainedValue()), step(profile, kColorSyncTransformPCSToDevice.takeUnretainedValue())]
        let transform = try #require(ColorSyncTransformCreate(sequence as CFArray, nil)?.takeRetainedValue())
        var input = rgb
        var output = [Float](repeating: 0, count: 3)
        let layout = ColorSyncDataLayout(CGImageAlphaInfo.none.rawValue)
        let ok = ColorSyncTransformConvert(transform, 1, 1, &output, kColorSync32BitFloat, layout, 12, &input, kColorSync32BitFloat, layout, 12, nil)
        #expect(ok)
        return output
    }

    static func generated(_ saturation: Double, for display: DisplaySummary) throws -> (base: ColorSyncProfile, adjusted: ColorSyncProfile, url: URL) {
        let data = try #require(SaturationService.currentProfileData(display.id))
        let baseName = ColorProfileService.current(for: display.id)?.name ?? "기준"
        let adjusted = try SaturationAdjustment.adjustedProfile(try ICCProfile(data: data), saturation: saturation, baseName: baseName)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("tbd-saturation-test-\(UUID().uuidString).icc")
        try adjusted.serialized().write(to: url)
        let base = try #require(ColorSyncProfileCreate(data as CFData, nil)?.takeRetainedValue())
        let profile = try #require(ColorSyncProfileCreateWithURL(url as CFURL, nil)?.takeRetainedValue())
        return (base, profile, url)
    }

    @Test func 만든_프로파일은_ColorSync_검사_통과() throws {
        for display in DisplayCatalog.displays() {
            guard SaturationService.status(for: display, store: SaturationStore(fileURL: URL(fileURLWithPath: "/nonexistent/x.json"))).unavailableReason == nil else { continue }
            let (_, profile, url) = try Self.generated(0.8, for: display)
            defer { try? FileManager.default.removeItem(at: url) }
            #expect(SaturationService.verify(url) == nil)
            let name = ColorSyncProfileCopyDescriptionString(profile)?.takeRetainedValue() as String?
            #expect(name?.hasSuffix("(채도 80%)") == true)
        }
    }

    @Test func 채도를_낮추면_장치_값의_채널_차이가_줄고_무채색은_유지() throws {
        let display = try #require(DisplayCatalog.displays().first)
        try #require(SaturationService.status(for: display, store: SaturationStore(fileURL: URL(fileURLWithPath: "/nonexistent/x.json"))).unavailableReason == nil, "행렬 방식 프로파일 필요")
        let (base, low, lowURL) = try Self.generated(0.6, for: display)
        let (_, high, highURL) = try Self.generated(1.3, for: display)
        defer {
            try? FileManager.default.removeItem(at: lowURL)
            try? FileManager.default.removeItem(at: highURL)
        }
        func spread(_ v: [Float]) -> Float { (v.max() ?? 0) - (v.min() ?? 0) }
        // 채도가 중간인 색 (원색은 색 영역 경계에서 잘려 비교에 부적합).
        let color: [Float] = [0.7, 0.45, 0.4]
        let original = try Self.convert(color, to: base)
        let reduced = try Self.convert(color, to: low)
        let boosted = try Self.convert(color, to: high)
        #expect(spread(reduced) < spread(original))
        #expect(spread(boosted) > spread(original))
        // 무채색은 세 프로파일에서 같은 값.
        let gray: [Float] = [0.5, 0.5, 0.5]
        let grayOriginal = try Self.convert(gray, to: base)
        let grayReduced = try Self.convert(gray, to: low)
        for index in 0..<3 { #expect(abs(grayOriginal[index] - grayReduced[index]) < 0.003) }
    }
}
