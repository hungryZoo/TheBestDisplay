import Foundation
import Testing
@testable import TBDCore

enum SignalFixture {
    /// 실험 기기의 프레임버퍼 노드 속성 (내장, LG TV, 빈 외장 노드).
    static func framebuffers() throws -> [[String: Any]] {
        let data = try Fixture.data("framebuffers_m5_lg_tv.plist")
        return try #require(try PropertyListSerialization.propertyList(from: data, format: nil) as? [[String: Any]])
    }

    static func lgTV(currentColorID: Int? = 122) throws -> SignalInfo {
        let node = try #require(try framebuffers().first { ($0["DisplayWidth"] as? Int) == 3840 })
        return SignalInfo(
            displayID: 2,
            timings: SignalDecoder.timingElements(node["TimingElements"]),
            sinkColorElements: SignalDecoder.colorElements(node["ColorElements"]),
            currentTimingID: node["DPTimingModeId"] as? Int,
            currentColorID: currentColorID,
            linkData: nil,
            transport: (node["Transport"] as? [String: Any])?["Downstream"] as? String
        )
    }
}

/// TC-COL-001: 타이밍 요소와 색 요소 해석.
@Suite("TC-COL-001 타이밍과 색 요소 해석")
struct SignalDecoderTests {
    @Test func LG_TV_요소_수와_현재_타이밍() throws {
        let info = try SignalFixture.lgTV()
        #expect(info.timings.count == 58)
        #expect(info.sinkColorElements.count == 37)
        #expect(info.transport == "DP")
        let timing = try #require(info.currentTiming)
        #expect(timing.id == 96)
        #expect((timing.hActive, timing.vActive) == (3840, 2160))
        #expect((timing.hTotal, timing.vTotal) == (3968, 2250))
        #expect(timing.refreshRate == 120)
        #expect(timing.pixelClockHz == 1_071_360_000)
        #expect(timing.colorModes.count == 17)
        #expect(timing.isPreferred)
        #expect(timing.label == "3840 x 2160, 120 Hz")
        #expect((timing.hFrontPorch, timing.hSyncWidth, timing.hBackPorch) == (32, 24, 72))
        #expect((timing.vFrontPorch, timing.vSyncWidth, timing.vBackPorch) == (76, 8, 6))
    }

    @Test func LG_TV_색_요소_122() throws {
        let info = try SignalFixture.lgTV()
        let color = try #require(info.currentColor)
        #expect(color.id == 122)
        #expect(color.pixelEncoding == .ycbcr422)
        #expect(color.bitsPerComponent == 12)
        #expect(color.eotf == .pq)
        #expect(color.dynamicRange == .limited)
        #expect(Colorimetry.name(color.colorimetry) == "BT.2020 (YCbCr)")
        #expect(color.label == "YCbCr 4:2:2, 12 bpc, Limited, PQ (HDR10)")
        #expect(color.bitsPerPixel == 24)
        #expect(!color.isVirtual)
    }

    @Test func 현재_타이밍의_선택_가능_색_모드는_가상_형식_제외() throws {
        let info = try SignalFixture.lgTV()
        let selectable = info.selectableColorModes
        #expect(selectable.count == 15)
        #expect(selectable.allSatisfy { !$0.isVirtual })
        // 4K 120 Hz에서 RGB는 8 bpc SDR만 제공.
        let rgb = selectable.filter { $0.pixelEncoding.isRGB }
        #expect(rgb.map(\.id).sorted() == [100, 101])
        #expect(rgb.allSatisfy { $0.bitsPerComponent == 8 && $0.eotf == .sdr })
        // HDR 색 모드는 전부 YCbCr 4:2:2 계열.
        #expect(selectable.filter { $0.eotf.isHDR }.allSatisfy { $0.pixelEncoding.componentsPerPixel == 2 })
    }

    @Test func 내장_패널과_빈_노드() throws {
        let nodes = try SignalFixture.framebuffers()
        let builtin = try #require(nodes.first { ($0["DisplayWidth"] as? Int) == 3024 })
        let timings = SignalDecoder.timingElements(builtin["TimingElements"])
        #expect(timings.count == 6)
        let current = try #require(timings.first { $0.id == builtin["DPTimingModeId"] as? Int })
        #expect((current.hActive, current.vActive) == (3024, 1964))
        // 내장 패널의 정밀 주사율은 120.0005 Hz.
        #expect(abs(current.refreshRate - 120) < 0.001)
        let empty = try #require(nodes.first { $0["DisplayWidth"] == nil })
        #expect(SignalDecoder.timingElements(empty["TimingElements"]).isEmpty)
    }

    @Test func 잘못된_입력은_빈_결과() {
        #expect(SignalDecoder.timingElements(nil).isEmpty)
        #expect(SignalDecoder.timingElements("문자열").isEmpty)
        #expect(SignalDecoder.timingElements([["ID": 1]]).isEmpty)
        #expect(SignalDecoder.colorElements([["ID": 1, "Depth": 8]]).isEmpty)
        #expect(SignalDecoder.colorElement(["ID": 5, "PixelEncoding": 99, "Depth": 8])?.pixelEncoding.name == "알 수 없음 (99)")
    }

    @Test func 열거값_이름과_픽셀당_비트_계수() {
        #expect(PixelEncoding(rawValue: 0).name == "RGB 4:4:4")
        #expect(PixelEncoding(rawValue: 1).name == "YCbCr 4:2:0")
        #expect(PixelEncoding(rawValue: 2).name == "YCbCr 4:2:2")
        #expect(PixelEncoding(rawValue: 3).name == "YCbCr 4:4:4")
        #expect(PixelEncoding(rawValue: 6).name == "YCbCr 4:2:2 (DP 터널링)")
        #expect(PixelEncoding.rgb444.componentsPerPixel == 3)
        #expect(PixelEncoding.ycbcr444.componentsPerPixel == 3)
        #expect(PixelEncoding.ycbcr422.componentsPerPixel == 2)
        #expect(PixelEncoding.ycbcr420.componentsPerPixel == 1.5)
        #expect(EOTF(rawValue: 2).name == "PQ (HDR10)")
        #expect(EOTF(rawValue: 3).name == "HLG")
        #expect(DynamicRange(rawValue: 1).name == "Limited")
        #expect(Colorimetry.name(16) == "기본 RGB")
        #expect(Colorimetry.name(99) == "알 수 없음 (99)")
    }

    @Test func 색_모드_서술로_찾기와_명령행_지정() throws {
        let info = try SignalFixture.lgTV()
        let modes = info.selectableColorModes
        let current = try #require(info.currentColor)
        #expect(current.descriptor.find(in: modes)?.id == 122)
        #expect(ColorDescriptor(pixelEncoding: .rgb444, bitsPerComponent: 8, eotf: .sdr, dynamicRange: .full).find(in: modes)?.id == 100)
        #expect(ColorDescriptor(pixelEncoding: .rgb444, bitsPerComponent: 10, eotf: .sdr, dynamicRange: .full).find(in: modes) == nil)

        #expect(ColorSpec.parse("id:100") == .id(100))
        #expect(ColorSpec.parse("rgb:8:full:sdr") == .partial(encoding: .rgb444, bitsPerComponent: 8, dynamicRange: .full, eotf: .sdr))
        #expect(ColorSpec.parse("ycbcr422:12:pq") == .partial(encoding: .ycbcr422, bitsPerComponent: 12, dynamicRange: nil, eotf: .pq))
        for bad in ["", "cmyk", "rgb:9", "rgb:wide", "id:x"] { #expect(ColorSpec.parse(bad) == nil, "\(bad)") }

        #expect(ColorSpec.parse("rgb")!.resolve(in: modes, current: current)?.pixelEncoding == .rgb444)
        #expect(ColorSpec.parse("rgb:limited")!.resolve(in: modes, current: current)?.id == 101)
        // 생략 항목은 현재 값(PQ, 12 bpc) 우선.
        #expect(ColorSpec.parse("ycbcr422")!.resolve(in: modes, current: current)?.id == 122)
        #expect(ColorSpec.parse("ycbcr422:10")!.resolve(in: modes, current: current)?.id == 117)
        #expect(ColorSpec.parse("ycbcr422:hlg")!.resolve(in: modes, current: current)?.id == 133)
        #expect(ColorSpec.parse("rgb:10")!.resolve(in: modes, current: current) == nil)
        #expect(ColorSpec.id(999).resolve(in: modes, current: current) == nil)
    }
}

/// TC-COL-003: 링크 데이터 구조체 해석.
@Suite("TC-COL-003 링크 데이터 해석")
struct VideoLinkDataTests {
    @Test func 실측_구조체_해석() throws {
        let bytes = [UInt8](try Fixture.data("linkdata_4k120_422_12bit_pq.bin"))
        #expect(bytes.count == VideoLinkData.byteCount)
        let link = try #require(VideoLinkData.decode(bytes))
        #expect(link.bitsPerComponent == 12)
        #expect(link.pixelEncoding == .ycbcr422)
        #expect(link.dynamicRange == .limited)
        #expect(link.eotf == .pq)
        #expect(Colorimetry.name(link.colorimetry) == "BT.2020 (YCbCr)")
        #expect((link.hActive, link.vActive) == (3840, 2160))
        #expect((link.hTotal, link.vTotal) == (3968, 2250))
        #expect((link.hSyncWidth, link.hBackPorch, link.hFrontPorch) == (24, 72, 32))
        #expect((link.vSyncWidth, link.vBackPorch, link.vFrontPorch) == (8, 6, 76))
        #expect(link.refreshRate == 120)
        #expect(link.pixelClockHz == 1_071_360_000)
        #expect(link.bitsPerPixel == 24)
        #expect(link.colorLabel == "YCbCr 4:2:2, 12 bpc, Limited, PQ (HDR10)")
        // 검산: 총 픽셀 x 주사율 = 픽셀 클록.
        #expect(Double(link.hTotal * link.vTotal) * link.refreshRate == link.pixelClockHz)
    }

    @Test func 길이_부족과_빈_구조체는_해석_거부() {
        #expect(VideoLinkData.decode([UInt8](repeating: 0, count: 0x10F)) == nil)
        #expect(VideoLinkData.decode([UInt8](repeating: 0, count: 0x110)) == nil)
    }
}

/// TC-COL-005: DSC 판정.
@Suite("TC-COL-005 DSC 판정")
struct DSCAssessmentTests {
    @Test func 실측_픽스처는_싱크_DSC_미지원() throws {
        let info = try SignalFixture.lgTV()
        let dsc = DSCAssessment.assess(signal: info, edidSupportsDSC: nil, sourceSupportsDSC: true)
        #expect(dsc.sinkSupportsDSC == false)
        #expect(dsc.sourceSupportsDSC == true)
        #expect(dsc.isActive == false)
        #expect(dsc.dscRequiredModeCount == 0)
        #expect(dsc.dscFreeModeCount == 15)
        #expect(dsc.summary == "현재 모드는 DSC 미사용 (싱크가 DSC 미지원)")
    }

    /// DSC 지원 싱크의 합성 자료: 4K 144 Hz에서 RGB 10 bpc는 DSC 필요, RGB 8 bpc는 불필요.
    func synthetic(currentColorID: Int?) -> SignalInfo {
        let rgb8 = ColorElement(id: 10, pixelEncoding: .rgb444, bitsPerComponent: 8, eotf: .sdr, dynamicRange: .full, colorimetry: 16, supportsDSC: true)
        let rgb10 = ColorElement(id: 11, pixelEncoding: .rgb444, bitsPerComponent: 10, eotf: .sdr, dynamicRange: .full, colorimetry: 16, supportsDSC: true)
        let virtualElement = ColorElement(id: 1, pixelEncoding: .rgb444, bitsPerComponent: 8, eotf: .sdr, dynamicRange: .full, colorimetry: 10, isVirtual: true)
        let timing = TimingElement(
            id: 5, hActive: 3840, hTotal: 4000, hFrontPorch: 48, hSyncWidth: 32, hBackPorch: 80,
            vActive: 2160, vTotal: 2222, vFrontPorch: 3, vSyncWidth: 5, vBackPorch: 54,
            refreshRate: 144, isInterlaced: false, isPreferred: true, isVirtual: false,
            colorModes: [rgb8, rgb10, virtualElement], dscRequiredColorElementIDs: [11], unsafeColorElementIDs: [],
            minVariableRefreshRate: 48, maxVariableRefreshRate: 144
        )
        return SignalInfo(displayID: 9, timings: [timing], sinkColorElements: [rgb8, rgb10], currentTimingID: 5, currentColorID: currentColorID, linkData: nil, transport: "DP")
    }

    @Test func 합성_픽스처에서_DSC_필요_모드_식별() {
        let active = DSCAssessment.assess(signal: synthetic(currentColorID: 11), edidSupportsDSC: nil, sourceSupportsDSC: true)
        #expect(active.sinkSupportsDSC == true)
        #expect(active.isActive == true)
        #expect(active.dscRequiredModeCount == 1)
        #expect(active.dscFreeModeCount == 1)
        #expect(active.summary == "현재 모드는 DSC 압축 사용")

        let inactive = DSCAssessment.assess(signal: synthetic(currentColorID: 10), edidSupportsDSC: nil, sourceSupportsDSC: true)
        #expect(inactive.isActive == false)
        #expect(inactive.summary == "현재 모드는 DSC 미사용 (싱크는 DSC 지원)")
        #expect(synthetic(currentColorID: 10).currentTiming?.requiresDSC(11) == true)
    }

    @Test func 자료가_없으면_미확인() {
        let empty = SignalInfo(displayID: 1, timings: [], sinkColorElements: [], currentTimingID: nil, currentColorID: nil, linkData: nil, transport: nil)
        let dsc = DSCAssessment.assess(signal: empty, edidSupportsDSC: nil, sourceSupportsDSC: nil)
        #expect(dsc.sinkSupportsDSC == nil)
        #expect(dsc.isActive == nil)
        #expect(dsc.summary == "DSC 사용 여부 확인 불가")
        // EDID 선언만 있는 경우 그 값을 사용.
        #expect(DSCAssessment.assess(signal: empty, edidSupportsDSC: true, sourceSupportsDSC: nil).sinkSupportsDSC == true)
    }
}

@Suite("TC-HDR-001 HDR 상태 모델")
struct HDRStatusTests {
    func status(supported: Bool, enabled: Bool, maxEDR: Double? = 10) -> HDRStatus {
        HDRStatus(displayID: 2, isSupported: supported, isEnabled: enabled, currentEDRHeadroom: 1, maxEDRHeadroom: maxEDR, supportedEOTFs: ["PQ (HDR10)"], maxLuminance: nil)
    }

    @Test func 상태_문구() {
        #expect(status(supported: true, enabled: true).stateLabel == "켜짐")
        #expect(status(supported: true, enabled: false).stateLabel == "꺼짐")
        #expect(status(supported: false, enabled: false, maxEDR: 16).stateLabel == "전환 항목 없음 (EDR 상시 지원)")
        #expect(status(supported: false, enabled: false, maxEDR: 1).stateLabel == "미지원")
        #expect(status(supported: false, enabled: false, maxEDR: nil).stateLabel == "미지원")
    }

    @Test func 전달_함수와_HDR_상태_불일치_판정() {
        #expect(status(supported: true, enabled: true).isMismatched(with: .sdr))
        #expect(!status(supported: true, enabled: true).isMismatched(with: .pq))
        #expect(status(supported: true, enabled: false).isMismatched(with: .hlg))
        #expect(!status(supported: true, enabled: false).isMismatched(with: .sdr))
        #expect(!status(supported: false, enabled: false).isMismatched(with: .sdr))
    }

    @Test func 켜기_끄기_값_해석() {
        for text in ["on", "ON", "1", "true", "yes"] { #expect(Toggle.parse(text) == true) }
        for text in ["off", "Off", "0", "false", "no"] { #expect(Toggle.parse(text) == false) }
        #expect(Toggle.parse("toggle") == nil)
    }
}
