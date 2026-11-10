import Foundation
import Testing
@testable import TBDCore

/// 212바이트 모드 서술 구조체를 만드는 시험 보조 함수.
func modeDescription(number: UInt32, width: UInt32, height: UInt32, pixelWidth: UInt32, pixelHeight: UInt32, scale: Float, hz: Double, flags: UInt32 = 1) -> [UInt8] {
    var bytes = [UInt8](repeating: 0, count: 212)
    func put(_ value: UInt32, at offset: Int) {
        for i in 0..<4 { bytes[offset + i] = UInt8((value >> (8 * UInt32(i))) & 0xFF) }
    }
    put(number, at: 0x00)
    put(flags, at: 0x04)
    put(width, at: 0x08)
    put(height, at: 0x0C)
    put(8, at: 0x1C)
    put(UInt32(hz), at: 0x24)
    put(UInt32(hz * 65536), at: 0xBC)
    put(pixelWidth, at: 0xC8)
    put(pixelHeight, at: 0xCC)
    put(scale.bitPattern, at: 0xD0)
    return bytes
}

func mode(_ number: Int32, _ w: Int, _ h: Int, hidpi: Bool, hz: Double, vrr: Bool = false, visible: Bool = true, native: Bool = false) -> DisplayMode {
    var m = DisplayMode(modeNumber: number, width: w, height: h, pixelWidth: w * (hidpi ? 2 : 1), pixelHeight: h * (hidpi ? 2 : 1), scale: hidpi ? 2 : 1, refreshRate: hz, isVRR: vrr, isInSystemDefaultList: visible)
    m.isNative = native
    return m
}

/// TC-MOD-002: 모드 해석, 묶음, 필터, 시스템 목록 판정.
@Suite("TC-MOD-002 모드 묶음과 필터")
struct ModeCatalogTests {
    let modes = [
        mode(1, 3840, 2160, hidpi: false, hz: 120, native: true),
        mode(2, 3840, 2160, hidpi: false, hz: 60, native: true),
        mode(3, 1920, 1080, hidpi: true, hz: 120),
        mode(4, 1920, 1080, hidpi: true, hz: 60),
        mode(5, 1920, 1080, hidpi: false, hz: 60),
        mode(6, 2560, 1440, hidpi: true, hz: 120, visible: false),
        mode(7, 2560, 1440, hidpi: true, hz: 59.94, visible: false),
        mode(8, 1600, 1200, hidpi: false, hz: 60),
        mode(9, 1920, 1080, hidpi: true, hz: 120, vrr: true),
    ]

    @Test func 구조체_해석() throws {
        let m = try #require(DisplayMode.decode(modeDescription(number: 149, width: 2304, height: 1296, pixelWidth: 4608, pixelHeight: 2592, scale: 2, hz: 120)))
        #expect(m.modeNumber == 149)
        #expect((m.width, m.height) == (2304, 1296))
        #expect((m.pixelWidth, m.pixelHeight) == (4608, 2592))
        #expect(m.scale == 2)
        #expect(m.isHiDPI)
        #expect(m.refreshRate == 120)
        #expect(m.bitsPerSample == 8)
        #expect(m.label == "2304 x 1296 HiDPI, 120 Hz")
        // 소수 주사율은 16.16 고정소수점에서 복원.
        let ntsc = try #require(DisplayMode.decode(modeDescription(number: 1, width: 1920, height: 1080, pixelWidth: 1920, pixelHeight: 1080, scale: 1, hz: 59.94)))
        #expect(abs(ntsc.refreshRate - 59.94) < 0.001)
        #expect(!ntsc.isHiDPI)
    }

    @Test func 길이가_다르거나_해상도가_0이면_해석_거부() {
        #expect(DisplayMode.decode([UInt8](repeating: 0, count: 211)) == nil)
        #expect(DisplayMode.decode([UInt8](repeating: 0, count: 260)) == nil)
        #expect(DisplayMode.decode([UInt8](repeating: 0, count: 212)) == nil)
        #expect(DisplayMode.descriptionLength == 212)
    }

    @Test func 해상도별_묶음과_정렬() {
        let groups = ModeCatalog.groups(modes)
        #expect(groups.map(\.id) == ["3840x2160@1", "2560x1440@2", "1920x1080@2", "1920x1080@1", "1600x1200@1"])
        let fhd = groups[2]
        #expect(fhd.modes.map(\.modeNumber) == [9, 3, 4])
        #expect(fhd.label == "1920 x 1080 HiDPI")
        #expect((fhd.pixelWidth, fhd.pixelHeight) == (3840, 2160))
        #expect(groups[1].isOutsideSystemDefaultList)
        #expect(!groups[0].isOutsideSystemDefaultList)
    }

    @Test func 필터() {
        var filter = ModeFilter()
        filter.hiDPI = .hiDPIOnly
        #expect(ModeCatalog.groups(modes, filter: filter).map(\.id) == ["2560x1440@2", "1920x1080@2"])
        filter.hiDPI = .lowDPIOnly
        #expect(ModeCatalog.groups(modes, filter: filter).count == 3)
        filter = ModeFilter()
        filter.refreshRate = 60
        #expect(Set(ModeCatalog.groups(modes, filter: filter).flatMap(\.modes).map(\.modeNumber)) == [2, 4, 5, 7, 8])
        filter = ModeFilter()
        filter.aspectRatio = "4:3"
        #expect(ModeCatalog.groups(modes, filter: filter).map(\.id) == ["1600x1200@1"])
        filter = ModeFilter()
        filter.onlyOutsideSystemDefaultList = true
        #expect(ModeCatalog.groups(modes, filter: filter).flatMap(\.modes).map(\.modeNumber) == [6, 7])
    }

    @Test func 주사율과_종횡비_집계() {
        #expect(ModeCatalog.refreshRates(modes) == [60, 120])
        #expect(ModeCatalog.aspectRatios(modes).first == "16:9")
        #expect(mode(1, 3024, 1964, hidpi: false, hz: 60).aspectRatio == "756:491")
        #expect(mode(1, 2560, 1600, hidpi: false, hz: 60).aspectRatio == "16:10")
        #expect(mode(1, 3440, 1440, hidpi: false, hz: 60).aspectRatio == "21:9")
    }

    @Test func 원본_모드_판정() {
        #expect(ModeCatalog.nativeModes(modes, nativeWidth: 3840, nativeHeight: 2160).map(\.modeNumber) == [1, 2])
        // 시스템 판정이 없으면 백킹 해상도 대조, 배율 1 우선.
        let unflagged = modes.map { m -> DisplayMode in var c = m; c.isNative = false; return c }
        #expect(ModeCatalog.nativeModes(unflagged, nativeWidth: 3840, nativeHeight: 2160).map(\.modeNumber) == [1, 2])
        #expect(ModeCatalog.nativeModes(unflagged.filter { $0.isHiDPI }, nativeWidth: 3840, nativeHeight: 2160).map(\.modeNumber) == [3, 4, 9])
    }

    @Test func 공개_API_대조로_시스템_목록_판정() {
        let keys: Set<String> = [ModeCatalog.defaultKey(width: 1920, height: 1080, pixelWidth: 1920, refreshRate: 59.94)]
        let marked = ModeCatalog.markSystemDefault(modes, defaultKeys: keys)
        #expect(marked.filter(\.isInSystemDefaultList).map(\.modeNumber) == [5])
    }

    @Test func 모드_서술로_찾기() {
        #expect(ModeDescriptor(width: 1920, height: 1080, isHiDPI: true, refreshRate: 120).find(in: modes)?.modeNumber == 3)
        #expect(ModeDescriptor(width: 1920, height: 1080, isHiDPI: true, refreshRate: 120, isVRR: true).find(in: modes)?.modeNumber == 9)
        #expect(ModeDescriptor(width: 2560, height: 1440, isHiDPI: true, refreshRate: 59.94).find(in: modes)?.modeNumber == 7)
        #expect(ModeDescriptor(width: 2560, height: 1440, isHiDPI: false, refreshRate: 60).find(in: modes) == nil)
        #expect(modes[2].descriptor == ModeDescriptor(width: 1920, height: 1080, isHiDPI: true, refreshRate: 120))
    }
}

@Suite("TC-CLI-003 모드 지정 해석")
struct ModeSpecTests {
    let modes = ModeCatalogTests().modes

    @Test func 형식_해석() {
        #expect(ModeSpec.parse("mode:149") == .number(149))
        #expect(ModeSpec.parse("1920x1080") == .resolution(width: 1920, height: 1080, refreshRate: nil, hiDPI: nil))
        #expect(ModeSpec.parse("1920x1080@60") == .resolution(width: 1920, height: 1080, refreshRate: 60, hiDPI: nil))
        #expect(ModeSpec.parse("2560X1440@59.94:HiDPI") == .resolution(width: 2560, height: 1440, refreshRate: 59.94, hiDPI: true))
        #expect(ModeSpec.parse("1920x1080:lodpi") == .resolution(width: 1920, height: 1080, refreshRate: nil, hiDPI: false))
        for bad in ["", "1920", "1920x", "ax1080", "1920x1080@", "1920x1080@abc", "mode:x", "0x0", "1920x1080x2"] {
            #expect(ModeSpec.parse(bad) == nil, "\(bad)")
        }
    }

    @Test func 생략_항목은_현재_주사율과_HiDPI_우선() throws {
        let current = modes[3]  // 1920x1080 HiDPI 60 Hz
        #expect(try ModeSpec.parse("1920x1080")!.resolve(in: modes, current: current).modeNumber == 4)
        #expect(try ModeSpec.parse("1920x1080")!.resolve(in: modes, current: nil).modeNumber == 3)
        #expect(try ModeSpec.parse("1920x1080:lodpi")!.resolve(in: modes, current: current).modeNumber == 5)
        #expect(try ModeSpec.parse("3840x2160@120")!.resolve(in: modes, current: current).modeNumber == 1)
        #expect(try ModeSpec.parse("2560x1440@60")!.resolve(in: modes, current: current).modeNumber == 7)
        #expect(try ModeSpec.parse("mode:8")!.resolve(in: modes, current: nil).modeNumber == 8)
    }

    @Test func 없는_모드는_오류() {
        #expect(throws: ModeSpec.ResolveError.notFound("mode:99")) { try ModeSpec.number(99).resolve(in: modes, current: nil) }
        #expect(throws: ModeSpec.ResolveError.notFound("1024x768@75:hidpi")) { try ModeSpec.parse("1024x768@75:hidpi")!.resolve(in: modes, current: nil) }
    }
}
