import Foundation
import Testing
@testable import TBDCore

/// TC-EDO-005: 사용자 정의 타이밍 계산과 EDID 주입.
@Suite("TC-EDO-005 사용자 정의 타이밍")
struct CustomTimingTests {
    @Test func CVT_축소_블랭킹_1판_기준값() throws {
        // VESA CVT 기준값: 1920x1080 60 Hz는 138.50 MHz, 총 2080 x 1111.
        let t = try #require(DetailedTimingSpec.cvt(width: 1920, height: 1080, refreshRate: 60, formula: .reducedBlanking))
        #expect(t.pixelClockHz == 138_500_000)
        #expect(t.hTotal == 2080 && t.vTotal == 1111)
        #expect([t.hFrontPorch, t.hSyncWidth, t.hBackPorch] as [Int] == [48, 32, 80])
        #expect([t.vFrontPorch, t.vSyncWidth, t.vBackPorch] as [Int] == [3, 5, 23])
        // 16:10은 수직 동기 6라인.
        #expect(DetailedTimingSpec.cvt(width: 1920, height: 1200, refreshRate: 60, formula: .reducedBlanking)?.vSyncWidth == 6)
        // 수평 활성은 8의 배수로 내림.
        #expect(DetailedTimingSpec.cvt(width: 1366, height: 768, refreshRate: 60, formula: .reducedBlanking)?.hActive == 1360)
    }

    @Test func CVT_축소_블랭킹_2판_기준값() throws {
        // VESA CVT 1.2 기준값: 3840x2160 60 Hz는 522.614 MHz, 총 3920 x 2222.
        let t = try #require(DetailedTimingSpec.cvt(width: 3840, height: 2160, refreshRate: 60, formula: .reducedBlanking2))
        #expect(t.pixelClockHz == 522_614_000)
        #expect(t.hTotal == 3920 && t.vTotal == 2222)
        #expect([t.hFrontPorch, t.hSyncWidth, t.hBackPorch] as [Int] == [8, 32, 40])
        #expect([t.vFrontPorch, t.vSyncWidth, t.vBackPorch] as [Int] == [48, 8, 6])
        #expect(abs(t.refreshRate - 60) < 0.001)

        let qhd = try #require(DetailedTimingSpec.cvt(width: 2560, height: 1440, refreshRate: 144, formula: .reducedBlanking2))
        #expect(qhd.hTotal == 2640 && qhd.vTotal == 1543)
        #expect(qhd.pixelClockHz == 586_586_000)
        #expect(DetailedTimingSpec.cvt(width: 10, height: 10, refreshRate: 60, formula: .reducedBlanking2) == nil)
    }

    @Test func 서술자_18바이트_왕복() throws {
        let spec = try #require(DetailedTimingSpec.cvt(width: 1920, height: 1080, refreshRate: 60, formula: .reducedBlanking))
        let d = try spec.descriptor(widthMM: 600, heightMM: 340)
        #expect(d.count == 18)
        let parsed = try #require(EDIDParser.detailedTiming(d, source: "base"))
        #expect(parsed.pixelClockHz == 138_500_000)
        #expect(parsed.hActive == 1920 && parsed.hBlank == 160 && parsed.hFrontPorch == 48 && parsed.hSyncWidth == 32)
        #expect(parsed.vActive == 1080 && parsed.vBlank == 31 && parsed.vFrontPorch == 3 && parsed.vSyncWidth == 5)
        #expect(d[17] == 0x1A)
        #expect(Int(d[12]) | Int(d[14] >> 4) << 8 == 600)
        #expect(DetailedTimingSpec(descriptor: d) == spec)
        #expect(DetailedTimingSpec(descriptor: [UInt8](repeating: 0, count: 18)) == nil)
    }

    @Test func 표현_범위와_DisplayID_타이밍_왕복() throws {
        let uhd120 = try #require(DetailedTimingSpec.cvt(width: 3840, height: 2160, refreshRate: 120, formula: .reducedBlanking2))
        #expect(uhd120.pixelClockHz > 655_350_000)
        #expect(!uhd120.fitsDescriptor)
        #expect(throws: EDIDEditError.self) { try uhd120.descriptor() }

        let d = try uhd120.displayIDTiming(preferred: true, version2: false)
        #expect(d.count == 20)
        #expect(d[3] == 0x84)
        let parsed = try #require(EDIDParser.displayIDTiming(d, clockUnitHz: 10_000))
        #expect(parsed.hActive == 3840 && parsed.vActive == 2160)
        #expect(parsed.hBlank == uhd120.hBlank && parsed.vBlank == uhd120.vBlank)
        #expect(parsed.hFrontPorch == 8 && parsed.hSyncWidth == 32 && parsed.vSyncWidth == 8)
        #expect(parsed.pixelClockHz == Double(uhd120.pixelClockHz / 10_000 * 10_000))
        #expect(abs(parsed.refreshRate - 120) < 0.01)
    }

    @Test func 명령행_표기_해석() throws {
        #expect(DetailedTimingSpec.parse("2560x1440@100") == DetailedTimingSpec.cvt(width: 2560, height: 1440, refreshRate: 100, formula: .reducedBlanking2))
        #expect(DetailedTimingSpec.parse("1920x1080@60:rb")?.pixelClockHz == 138_500_000)
        #expect(DetailedTimingSpec.parse("1920x1080@59.94:rb2") != nil)
        let raw = try #require(DetailedTimingSpec.parse("raw:1920,48,32,80,1080,3,5,23,138500,+h,-v"))
        #expect(raw == DetailedTimingSpec.cvt(width: 1920, height: 1080, refreshRate: 60, formula: .reducedBlanking))
        #expect(DetailedTimingSpec.parse("raw:1920,48,32,80,1080,3,5,23") == nil)
        #expect(DetailedTimingSpec.parse("raw:1920,0,32,80,1080,3,5,23,138500") == nil)
        #expect(DetailedTimingSpec.parse("1920x1080") == nil)
        #expect(DetailedTimingSpec.parse("1920x1080@60:gtf") == nil)
    }

    @Test func 실측_EDID에_타이밍_추가() throws {
        let original = try EDIDEditFixture.lgTV()
        let before = EDIDParser.parse(original)
        let spec = try #require(DetailedTimingSpec.parse("2560x1440@100"))
        let (data, results) = try EDIDEditor.apply([.addTiming(spec, preferred: false)], to: original)
        #expect(EDIDEditor.validate(data).isEmpty)
        #expect(results[0].changed)
        let after = EDIDParser.parse(data)
        #expect(after.issues.isEmpty)
        #expect(after.detailedTimings.count == before.detailedTimings.count + 1)
        #expect(after.detailedTimings.contains { $0.hActive == 2560 && $0.vActive == 1440 && abs($0.refreshRate - 100) < 0.01 })
        // 기존 타이밍은 모두 유지.
        for timing in before.detailedTimings {
            #expect(after.detailedTimings.contains { $0.hActive == timing.hActive && $0.vActive == timing.vActive && $0.pixelClockHz == timing.pixelClockHz })
        }
        #expect(after.sinkCapabilities.preferredWidth == before.sinkCapabilities.preferredWidth)
    }

    @Test func 선호_타이밍_교체는_기존_타이밍을_다른_자리로_이동() throws {
        let original = try EDIDEditFixture.lgTV()
        let before = EDIDParser.parse(original)
        let spec = try #require(DetailedTimingSpec.parse("2560x1440@100"))
        let (data, results) = try EDIDEditor.apply([.addTiming(spec, preferred: true)], to: original)
        #expect(EDIDEditor.validate(data).isEmpty)
        #expect(results[0].changes.count == 2)
        let after = EDIDParser.parse(data)
        #expect(after.sinkCapabilities.preferredWidth == 2560)
        #expect(after.sinkCapabilities.preferredHeight == 1440)
        #expect(after.detailedTimings.count == before.detailedTimings.count + 1)
        let old = try #require(before.detailedTimings.first)
        #expect(after.detailedTimings.dropFirst().contains { $0.hActive == old.hActive && $0.vActive == old.vActive && $0.pixelClockHz == old.pixelClockHz })
        // 물리 크기는 기존 선호 타이밍의 값 유지.
        #expect(Array(data[66...68]) == Array(original[66...68]))
    }

    static func displayIDSectionChecksumValid(_ block: Data) -> Bool {
        let b = [UInt8](block)
        return b[0] == 0x70 && b[1...126].reduce(0) { ($0 + Int($1)) & 0xFF } == 0
    }

    @Test func 높은_픽셀_클록은_DisplayID_확장에_추가() throws {
        let original = try EDIDEditFixture.lgTV()
        let before = EDIDParser.parse(original)
        let spec = try #require(DetailedTimingSpec.parse("3840x2160@144"))
        let (data, results) = try EDIDEditor.apply([.addTiming(spec, preferred: false)], to: original)
        #expect(data.count == original.count)
        #expect(EDIDEditor.validate(data).isEmpty)
        #expect(results[0].changes.first?.contains("DisplayID 확장 블록 2") == true)
        #expect(Self.displayIDSectionChecksumValid(data.suffix(128)))
        let after = EDIDParser.parse(data)
        #expect(after.issues.isEmpty)
        #expect(after.detailedTimings.count == before.detailedTimings.count + 1)
        #expect(after.detailedTimings.contains { $0.source == "displayid" && $0.hActive == 3840 && abs($0.refreshRate - 144) < 0.01 })
        // CTA 확장 블록은 그대로.
        #expect(data[128..<256] == original[128..<256])
    }

    @Test func DisplayID_확장이_없으면_새_확장_블록_생성() throws {
        let original = try EDIDEditFixture.hdmi()
        #expect(original.count == 256)
        let spec = try #require(DetailedTimingSpec.parse("3840x2160@120"))
        let (data, results) = try EDIDEditor.apply([.addTiming(spec, preferred: true)], to: original)
        #expect(data.count == 384)
        #expect(data[126] == 2)
        #expect(EDIDEditor.validate(data).isEmpty)
        #expect(results[0].changes.first?.contains("새 DisplayID 확장 블록 2") == true)
        #expect(Self.displayIDSectionChecksumValid(data.suffix(128)))
        let after = EDIDParser.parse(data)
        #expect(after.displayID != nil)
        #expect(after.detailedTimings.contains { $0.source == "displayid" && $0.hActive == 3840 && abs($0.refreshRate - 120) < 0.01 })
        // 선호 표시 비트.
        #expect(data[256 + 5 + 3 + 3] & 0x80 != 0)
    }

    @Test func 잘못된_타이밍은_거부() throws {
        var bad = try #require(DetailedTimingSpec.parse("1920x1080@60"))
        bad.hSyncWidth = 0
        #expect(!bad.issues.isEmpty)
        #expect(throws: EDIDEditError.self) { try EDIDEditor.apply([.addTiming(bad, preferred: false)], to: try EDIDEditFixture.lgTV()) }
    }
}
