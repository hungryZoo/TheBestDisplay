import Foundation
import Testing
@testable import TBDCore

enum EDIDEditFixture {
    static func lgTV() throws -> Data { try Fixture.data("lg_tv_sscr2_dp.edid.bin") }

    /// HDMI 싱크의 합성 EDID: LG TV 기본 블록 + 직접 구성한 CTA 확장 블록 1개.
    /// HDMI VSDB(340 MHz, 딥 컬러, Y444), HF-VSDB(600 MHz, FRL 6, VRR 48-120 Hz, DSC 1.2a), HDR 정적 메타데이터,
    /// Dolby Vision 블록, 4:2:0 비디오 블록과 능력 맵 포함.
    static func hdmi() throws -> Data {
        let source = [UInt8](try lgTV())
        var base = Array(source[0..<128])
        base[126] = 1
        var cta = try #require(EDIDEditor.CTABlock(Array(source[128..<256])))
        cta.dataBlocks = [
            [0x43, 0x10, 0x61, 0x76],                                                       // 비디오: VIC 16, 97, 118
            [0x67, 0x03, 0x0C, 0x00, 0x10, 0x00, 0xB8, 0x44],                               // HDMI VSDB
            [0x6D, 0xD8, 0x5D, 0xC4, 0x01, 0x78, 0x80, 0x63, 0x52, 0x30, 0x78, 0x83, 0x64, 0x10], // HF-VSDB
            [0xE3, 0x06, 0x0D, 0x01],                                                       // HDR 정적 메타데이터
            [0xE7, 0x01, 0x46, 0xD0, 0x00, 0x48, 0x03, 0x76],                               // Dolby Vision
            [0xE2, 0x0E, 0x61],                                                             // 4:2:0 비디오
            [0xE2, 0x0F, 0x06],                                                             // 4:2:0 능력 맵
        ]
        cta.descriptors = Array(cta.descriptors.prefix(1))
        let block = try cta.serialized()
        return Data(EDIDEditor.withChecksum(base) + EDIDEditor.withChecksum(block))
    }
}

/// TC-EDO-001: EDID 검증과 편집.
@Suite("TC-EDO-001 EDID 검증과 편집")
struct EDIDEditorTests {
    @Test func 검증은_길이_머리_블록_수_체크섬_확인() throws {
        let edid = try EDIDEditFixture.lgTV()
        #expect(EDIDEditor.validate(edid).isEmpty)
        #expect(EDIDEditor.validate(try EDIDEditFixture.hdmi()).isEmpty)

        var corrupted = edid
        corrupted[130] ^= 0xFF
        #expect(EDIDEditor.validate(corrupted) == ["블록 1 체크섬 오류"])
        #expect(EDIDEditor.validate(edid.prefix(256)) == ["확장 블록 수 선언 2개, 실제 1개"])
        #expect(EDIDEditor.validate(edid.prefix(100)) == ["길이 100바이트 (최소 128바이트)"])
        var badHeader = edid
        badHeader[1] = 0
        #expect(EDIDEditor.validate(badHeader).contains("머리 8바이트 불일치"))
        #expect(throws: EDIDEditError.self) { try EDIDEditor.apply([.removeHDR], to: corrupted) }
    }

    @Test func 합성_픽스처의_편집_전_능력() throws {
        let caps = EDIDParser.parse(try EDIDEditFixture.hdmi()).sinkCapabilities
        #expect(caps.supportsDSC == true)
        #expect(caps.hdrFormats == ["PQ (HDR10)", "HLG"] || !caps.hdrFormats.isEmpty)
        #expect(caps.supportsYCbCr444 && caps.supportsYCbCr422 && caps.supportsYCbCr420)
        #expect(caps.vrrMinHz == 48)
        #expect(caps.vrrMaxHz == 120)
        #expect(caps.maxTMDSMHz == 600)
        #expect(caps.maxFRLGbps == 48)
    }

    @Test func DSC_선언_제거() throws {
        let (data, results) = try EDIDEditor.apply([.removeDSC], to: try EDIDEditFixture.hdmi())
        #expect(EDIDEditor.validate(data).isEmpty)
        #expect(results.map(\.changed) == [true])
        let edid = EDIDParser.parse(data)
        #expect(edid.sinkCapabilities.supportsDSC == false)
        #expect(edid.cta?.hdmiForum?.dscMaxFRLRate == 0)
        // 다른 선언은 유지.
        #expect(edid.sinkCapabilities.maxFRLGbps == 48)
        #expect(edid.sinkCapabilities.vrrMinHz == 48)
        #expect(edid.detailedTimings.count == EDIDParser.parse(try EDIDEditFixture.hdmi()).detailedTimings.count)
    }

    @Test func HDR_선언_제거는_블록을_빼고_상세_타이밍_오프셋_재계산() throws {
        let original = try EDIDEditFixture.hdmi()
        let (data, results) = try EDIDEditor.apply([.removeHDR], to: original)
        #expect(EDIDEditor.validate(data).isEmpty)
        #expect(results[0].changes == ["HDR 관련 데이터 블록 2개 제거"])
        let edid = EDIDParser.parse(data)
        #expect(edid.cta?.hdr == nil)
        #expect(edid.sinkCapabilities.hdrFormats.isEmpty)
        // 블록 2개(4 + 8바이트)가 빠진 만큼 상세 타이밍 시작 오프셋 감소.
        #expect(Int(data[128 + 2]) == Int(original[128 + 2]) - 12)
        #expect(edid.detailedTimings == EDIDParser.parse(original).detailedTimings)
        #expect(edid.issues.isEmpty)
    }

    @Test func YCbCr_선언_제거() throws {
        let original = try EDIDEditFixture.hdmi()
        let (rgbOnly, _) = try EDIDEditor.apply([.removeYCbCr], to: original)
        #expect(EDIDEditor.validate(rgbOnly).isEmpty)
        let caps = EDIDParser.parse(rgbOnly).sinkCapabilities
        #expect(!caps.supportsYCbCr444 && !caps.supportsYCbCr422 && !caps.supportsYCbCr420)
        #expect(rgbOnly[24] & 0x18 == 0)
        #expect(original[24] & 0x18 == 0x18)
        #expect(EDIDParser.parse(rgbOnly).cta?.hdmi?.supportsDeepColorYCbCr444 == false)
        #expect(EDIDParser.parse(rgbOnly).cta?.hdmi?.supportsDeepColor36 == true)

        let (no420, results) = try EDIDEditor.apply([.removeYCbCr420], to: original)
        let caps420 = EDIDParser.parse(no420).sinkCapabilities
        #expect(caps420.supportsYCbCr444 && caps420.supportsYCbCr422 && !caps420.supportsYCbCr420)
        #expect(EDIDParser.parse(no420).cta?.hdmiForum?.deepColor420Bits == [])
        #expect(results[0].changes.count == 2)
    }

    @Test func VRR_제거와_속도_제한() throws {
        let original = try EDIDEditFixture.hdmi()
        let (data, results) = try EDIDEditor.apply([.removeVRR, .limitFRLRate(3), .limitTMDSRate(300)], to: original)
        #expect(EDIDEditor.validate(data).isEmpty)
        #expect(results.allSatisfy { $0.changed })
        let edid = EDIDParser.parse(data)
        #expect(edid.sinkCapabilities.vrrMinHz == nil)
        #expect(edid.cta?.hdmiForum?.supportsALLM == true)
        #expect(edid.cta?.hdmiForum?.supportsQMS == false)
        #expect(edid.cta?.hdmiForum?.maxFRLRate == 3)
        #expect(edid.cta?.hdmiForum?.dscMaxFRLRate == 3)
        #expect(edid.cta?.hdmiForum?.maxTMDSCharacterRateMHz == 300)
        #expect(edid.cta?.hdmi?.maxTMDSClockMHz == 300)
        // 이미 한도 이하이면 변경 없음.
        let (again, second) = try EDIDEditor.apply([.limitFRLRate(5), .limitTMDSRate(600)], to: data)
        #expect(again == data)
        #expect(second.allSatisfy { !$0.changed })
    }

    @Test func 실측_EDID는_HDMI_선언이_없어_DSC_편집_대상_없음() throws {
        let original = try EDIDEditFixture.lgTV()
        let (same, results) = try EDIDEditor.apply([.removeDSC, .removeVRR], to: original)
        #expect(same == original)
        #expect(results.allSatisfy { !$0.changed })

        let (noHDR, _) = try EDIDEditor.apply([.removeHDR, .removeYCbCr], to: original)
        #expect(EDIDEditor.validate(noHDR).isEmpty)
        let before = EDIDParser.parse(original), after = EDIDParser.parse(noHDR)
        #expect(!before.sinkCapabilities.hdrFormats.isEmpty)
        #expect(after.sinkCapabilities.hdrFormats.isEmpty)
        #expect(!after.sinkCapabilities.supportsYCbCr444 && !after.sinkCapabilities.supportsYCbCr420)
        #expect(after.detailedTimings == before.detailedTimings)
        // DisplayID 확장 블록과 식별 정보는 그대로.
        #expect(noHDR.suffix(128) == original.suffix(128))
        #expect(after.vendorNumber == before.vendorNumber && after.productCode == before.productCode && after.serialNumber == before.serialNumber)
    }

    @Test func 편집_목록_해석() {
        #expect(EDIDPatch.parseList("remove-dsc, remove-hdr,limit-frl:3") == [.removeDSC, .removeHDR, .limitFRLRate(3)])
        #expect(EDIDPatch.parseList("rgb-only,remove-420,remove-vrr,limit-tmds:340") == [.removeYCbCr, .removeYCbCr420, .removeVRR, .limitTMDSRate(340)])
        #expect(EDIDPatch.parseList("remove-dsc,unknown") == nil)
        #expect(EDIDPatch.parseList("limit-frl:9") == nil)
        #expect(EDIDPatch.parseList("") == nil)
    }

    @Test func 능력_비교_행() throws {
        let rows = EDIDParser.parse(try EDIDEditFixture.hdmi()).sinkCapabilities.comparisonRows
        #expect(rows.first { $0.label == "DSC (EDID 선언)" }?.value == "지원")
        #expect(rows.first { $0.label == "VRR" }?.value == "48-120 Hz")
        #expect(rows.first { $0.label == "FRL 최대" }?.value == "48 Gbps")
        #expect(rows.first { $0.label == "YCbCr" }?.value == "4:4:4, 4:2:2, 4:2:0")
    }
}
