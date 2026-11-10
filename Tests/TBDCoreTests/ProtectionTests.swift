import Foundation
import Testing
@testable import TBDCore

/// TC-PRF-003: 구성 보호의 차이 산출, 설정 저장, 반복 복원 방지.
@Suite("TC-PRF-003 구성 보호")
struct ProtectionTests {
    static func display(id: UInt32, serial: UInt32, main: Bool, x: Int) -> DisplaySummary {
        DisplaySummary(
            identity: DisplayIdentity(displayID: id, uuid: "UUID-\(serial)", vendorID: 0x1E6D, productID: 0xC0C8, serialNumber: serial, name: "모니터 \(serial)", isBuiltin: false),
            isMain: main, isActive: true, mirrorsDisplayID: nil,
            pointWidth: 1920, pointHeight: 1080, pixelWidth: 3840, pixelHeight: 2160, refreshRate: 60,
            rotationDegrees: 0, originX: x, originY: 0, physicalWidthMM: 600, physicalHeightMM: 340
        )
    }

    static func entry(_ display: DisplaySummary, width: Int = 1920, brightness: Double? = nil, rotation: Int = 0) -> DisplayProfileEntry {
        DisplayProfileEntry(
            ref: DisplayRef(display.identity),
            mode: ModeDescriptor(width: width, height: width * 9 / 16, isHiDPI: true, refreshRate: 60),
            color: nil, hdrEnabled: nil, rotation: rotation,
            originX: display.originX, originY: display.originY, isMain: display.isMain, mirrorOf: nil, brightness: brightness
        )
    }

    @Test func 보호_대상_단계만_차이로_산출() {
        let a = Self.display(id: 1, serial: 1, main: true, x: 0)
        let b = Self.display(id: 2, serial: 2, main: false, x: 1920)
        let saved = DisplayProfile(name: "작업", createdAt: Date(), displays: [Self.entry(a, brightness: 0.5), Self.entry(b)])
        // 현재: 두 번째 디스플레이의 해상도와 첫 번째 디스플레이의 밝기가 다름.
        let current = DisplayProfile(name: "현재", createdAt: Date(), displays: [Self.entry(a, brightness: 0.8), Self.entry(b, width: 2560)])
        let setting = ProtectionSetting(profileID: saved.id)
        let steps = setting.deviations(profile: saved, current: current, displays: [a, b])
        #expect(steps.map(\.kind) == [.mode])
        #expect(steps.first?.displayID == 2)
        // 밝기를 보호 대상에 넣으면 밝기 차이도 포함.
        let withBrightness = ProtectionSetting(profileID: saved.id, kinds: [.mode, .brightness])
        #expect(withBrightness.deviations(profile: saved, current: current, displays: [a, b]).map(\.kind) == [.mode, .brightness])
        // 같은 구성이면 차이 없음. 연결되지 않은 디스플레이는 무시.
        #expect(setting.deviations(profile: saved, current: saved, displays: [a, b]).isEmpty)
        #expect(setting.deviations(profile: saved, current: current, displays: [a]).isEmpty)
    }

    @Test func 설정_파일_저장과_삭제() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("tbd-protection-\(UUID().uuidString).json")
        let store = ProtectionStore(fileURL: url)
        #expect(store.load() == nil)
        let setting = ProtectionSetting(profileID: UUID(), kinds: [.mode, .hdr])
        try store.save(setting)
        #expect(store.load() == setting)
        try store.save(nil)
        #expect(store.load() == nil)
        #expect(!FileManager.default.fileExists(atPath: url.path))
        try Data("손상".utf8).write(to: url)
        #expect(store.load() == nil)
        try FileManager.default.removeItem(at: url)
    }

    @Test func 반복_복원은_3회_뒤_일시_중지() {
        var state = ProtectionGuard()
        let start = Date(timeIntervalSince1970: 1000)
        #expect(state.decide(deviationCount: 0, now: start) == .stable)
        #expect(state.decide(deviationCount: 2, now: start) == .restore)
        #expect(state.decide(deviationCount: 1, now: start.addingTimeInterval(5)) == .restore)
        #expect(state.decide(deviationCount: 1, now: start.addingTimeInterval(10)) == .restore)
        guard case .suspended(let reason) = state.decide(deviationCount: 1, now: start.addingTimeInterval(15)) else {
            Issue.record("일시 중지 기대")
            return
        }
        #expect(reason == "60초 안에 3회 복원한 뒤에도 구성이 다시 바뀌어 보호 일시 중지")
        #expect(state.isSuspended)
        // 일시 중지 중에는 차이가 없어도 중지 상태 유지.
        #expect(state.decide(deviationCount: 0, now: start.addingTimeInterval(20)) == .suspended(reason))
        state.resume()
        #expect(state.decide(deviationCount: 1, now: start.addingTimeInterval(25)) == .restore)
    }

    @Test func 시간_창이_지난_시도는_세지_않음() {
        var state = ProtectionGuard()
        let start = Date(timeIntervalSince1970: 1000)
        for offset in [0.0, 30, 59] { #expect(state.decide(deviationCount: 1, now: start.addingTimeInterval(offset)) == .restore) }
        // 첫 시도 후 61초: 창 안의 시도는 2회.
        #expect(state.decide(deviationCount: 1, now: start.addingTimeInterval(61)) == .restore)
        #expect(!state.isSuspended)
        state.suspend("사용자 변경")
        #expect(state.decide(deviationCount: 1, now: start.addingTimeInterval(62)) == .suspended("사용자 변경"))
    }
}
