import Foundation
import Testing
@testable import TBDCore

/// TC-VRT-001 일부: 가상 디스플레이 구성과 저장 (순수 로직).
@Suite("TC-VRT-001 가상 디스플레이 구성")
struct VirtualDisplayConfigTests {
    @Test func 해상도와_물리_크기() {
        let config = VirtualDisplayConfig(name: "가상", width: 1920, height: 1080, hiDPI: true)
        #expect((config.pixelWidth, config.pixelHeight) == (3840, 2160))
        #expect(config.label == "1920 x 1080 HiDPI, 60 Hz")
        #expect(abs(config.sizeInMillimeters.width - 443.3) < 0.1)
        #expect(VirtualDisplayConfig(name: "가상", width: 1920, height: 1080, hiDPI: false).pixelWidth == 1920)
        #expect(config.validationIssues().isEmpty)
    }

    @Test func 일련번호는_구성_식별자에_고정() {
        let id = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let a = VirtualDisplayConfig(id: id, name: "A", width: 1920, height: 1080, hiDPI: true)
        let b = VirtualDisplayConfig(id: id, name: "B", width: 2560, height: 1440, hiDPI: false)
        #expect(a.serialNumber == b.serialNumber)
        #expect(a.serialNumber != VirtualDisplayConfig(name: "C", width: 1920, height: 1080, hiDPI: true).serialNumber)
    }

    @Test func 유효성_검사() {
        #expect(VirtualDisplayConfig(name: " ", width: 1920, height: 1080, hiDPI: true).validationIssues() == ["이름이 비어 있음"])
        #expect(VirtualDisplayConfig(name: "가상", width: 100, height: 100, hiDPI: false).validationIssues().count == 2)
        // HiDPI 4096 폭은 백킹 8192픽셀로 상한 초과.
        #expect(VirtualDisplayConfig(name: "가상", width: 4096, height: 2160, hiDPI: true).validationIssues().contains { $0.contains("백킹 폭 8192픽셀") })
        #expect(VirtualDisplayConfig(name: "가상", width: 4096, height: 2160, hiDPI: false).validationIssues().isEmpty)
        #expect(VirtualDisplayConfig(name: "가상", width: 1920, height: 1080, hiDPI: true, refreshRate: 10).validationIssues() == ["주사율은 24-240 Hz 범위"])
    }

    @Test func 저장과_복원() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("tbd-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = VirtualDisplayStore(fileURL: dir.appendingPathComponent("nested/virtual-displays.json"))
        #expect(store.load().isEmpty)
        let configs = [
            VirtualDisplayConfig(name: "작업용", width: 2560, height: 1440, hiDPI: true, refreshRate: 120, restoreAtLaunch: true),
            VirtualDisplayConfig(name: "녹화용", width: 1920, height: 1080, hiDPI: false),
        ]
        try store.save(configs)
        #expect(store.load() == configs)
        #expect(store.load().filter(\.restoreAtLaunch).map(\.name) == ["작업용"])
        try Data("손상".utf8).write(to: store.fileURL)
        #expect(store.load().isEmpty)
    }
}

/// TC-VRT-002 일부: HiDPI 스케일링 계획 (순수 로직).
@Suite("TC-VRT-002 HiDPI 스케일링 계획")
struct HiDPIScalingTests {
    @Test func 원본_3840x2160의_후보() {
        let presets = HiDPIScaling.presets(nativeWidth: 3840, nativeHeight: 2160)
        #expect(presets.map(\.width) == [1920, 2304, 2560, 2880, 3072, 3456, 3840])
        #expect(presets.first { $0.width == 2560 }?.height == 1440)
        #expect(presets.first { $0.width == 3840 }?.height == 2160)
        // 종횡비 유지, 백킹 폭 상한 이내.
        for preset in presets {
            #expect(abs(Double(preset.height) / Double(preset.width) - 0.5625) < 0.002)
            #expect(preset.width * 2 <= VirtualDisplayConfig.maxPixelWidth)
        }
    }

    @Test func 폭이_큰_패널은_상한_초과_후보_제외() {
        let presets = HiDPIScaling.presets(nativeWidth: 5120, nativeHeight: 2880)
        #expect(presets.allSatisfy { $0.width * 2 <= 7680 })
        #expect(presets.map(\.width).contains(2560))
        #expect(!presets.map(\.width).contains(5120))
        #expect(HiDPIScaling.presets(nativeWidth: 0, nativeHeight: 0).isEmpty)
    }

    @Test func 스케일링_구성() {
        let config = HiDPIScaling.config(for: RegistryFixture.lgTV, logicalWidth: 2560, logicalHeight: 1440)
        #expect(config.name == "LG TV SSCR2 HiDPI")
        #expect(config.hiDPI)
        #expect((config.pixelWidth, config.pixelHeight) == (5120, 2880))
        #expect(config.refreshRate == 120)
        #expect(config.validationIssues().isEmpty)
    }

    @Test func 선명도_설명() {
        #expect(HiDPIScaling.sharpnessNote(logicalWidth: 1920, nativeWidth: 3840) == "패널 화소와 1대1 대응")
        #expect(HiDPIScaling.sharpnessNote(logicalWidth: 2560, nativeWidth: 3840) == "5120픽셀로 그린 뒤 패널 3840픽셀로 축소 (75%)")
        #expect(HiDPIScaling.sharpnessNote(logicalWidth: 1600, nativeWidth: 3840) == "3200픽셀로 그린 뒤 패널 3840픽셀로 확대 (120%)")
    }
}
