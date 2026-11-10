import Foundation
import Testing
@testable import TBDCore

/// TC-MOD-010: 렌더링 한계, 슬라이더 단계, 즐겨찾기 저장.
@Suite("TC-MOD-010 렌더링 한계, 슬라이더, 즐겨찾기")
struct ModeExtrasTests {
    static func mode(_ number: Int32, _ w: Int, _ h: Int, scale: Double, hz: Double, vrr: Bool = false) -> DisplayMode {
        DisplayMode(modeNumber: number, width: w, height: h, pixelWidth: Int(Double(w) * scale), pixelHeight: Int(Double(h) * scale), scale: scale, refreshRate: hz, isVRR: vrr)
    }

    static let modes: [DisplayMode] = [
        mode(1, 3840, 2160, scale: 1, hz: 60), mode(2, 3840, 2160, scale: 1, hz: 120),
        mode(3, 1920, 1080, scale: 2, hz: 60), mode(4, 1920, 1080, scale: 2, hz: 120), mode(5, 1920, 1080, scale: 2, hz: 120, vrr: true),
        mode(6, 2560, 1440, scale: 2, hz: 60),
        mode(7, 1280, 720, scale: 2, hz: 60), mode(8, 1280, 720, scale: 2, hz: 120),
        mode(9, 1600, 1200, scale: 2, hz: 60),
        mode(10, 1920, 1080, scale: 1, hz: 60),
    ]

    @Test func 렌더링_한계는_최대_백킹과_가장_큰_HiDPI_모드() throws {
        let limits = try #require(ModeCatalog.renderingLimits(Self.modes))
        #expect(limits.maxPixelWidth == 5120 && limits.maxPixelHeight == 2880)
        #expect(limits.largestHiDPILogicalWidth == 2560 && limits.largestHiDPILogicalHeight == 1440)
        #expect(limits.modeCount == 10 && limits.hiDPIModeCount == 7)
        #expect(limits.summary == "최대 백킹 5120 x 2880 픽셀, 가장 큰 HiDPI 모드 2560 x 1440 (백킹 5120 x 2880), 모드 10개 중 HiDPI 7개")
        #expect(ModeCatalog.renderingLimits([]) == nil)
        // HiDPI 모드가 없으면 최대 백킹만.
        let lowOnly = try #require(ModeCatalog.renderingLimits([Self.modes[0]]))
        #expect(lowOnly.largestHiDPILogicalWidth == nil)
        #expect(lowOnly.summary == "최대 백킹 3840 x 2160 픽셀, 모드 1개 중 HiDPI 0개")
    }

    @Test func 슬라이더_단계는_같은_배율과_종횡비를_폭_순으로() {
        // 현재: 1920x1080 HiDPI 120 Hz (고정 주사율).
        let steps = ModeCatalog.sliderSteps(Self.modes, current: Self.modes[3])
        #expect(steps.map(\.width) == [1280, 1920, 2560])
        // 주사율이 같은 모드 우선, 없으면 가장 가까운 주사율. 가변 주사율 여부가 같은 모드 우선.
        #expect(steps.map(\.modeNumber) == [8, 4, 6])
        // 4:3 해상도와 배율이 다른 모드는 제외.
        #expect(!steps.contains { $0.width == 1600 })
        let lowDPI = ModeCatalog.sliderSteps(Self.modes, current: Self.modes[0])
        #expect(lowDPI.map(\.modeNumber) == [10, 1])
        let vrr = ModeCatalog.sliderSteps(Self.modes, current: Self.modes[4])
        #expect(vrr.first { $0.width == 1920 }?.modeNumber == 5)
    }

    @Test func 즐겨찾기_저장은_디스플레이별로_구분() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("tbd-favorites-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = ModeFavoritesStore(fileURL: url)
        let a = DisplayIdentity(displayID: 2, uuid: nil, vendorID: 0x1E6D, productID: 0xC0C8, serialNumber: 1, name: "A", isBuiltin: false)
        let b = DisplayIdentity(displayID: 3, uuid: nil, vendorID: 0x1E6D, productID: 0xC0C8, serialNumber: 2, name: "B", isBuiltin: false)
        #expect(ModeFavoritesStore.key(for: a) == "1e6d-c0c8-1")
        #expect(store.favorites(for: a).isEmpty)

        let first = Self.modes[3].descriptor, second = Self.modes[5].descriptor
        #expect(try store.add(first, for: a))
        #expect(try store.add(second, for: a))
        #expect(try !store.add(first, for: a))
        #expect(try store.add(first, for: b))
        #expect(store.favorites(for: a) == [first, second])
        #expect(store.favorites(for: b) == [first])
        #expect(store.contains(second, for: a) && !store.contains(second, for: b))

        #expect(try store.remove(first, for: a))
        #expect(try !store.remove(first, for: a))
        #expect(store.favorites(for: a) == [second])
        // 디스플레이 ID가 바뀌어도 같은 제품과 일련번호면 같은 목록.
        var moved = a
        moved.displayID = 9
        #expect(store.favorites(for: moved) == [second])
        // 저장한 서술자로 모드 목록에서 다시 찾기.
        #expect(second.find(in: Self.modes)?.modeNumber == 6)
        try Data("손상".utf8).write(to: url)
        #expect(store.favorites(for: a).isEmpty)
    }
}

extension ModeExtrasTests {
    @Test func 슬라이더는_반올림으로_비율이_조금_다른_스케일_해상도_포함() {
        // 내장 패널의 스케일 해상도: 비율이 정확히 같지 않음 (1.5397, 1.5398, 1.5400).
        let scaled = [
            Self.mode(1, 1512, 982, scale: 2, hz: 120, vrr: true),
            Self.mode(2, 1800, 1169, scale: 2, hz: 120, vrr: true),
            Self.mode(3, 1147, 745, scale: 2, hz: 120, vrr: true),
            Self.mode(4, 1512, 945, scale: 2, hz: 120, vrr: true),
        ]
        let steps = ModeCatalog.sliderSteps(scaled, current: scaled[0])
        #expect(steps.map(\.width) == [1147, 1512, 1800])
    }
}

/// TC-MOD-012: notch 모드 쌍 판정.
@Suite("TC-MOD-012 notch 모드 쌍")
struct NotchModeTests {
    static let modes: [DisplayMode] = [
        ModeExtrasTests.mode(1, 1512, 982, scale: 2, hz: 120, vrr: true), ModeExtrasTests.mode(2, 1512, 945, scale: 2, hz: 120, vrr: true),
        ModeExtrasTests.mode(3, 1512, 982, scale: 2, hz: 60), ModeExtrasTests.mode(4, 1512, 945, scale: 2, hz: 60),
        ModeExtrasTests.mode(5, 1800, 1169, scale: 2, hz: 120, vrr: true), ModeExtrasTests.mode(6, 1800, 1125, scale: 2, hz: 120, vrr: true),
        ModeExtrasTests.mode(7, 1920, 1080, scale: 2, hz: 60), ModeExtrasTests.mode(8, 1920, 1200, scale: 2, hz: 60),
    ]

    @Test func 전체_모드와_notch_아래_모드의_쌍() throws {
        let fromFull = try #require(ModeCatalog.notchPair(Self.modes, current: Self.modes[0]))
        #expect(fromFull.full.modeNumber == 1 && fromFull.belowNotch.modeNumber == 2)
        let fromBelow = try #require(ModeCatalog.notchPair(Self.modes, current: Self.modes[1]))
        #expect(fromBelow.full.modeNumber == 1 && fromBelow.belowNotch.modeNumber == 2)
        // 주사율과 가변 주사율 여부가 같은 모드끼리 짝.
        #expect(ModeCatalog.notchPair(Self.modes, current: Self.modes[2])?.belowNotch.modeNumber == 4)
        #expect(ModeCatalog.notchPair(Self.modes, current: Self.modes[5])?.full.modeNumber == 5)
    }

    @Test func notch가_없는_디스플레이는_쌍_없음() {
        // 1920x1080(16:9)과 1920x1200(16:10)은 높이 차이가 notch 범위를 넘음.
        #expect(ModeCatalog.notchPair(Self.modes, current: Self.modes[6]) == nil)
        #expect(ModeCatalog.notchPair(Self.modes, current: Self.modes[7]) == nil)
        #expect(ModeCatalog.notchPair([Self.modes[0]], current: Self.modes[0]) == nil)
    }
}
