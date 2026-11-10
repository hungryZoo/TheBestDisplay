import Foundation
import Testing
@testable import TBDCore

enum Fixture {
    static func data(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures"), "픽스처 없음: \(name)")
        return try Data(contentsOf: url)
    }

    static func lgTV() throws -> [UInt8] { [UInt8](try data("lg_tv_sscr2_dp.edid.bin")) }

    /// 체크섬을 맞춘 128바이트 블록.
    static func sealed(_ block: [UInt8]) -> [UInt8] {
        var b = Array(block.prefix(127)) + [UInt8](repeating: 0, count: max(0, 127 - block.count))
        b.append(0 &- b.reduce(0) { $0 &+ $1 })
        return b
    }

    /// 데이터 블록만 가진 CTA 확장 블록.
    static func ctaBlock(dataBlocks: [UInt8]) -> [UInt8] {
        sealed([0x02, 0x03, UInt8(4 + dataBlocks.count), 0x00] + dataBlocks)
    }
}

/// TC-INF-002: EDID 기본 블록 해석.
@Suite("TC-INF-002 EDID 기본 블록")
struct EDIDBaseBlockTests {
    @Test func LG_TV_기본_정보() throws {
        let edid = EDIDParser.parse(try Fixture.lgTV())
        #expect(edid.byteCount == 384)
        #expect(edid.issues.isEmpty)
        #expect(edid.manufacturerID == "GSM")
        #expect(edid.productCode == 49352)
        #expect(edid.serialNumber == 0x01010101)
        #expect(edid.manufactureYear == 2021)
        #expect(edid.manufactureWeek == 1)
        #expect(edid.version == "1.4")
        #expect(edid.productName == "LG TV SSCR2")
        #expect(edid.isDigital)
        #expect(edid.bitsPerColor == 12)
        #expect(edid.digitalInterface == "DisplayPort")
        #expect(edid.screenWidthCM == 160)
        #expect(edid.screenHeightCM == 90)
        #expect(edid.gamma == 2.2)
        #expect(edid.declaredExtensionCount == 2)
        #expect(edid.vendorNumber == 7789)
    }

    @Test func LG_TV_상세_타이밍과_주사율_범위() throws {
        let edid = EDIDParser.parse(try Fixture.lgTV())
        let first = try #require(edid.detailedTimings.first)
        #expect(first.hActive == 3840)
        #expect(first.vActive == 2160)
        #expect(first.pixelClockHz == 594_000_000)
        #expect(abs(first.refreshRate - 60) < 0.01)
        #expect(first.source == "base")
        #expect(edid.detailedTimings.contains { $0.hActive == 2560 && $0.vActive == 1440 && abs($0.refreshRate - 120) < 0.1 })
        let limits = try #require(edid.rangeLimits)
        #expect(limits.minVerticalHz == 24)
        #expect(limits.maxVerticalHz == 120)
        #expect(limits.maxPixelClockMHz == 1000)
    }

    @Test func 색도_좌표_범위() throws {
        let c = try #require(EDIDParser.parse(try Fixture.lgTV()).chromaticity)
        // IORegistry 실측값(Red X 41920/65536 = 0.6396, Y 21632/65536 = 0.3301)과 대조.
        #expect(abs(c.redX - 0.6396) < 0.001)
        #expect(abs(c.redY - 0.3301) < 0.001)
        #expect(abs(c.whiteX - 0.3125) < 0.001)
        #expect(abs(c.whiteY - 0.3291) < 0.001)
    }

    @Test func 대응_키는_IORegistry_EDID_UUID_형식() throws {
        #expect(EDID.matchKey(from: try Fixture.lgTV()) == "1E6DC8C0-0000-0000-011F-0104C5A05A78")
        #expect(EDID.matchKey(from: [0, 1, 2]) == nil)
    }
}

/// TC-INF-003: 확장 블록과 싱크 능력.
@Suite("TC-INF-003 EDID 확장 블록과 싱크 능력")
struct EDIDExtensionTests {
    @Test func LG_TV_CTA_확장() throws {
        let edid = EDIDParser.parse(try Fixture.lgTV())
        let cta = try #require(edid.cta)
        #expect(cta.revision == 3)
        #expect(cta.supportsYCbCr444)
        #expect(cta.supportsYCbCr422)
        #expect(cta.videoCodes.count == 24)
        #expect(cta.videoCodes.contains { $0.vic == 118 } == false)
        #expect(cta.videoCodes.contains { $0.vic == 117 && $0.width == 3840 && $0.refreshRate == 100 })
        #expect(cta.videoCodes.contains { $0.vic == 219 && $0.width == 4096 && $0.refreshRate == 120 })
        #expect(cta.videoCodes.first { $0.isNative }?.vic == 16)
        #expect(cta.colorimetry == ["BT.2020 YCC", "BT.2020 RGB"])
        let hdr = try #require(cta.hdr)
        #expect(hdr.supportsSDRGamma)
        #expect(hdr.supportsPQ)
        #expect(hdr.supportsHLG)
        #expect(!hdr.supportsHDRGamma)
        #expect(hdr.supportsStaticMetadataType1)
        #expect(hdr.maxLuminance == nil)
        #expect(cta.ycbcr420CapableVICs == [219, 218, 117, 97, 96, 101, 102])
        #expect(cta.audioFormats == ["LPCM 2채널"])
        // DP 경로로 받은 EDID에는 HDMI 제조사 블록 없음.
        #expect(cta.hdmi == nil)
        #expect(cta.hdmiForum == nil)
    }

    @Test func LG_TV_DisplayID_확장() throws {
        let edid = EDIDParser.parse(try Fixture.lgTV())
        let did = try #require(edid.displayID)
        #expect(did.version == "1.2")
        #expect(did.dataBlocks == ["Type I 상세 타이밍"])
        let t = try #require(edid.detailedTimings.first { $0.source == "displayid" })
        #expect(t.hActive == 3840)
        #expect(t.vActive == 2160)
        #expect(t.pixelClockHz == 1_071_360_000)
        #expect(t.hTotal == 3968)
        #expect(t.vTotal == 2250)
        #expect(abs(t.refreshRate - 120) < 0.001)
        #expect(t.hFrontPorch == 32)
        #expect(t.hSyncWidth == 24)
        #expect(t.vFrontPorch == 76)
        #expect(t.vSyncWidth == 8)
        #expect(edid.detailedTimings.contains { $0.source == "displayid" && $0.hActive == 1920 && $0.pixelClockHz == 297_000_000 })
    }

    @Test func LG_TV_싱크_능력_요약() throws {
        let caps = EDIDParser.parse(try Fixture.lgTV()).sinkCapabilities
        #expect(caps.hdrFormats == ["PQ (HDR10)", "HLG"])
        #expect(caps.maxRefreshRate == 120)
        #expect(caps.colorimetry.contains("BT.2020 RGB"))
        #expect(caps.supportsYCbCr420)
        #expect(caps.supportsDSC == nil)
        #expect(caps.maxFRLGbps == nil)
        #expect(caps.deepColorBits == [12])
        #expect(caps.preferredWidth == 3840)
        #expect(caps.preferredHeight == 2160)
    }

    @Test func 합성_HDMI_블록_해석() throws {
        // HDMI VSDB: 물리 주소 1.0.0.0, DC 30과 36비트, 최대 TMDS 300 MHz.
        let vsdb: [UInt8] = [0x67, 0x03, 0x0C, 0x00, 0x10, 0x00, 0x38, 0x3C]
        // HF-VSDB: 판 1, TMDS 600 MHz, SCDC, FRL 6(48 Gbps), DC 4:2:0 10과 12비트, ALLM, VRR 48-120 Hz, DSC 1.2a 10과 12 bpc, DSC FRL 6, 슬라이스 8.
        let hf: [UInt8] = [0x6C, 0xD8, 0x5D, 0xC4, 0x01, 0x78, 0x80, 0x63, 0x02, 0x30, 0x78, 0x83, 0x64]
        // HDR 정적 메타데이터: PQ와 HLG, 최대 휘도 부호 138, 평균 100, 최소 50.
        let hdr: [UInt8] = [0xE6, 0x06, 0x0D, 0x01, 138, 100, 50]
        var base = try Fixture.lgTV()
        base = Array(base[0..<128])
        base[126] = 1
        let bytes = Fixture.sealed(base) + Fixture.ctaBlock(dataBlocks: vsdb + hf + hdr)
        let edid = EDIDParser.parse(bytes)
        #expect(edid.issues.isEmpty)

        let hdmi = try #require(edid.cta?.hdmi)
        #expect(hdmi.physicalAddress == "1.0.0.0")
        #expect(hdmi.supportsDeepColor30)
        #expect(hdmi.supportsDeepColor36)
        #expect(!hdmi.supportsDeepColor48)
        #expect(hdmi.maxTMDSClockMHz == 300)

        let forum = try #require(edid.cta?.hdmiForum)
        #expect(forum.version == 1)
        #expect(forum.maxTMDSCharacterRateMHz == 600)
        #expect(forum.supportsSCDC)
        #expect(forum.maxFRLRate == 6)
        #expect(forum.maxFRLGbps == 48)
        #expect(forum.deepColor420Bits == [10, 12])
        #expect(forum.supportsALLM)
        #expect(forum.vrrMinHz == 48)
        #expect(forum.vrrMaxHz == 120)
        #expect(forum.supportsDSC12a)
        #expect(forum.dscBitsPerComponent == [10, 12])
        #expect(forum.dscMaxFRLRate == 6)
        #expect(forum.dscMaxSlices == 8)

        let hdrInfo = try #require(edid.cta?.hdr)
        let maxLum = try #require(hdrInfo.maxLuminance)
        #expect(abs(maxLum - 50 * pow(2, 138.0 / 32)) < 0.001)
        #expect(abs(maxLum - 993.4) < 0.1)

        let caps = edid.sinkCapabilities
        #expect(caps.maxTMDSMHz == 600)
        #expect(caps.maxFRLGbps == 48)
        #expect(caps.supportsDSC == true)
        #expect(caps.supportsALLM)
        #expect(caps.vrrMinHz == 48)
        #expect(caps.vrrMaxHz == 120)
        #expect(caps.vrrSource == "HDMI Forum VSDB")
        #expect(caps.deepColorBits == [10, 12])
    }

    @Test func VIC_표() {
        #expect(VICTable.format(16)?.height == 1080)
        #expect(VICTable.format(97)?.refreshRate == 60)
        #expect(VICTable.format(118)?.refreshRate == 120)
        #expect(VICTable.format(199)?.width == 7680)
        #expect(VICTable.format(5)?.interlaced == true)
        #expect(VICTable.format(0) == nil)
        #expect(VICTable.format(128) == nil)
    }
}

/// TC-INF-004: 손상 EDID 내성.
@Suite("TC-INF-004 손상 EDID 내성")
struct EDIDRobustnessTests {
    @Test func 빈_입력과_길이_부족() {
        #expect(EDIDParser.parse([UInt8]()).issues.count == 1)
        let short = EDIDParser.parse([UInt8](repeating: 0, count: 127))
        #expect(short.issues.first?.contains("길이 부족") == true)
        #expect(short.manufacturerID.isEmpty)
    }

    @Test func 체크섬_오류는_문제로_기록하고_해석_계속() throws {
        var bytes = try Fixture.lgTV()
        bytes[127] ^= 0xFF
        bytes[255] ^= 0xFF
        let edid = EDIDParser.parse(bytes)
        #expect(edid.issues.contains("기본 블록 체크섬 오류"))
        #expect(edid.issues.contains("확장 블록 1 체크섬 오류"))
        #expect(edid.manufacturerID == "GSM")
        #expect(edid.cta != nil)
    }

    @Test func 확장_블록_누락과_길이_불일치() throws {
        let bytes = try Fixture.lgTV()
        let truncated = EDIDParser.parse(Array(bytes[0..<128]))
        #expect(truncated.issues.contains { $0.contains("확장 블록 수 불일치") })
        #expect(truncated.productName == "LG TV SSCR2")
        let odd = EDIDParser.parse(Array(bytes[0..<200]))
        #expect(odd.issues.contains { $0.contains("128의 배수가 아님") })
    }

    @Test func 데이터_블록_길이_초과() {
        // 길이 31을 선언했으나 영역은 2바이트뿐인 비디오 블록.
        let block = Fixture.sealed([0x02, 0x03, 0x06, 0x00, 0x5F, 0x10])
        var base = [UInt8](repeating: 0, count: 128)
        base.replaceSubrange(0..<8, with: EDIDParser.header)
        base[126] = 1
        let edid = EDIDParser.parse(Fixture.sealed(base) + block)
        #expect(edid.issues.contains { $0.contains("CTA 데이터 블록 길이 초과") })
        #expect(edid.cta?.videoCodes.isEmpty == true)
    }

    @Test func 무작위_바이트_1000건에서_충돌_없음() {
        var generator = SystemRandomNumberGenerator()
        for round in 0..<1000 {
            let blocks = [1, 2, 3, 4][round % 4]
            var bytes = (0..<blocks * 128).map { _ in UInt8.random(in: 0...255, using: &generator) }
            // 절반은 머리와 확장 태그를 유효하게 두어 확장 해석 경로까지 진입.
            if round % 2 == 0 {
                bytes.replaceSubrange(0..<8, with: EDIDParser.header)
                bytes[126] = UInt8(blocks - 1)
                for b in 1..<blocks { bytes[b * 128] = round % 3 == 0 ? 0x70 : 0x02 }
            }
            let edid = EDIDParser.parse(bytes)
            #expect(edid.byteCount == bytes.count)
            _ = edid.sinkCapabilities
        }
    }
}
