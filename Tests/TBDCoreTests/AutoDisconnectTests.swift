import Foundation
import Testing
@testable import TBDCore

/// TC-ARR-008: 내장 자동 해제의 판단과 상태 파일.
@Suite("TC-ARR-008 내장 자동 해제 판단")
struct AutoDisconnectTests {
    typealias S = AutoDisconnectPolicy.DisplayState
    static let builtin = S(id: 1, isBuiltin: true, isVirtual: false)
    static let tv = S(id: 2, isBuiltin: false, isVirtual: false)
    static let virtual = S(id: 9, isBuiltin: false, isVirtual: true)

    @Test func 실제_외장이_온라인이면_내장_해제() {
        #expect(AutoDisconnectPolicy.decide(enabled: true, online: [Self.builtin, Self.tv], disconnectedBuiltin: nil) == .disconnectBuiltin(1))
        // 설정이 꺼져 있으면 아무것도 하지 않음.
        #expect(AutoDisconnectPolicy.decide(enabled: false, online: [Self.builtin, Self.tv], disconnectedBuiltin: nil) == .none)
    }

    @Test func 가상_디스플레이만_있으면_해제하지_않음() {
        #expect(AutoDisconnectPolicy.decide(enabled: true, online: [Self.builtin, Self.virtual], disconnectedBuiltin: nil) == .none)
        #expect(AutoDisconnectPolicy.decide(enabled: true, online: [Self.builtin], disconnectedBuiltin: nil) == .none)
        // 내장이 없는 기기.
        #expect(AutoDisconnectPolicy.decide(enabled: true, online: [Self.tv], disconnectedBuiltin: nil) == .none)
    }

    @Test func 외장이_사라지면_내장_재연결() {
        // 해제 상태에서 외장 분리: 온라인 디스플레이가 없어도 재연결.
        #expect(AutoDisconnectPolicy.decide(enabled: true, online: [], disconnectedBuiltin: 1) == .reconnectBuiltin(1))
        // 가상 디스플레이만 남은 경우에도 재연결.
        #expect(AutoDisconnectPolicy.decide(enabled: true, online: [Self.virtual], disconnectedBuiltin: 1) == .reconnectBuiltin(1))
        // 외장이 그대로면 유지.
        #expect(AutoDisconnectPolicy.decide(enabled: true, online: [Self.tv], disconnectedBuiltin: 1) == .none)
    }

    @Test func 설정을_끄면_내장_재연결() {
        #expect(AutoDisconnectPolicy.decide(enabled: false, online: [Self.tv], disconnectedBuiltin: 1) == .reconnectBuiltin(1))
        // 이미 온라인이면 할 일 없음.
        #expect(AutoDisconnectPolicy.decide(enabled: false, online: [Self.builtin, Self.tv], disconnectedBuiltin: 1) == .none)
    }

    @Test func 상태_파일() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("tbd-auto-\(UUID().uuidString).json")
        let store = AutoDisconnectStore(fileURL: url)
        #expect(store.load() == AutoDisconnectStore.State())
        try store.save(.init(enabled: true, disconnectedBuiltin: 1))
        #expect(store.load() == .init(enabled: true, disconnectedBuiltin: 1))
        // 기본 상태는 파일 삭제.
        try store.save(.init())
        #expect(!FileManager.default.fileExists(atPath: url.path))
        try Data("손상".utf8).write(to: url)
        #expect(store.load() == .init())
        try FileManager.default.removeItem(at: url)
    }
}
