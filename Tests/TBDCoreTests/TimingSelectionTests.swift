import Foundation
import Testing
@testable import TBDCore

/// TC-COL-008: 연결 수준 타이밍 직접 선택의 계획.
@Suite("TC-COL-008 타이밍 직접 선택 계획")
struct TimingSelectionTests {
    @Test func 명령행_지정_해석() throws {
        let info = try SignalFixture.lgTV()
        // 실측 픽스처: 3840x2160의 59.94 Hz는 ID 60, 60 Hz는 ID 61(가상 형식 ID 33 제외), 120 Hz는 ID 96.
        #expect(TimingSelection.resolve("3840x2160@59.94", in: info.timings)?.id == 60)
        #expect(TimingSelection.resolve("3840x2160@60", in: info.timings)?.id == 61)
        #expect(TimingSelection.resolve("id:60", in: info.timings)?.id == 60)
        #expect(TimingSelection.resolve("1920x1080@119.88", in: info.timings)?.id == 84)
        #expect(TimingSelection.resolve("3840x2160@75", in: info.timings) == nil)
        #expect(TimingSelection.resolve("id:9999", in: info.timings) == nil)
        #expect(TimingSelection.resolve("3840x2160", in: info.timings) == nil)
    }

    @Test func 서술로_타이밍_다시_찾기() throws {
        let info = try SignalFixture.lgTV()
        let ntsc = try #require(info.timings.first { $0.id == 60 })
        let descriptor = TimingDescriptor(ntsc)
        #expect(abs(descriptor.refreshRate - 59.94) < 0.001)
        #expect(descriptor.find(in: info.timings)?.id == 60)
        // 60 Hz 서술은 가상 형식(ID 33)이 아닌 ID 61.
        #expect(TimingDescriptor(hActive: 3840, vActive: 2160, refreshRate: 60).find(in: info.timings)?.id == 61)
        #expect(TimingDescriptor(hActive: 3840, vActive: 2160, refreshRate: 75).find(in: info.timings) == nil)
    }

    @Test func 대상_타이밍의_색_모드_선택() throws {
        // 현재: 3840x2160 120 Hz, 색 ID 122 (YCbCr 4:2:2, 12 bpc, PQ).
        let info = try SignalFixture.lgTV()
        let current = try #require(info.currentColor)
        let target = try #require(TimingSelection.resolve("3840x2160@59.94", in: info.timings))
        let color = try TimingSelection.plan(signal: info, target: target).get()
        #expect(!color.isVirtual)
        #expect(target.colorModes.contains { $0.id == color.id })
        // 같은 서술이 있으면 그것을, 없으면 같은 전달 함수를 유지.
        if target.colorModes.contains(where: { !$0.isVirtual && $0.descriptor == current.descriptor }) {
            #expect(color.descriptor == current.descriptor)
        } else {
            #expect(color.eotf == current.eotf)
        }
    }

    @Test func 거부_사유() throws {
        let info = try SignalFixture.lgTV()
        let currentTiming = try #require(info.currentTiming)
        #expect(TimingSelection.plan(signal: info, target: currentTiming) == .failure(.alreadyCurrent))
        var unknown = info
        unknown.currentColorID = nil
        let other = try #require(info.timings.first { $0.id == 60 })
        #expect(TimingSelection.plan(signal: unknown, target: other) == .failure(.unknownCurrentMode))
        var empty = other
        empty.colorModes = empty.colorModes.filter(\.isVirtual)
        #expect(TimingSelection.plan(signal: info, target: empty) == .failure(.noColorMode))
    }
}
