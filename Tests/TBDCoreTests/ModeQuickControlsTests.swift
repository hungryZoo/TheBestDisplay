import Foundation
import Testing
@testable import TBDCore

/// TC-MOD-017: 주사율 선택 목록, HiDPI 전환 대상, 해상도 구성 요약.
@Suite("TC-MOD-017 해상도 빠른 설정 계산")
struct ModeQuickControlsTests {
    static func mode(_ number: Int32, _ w: Int, _ h: Int, hiDPI: Bool, hz: Double, vrr: Bool = false) -> DisplayMode {
        DisplayMode(modeNumber: number, width: w, height: h, pixelWidth: hiDPI ? w * 2 : w, pixelHeight: hiDPI ? h * 2 : h, scale: hiDPI ? 2 : 1, refreshRate: hz, isVRR: vrr)
    }

    /// 4K 120 Hz TV의 모드 일부 (LG TV 구성을 본뜬 자료).
    static let modes: [DisplayMode] = [
        mode(1, 3840, 2160, hiDPI: false, hz: 120), mode(2, 3840, 2160, hiDPI: false, hz: 60), mode(3, 3840, 2160, hiDPI: false, hz: 30),
        mode(4, 1920, 1080, hiDPI: true, hz: 120), mode(5, 1920, 1080, hiDPI: true, hz: 60),
        mode(6, 2304, 1296, hiDPI: true, hz: 120), mode(7, 2304, 1296, hiDPI: true, hz: 100), mode(8, 2304, 1296, hiDPI: true, hz: 60), mode(9, 2304, 1296, hiDPI: true, hz: 24),
        mode(10, 2304, 1296, hiDPI: false, hz: 120), mode(11, 2304, 1296, hiDPI: false, hz: 60),
        mode(12, 3008, 1692, hiDPI: true, hz: 60),
        mode(13, 1920, 1080, hiDPI: false, hz: 120), mode(14, 1920, 1080, hiDPI: false, hz: 60),
    ]

    @Test func 주사율_목록은_현재_해상도의_모드만_내림차순() throws {
        let current = try #require(Self.modes.first { $0.modeNumber == 8 })
        let options = ModeCatalog.refreshOptions(Self.modes, current: current)
        #expect(options.map(\.modeNumber) == [6, 7, 8, 9])
        #expect(options.map(\.refreshRate) == [120, 100, 60, 24])
        // 같은 논리 해상도의 HiDPI 꺼짐 모드는 포함하지 않음.
        #expect(!options.contains { !$0.isHiDPI })
    }

    @Test func 가변_주사율_모드는_같은_주사율의_앞에() {
        var modes = Self.modes
        modes.append(Self.mode(20, 2304, 1296, hiDPI: true, hz: 120, vrr: true))
        let options = ModeCatalog.refreshOptions(modes, current: modes[5])
        #expect(options.prefix(2).map(\.modeNumber) == [20, 6])
    }

    @Test func HiDPI_전환은_같은_논리_해상도와_가까운_주사율() throws {
        let hiDPI100 = try #require(Self.modes.first { $0.modeNumber == 7 })
        // 2304 x 1296 HiDPI 100 Hz를 끄면 같은 크기의 HiDPI 꺼짐 모드 중 100 Hz에 가장 가까운 120 Hz.
        #expect(ModeCatalog.hiDPICounterpart(Self.modes, current: hiDPI100, nativeWidth: 3840, nativeHeight: 2160)?.modeNumber == 10)
        let lowDPI60 = try #require(Self.modes.first { $0.modeNumber == 11 })
        #expect(ModeCatalog.hiDPICounterpart(Self.modes, current: lowDPI60, nativeWidth: 3840, nativeHeight: 2160)?.modeNumber == 8)
    }

    @Test func 같은_크기가_없으면_켤_때는_백킹이_패널과_같은_모드() throws {
        // 3840 x 2160 (HiDPI 꺼짐)에는 같은 논리 크기의 HiDPI 모드가 없음: 백킹 3840 x 2160인 1920 x 1080 HiDPI.
        let native60 = try #require(Self.modes.first { $0.modeNumber == 2 })
        let target = try #require(ModeCatalog.hiDPICounterpart(Self.modes, current: native60, nativeWidth: 3840, nativeHeight: 2160))
        #expect(target.modeNumber == 5)
        #expect(target.pixelWidth == 3840 && target.isHiDPI)
    }

    @Test func 같은_크기가_없으면_끌_때는_패널_해상도_모드() throws {
        // 3008 x 1692 HiDPI에는 같은 크기의 HiDPI 꺼짐 모드가 없음: 패널 해상도 3840 x 2160.
        let current = try #require(Self.modes.first { $0.modeNumber == 12 })
        #expect(ModeCatalog.hiDPICounterpart(Self.modes, current: current, nativeWidth: 3840, nativeHeight: 2160)?.modeNumber == 2)
    }

    @Test func 패널_해상도_모드도_없으면_넓이가_가장_가까운_모드() throws {
        let modes = [Self.mode(1, 3008, 1692, hiDPI: true, hz: 60), Self.mode(2, 2560, 1440, hiDPI: false, hz: 60), Self.mode(3, 1280, 720, hiDPI: false, hz: 60)]
        #expect(ModeCatalog.hiDPICounterpart(modes, current: modes[0], nativeWidth: 5120, nativeHeight: 2880)?.modeNumber == 2)
    }

    @Test func 반대_상태의_모드가_없으면_대상_없음() {
        let onlyLow = Self.modes.filter { !$0.isHiDPI }
        #expect(ModeCatalog.hiDPICounterpart(onlyLow, current: onlyLow[0], nativeWidth: 3840, nativeHeight: 2160) == nil)
    }

    @Test func 해상도_구성_요약() throws {
        let current = try #require(Self.modes.first { $0.modeNumber == 6 })
        let breakdown = ResolutionBreakdown(mode: current, transmitWidth: 3840, transmitHeight: 2160, transmitRefreshRate: 120)
        #expect(breakdown.logicalText == "2304 x 1296")
        #expect(breakdown.scaleText == "2배 (HiDPI: 1포인트를 2 x 2 픽셀로 그림)")
        #expect(breakdown.renderText == "4608 x 2592 픽셀")
        #expect(breakdown.transmitText == "3840 x 2160 픽셀, 120 Hz")
        #expect(breakdown.transmitNote == "렌더링한 화면을 83%로 축소해 전송")
    }

    @Test func 전송_관계_표기() throws {
        let exact = ResolutionBreakdown(mode: Self.modes[3], transmitWidth: 3840, transmitHeight: 2160, transmitRefreshRate: 120)
        #expect(exact.transmitNote == "렌더링한 화면을 그대로 전송 (1:1, 가장 선명)")
        let upscaled = ResolutionBreakdown(mode: Self.modes[12], transmitWidth: 3840, transmitHeight: 2160, transmitRefreshRate: 120)
        #expect(upscaled.scaleText == "1배 (HiDPI 꺼짐)")
        #expect(upscaled.transmitNote == "렌더링한 화면을 200%로 확대해 전송 (흐리게 보일 수 있음)")
        let unknown = ResolutionBreakdown(mode: Self.modes[0])
        #expect(unknown.transmitText == nil && unknown.transmitNote == nil)
    }
}
