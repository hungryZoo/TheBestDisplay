import Foundation
import Testing
@testable import TBDCore

/// TC-EDO-007: EDID에 HDR 선언 추가.
@Suite("TC-EDO-007 HDR 선언 추가")
struct EDIDAddHDRTests {
    @Test func 이미_PQ를_선언한_EDID는_변경_없음() throws {
        let original = try EDIDEditFixture.lgTV()
        #expect(EDIDParser.parse(original).cta?.hdr?.supportsPQ == true)
        let (data, results) = try EDIDEditor.apply([.addHDR(maxNits: nil)], to: original)
        #expect(results[0].changes.isEmpty)
        #expect(data == original)
        #expect(results[0].summary == "이미 선언됨 (변경 없음)")
        // 제거 편집의 변경 없음 사유는 대상 선언 없음.
        let (_, removed) = try EDIDEditor.apply([.removeDSC], to: original)
        #expect(removed[0].summary == "대상 선언 없음 (변경 없음)")
    }

    @Test func HDR_선언이_없는_EDID에_블록_추가() throws {
        // LG TV EDID에서 HDR 선언을 뺀 것을 HDR 미선언 디스플레이의 EDID로 사용.
        let (stripped, _) = try EDIDEditor.apply([.removeHDR], to: try EDIDEditFixture.lgTV())
        let before = EDIDParser.parse(stripped)
        #expect(before.cta?.hdr == nil)

        let (data, results) = try EDIDEditor.apply([.addHDR(maxNits: 600)], to: stripped)
        #expect(EDIDEditor.validate(data).isEmpty)
        #expect(results[0].changes.first == "HDR 정적 메타데이터 블록 추가 (SDR, PQ, 최대 600 cd/m²)")
        let edid = EDIDParser.parse(data)
        let hdr = try #require(edid.cta?.hdr)
        #expect(hdr.supportsPQ && hdr.supportsSDRGamma && hdr.supportsStaticMetadataType1)
        #expect(!hdr.supportsHLG)
        // 휘도 부호는 32 x log2(600 / 50)의 반올림 115: 50 x 2^(115/32)은 약 604.
        #expect(abs((hdr.maxLuminance ?? 0) - 603.6) < 1)
        #expect(edid.cta?.colorimetry.contains("BT.2020 RGB") == true)
        #expect(edid.sinkCapabilities.hdrFormats.contains { $0.contains("PQ") || $0.contains("HDR10") })
        // 다른 내용은 유지.
        #expect(edid.detailedTimings == before.detailedTimings)
        #expect(data.count == stripped.count)
    }

    @Test func 최대_휘도를_주지_않으면_휘도_없이_추가() throws {
        let (stripped, _) = try EDIDEditor.apply([.removeHDR], to: try EDIDEditFixture.lgTV())
        let (data, results) = try EDIDEditor.apply([.addHDR(maxNits: nil)], to: stripped)
        #expect(results[0].changes.first == "HDR 정적 메타데이터 블록 추가 (SDR, PQ)")
        let hdr = try #require(EDIDParser.parse(data).cta?.hdr)
        #expect(hdr.supportsPQ)
        #expect(hdr.maxLuminance == nil)
    }

    @Test func 제거와_추가를_함께_주면_순서대로_적용() throws {
        let (data, results) = try EDIDEditor.apply([.removeHDR, .addHDR(maxNits: 1000)], to: try EDIDEditFixture.hdmi())
        #expect(results.count == 2 && results.allSatisfy(\.changed))
        let hdr = try #require(EDIDParser.parse(data).cta?.hdr)
        // 휘도 부호 138: 50 x 2^(138/32)은 약 993.
        #expect(abs((hdr.maxLuminance ?? 0) - 993) < 2)
        #expect(EDIDEditor.validate(data).isEmpty)
    }

    @Test func PQ가_없는_HDR_블록에는_PQ_선언만_추가() throws {
        let source = [UInt8](try EDIDEditFixture.lgTV())
        var cta = try #require(EDIDEditor.CTABlock(Array(source[128..<256])))
        let position = try #require(cta.dataBlocks.firstIndex { EDIDEditor.CTABlock.extendedTag($0) == 6 })
        // SDR과 HLG만 선언한 상태로 바꿈.
        cta.dataBlocks[position][2] = 0x09
        var bytes = source
        bytes.replaceSubrange(128..<256, with: EDIDEditor.withChecksum(try cta.serialized()))
        let (data, results) = try EDIDEditor.apply([.addHDR(maxNits: nil)], to: Data(bytes))
        #expect(results[0].changes.contains("기존 HDR 정적 메타데이터 블록에 PQ 선언 추가"))
        let hdr = try #require(EDIDParser.parse(data).cta?.hdr)
        #expect(hdr.supportsPQ && hdr.supportsHLG)
    }

    @Test func CTA_확장_블록이_없으면_거부() throws {
        var base = Array([UInt8](try EDIDEditFixture.lgTV())[0..<128])
        base[126] = 0
        let data = Data(EDIDEditor.withChecksum(base))
        #expect(EDIDEditor.validate(data).isEmpty)
        #expect(throws: EDIDEditError.unsupported("CTA 확장 블록(3판 이상) 없음")) { try EDIDEditor.apply([.addHDR(maxNits: nil)], to: data) }
    }

    @Test func 공간이_없으면_오류() throws {
        let source = [UInt8](try EDIDEditFixture.lgTV())
        var bytes = Array(source[0..<256])
        bytes[126] = 1
        bytes.replaceSubrange(0..<128, with: EDIDEditor.withChecksum(Array(bytes[0..<128])))
        var cta = try #require(EDIDEditor.CTABlock(Array(bytes[128..<256])))
        cta.dataBlocks.removeAll { [5, 6, 7].contains(EDIDEditor.CTABlock.extendedTag($0) ?? -1) }
        // 남는 공간을 제조사 블록으로 채워 3바이트만 남김.
        while cta.freeBytes > 3 {
            let size = min(cta.freeBytes - 3, 31)
            guard size >= 4 else { break }
            cta.dataBlocks.append([0x60 | UInt8(size - 1), 0xAA, 0xBB, 0xCC] + [UInt8](repeating: 0, count: size - 4))
        }
        #expect(cta.freeBytes < 4)
        bytes.replaceSubrange(128..<256, with: EDIDEditor.withChecksum(try cta.serialized()))
        #expect(throws: EDIDEditError.self) { try EDIDEditor.apply([.addHDR(maxNits: nil)], to: Data(bytes)) }
    }

    @Test func 명령행_표기와_이름() {
        #expect(EDIDPatch.parse("add-hdr") == .addHDR(maxNits: nil))
        #expect(EDIDPatch.parse("add-hdr:600") == .addHDR(maxNits: 600))
        #expect(EDIDPatch.parse("add-hdr:50") == nil)
        #expect(EDIDPatch.parse("add-hdr:20000") == nil)
        #expect(EDIDPatch.parseList("remove-hdr,add-hdr:1000") == [.removeHDR, .addHDR(maxNits: 1000)])
        #expect(EDIDPatch.addHDR(maxNits: nil).title == "HDR 선언 추가 (PQ, BT.2020)")
        #expect(EDIDPatch.addHDR(maxNits: 600).title == "HDR 선언 추가 (PQ, BT.2020), 최대 600 cd/m²")
        #expect(EDIDPatch.simpleCases.contains(.addHDR(maxNits: nil)))
        #expect(EDIDEditor.luminanceCode(600) == 115 && EDIDEditor.luminanceCode(1000) == 138)
    }
}
