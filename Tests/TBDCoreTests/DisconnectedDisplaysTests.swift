import Foundation
import Testing
@testable import TBDCore

/// TC-ARR-011: 연결 해제 기록의 갱신 규칙과 파일 저장.
@Suite("TC-ARR-011 연결 해제 기록")
struct DisconnectedDisplaysTests {
    static let base = Date(timeIntervalSince1970: 1_800_000_000)
    static let tv = DisconnectedDisplayRecord(displayID: 3, name: "LG TV SSCR2", isBuiltin: false, disconnectedAt: base)
    static let legion = DisconnectedDisplayRecord(displayID: 2, name: "Legion 27-10", isBuiltin: false, disconnectedAt: base.addingTimeInterval(60))

    @Test func 기록_추가와_교체() {
        var list = DisconnectedDisplayList.remembering(Self.legion, in: [])
        list = DisconnectedDisplayList.remembering(Self.tv, in: list)
        // 해제 시각 순서.
        #expect(list.map(\.displayID) == [3, 2])
        // 같은 ID는 교체.
        let renamed = DisconnectedDisplayRecord(displayID: 3, name: "거실 TV", isBuiltin: false, disconnectedAt: Self.base.addingTimeInterval(120))
        list = DisconnectedDisplayList.remembering(renamed, in: list)
        #expect(list.map(\.name) == ["Legion 27-10", "거실 TV"])
    }

    @Test func 현재_상태와_대조() {
        let list = [Self.tv, Self.legion]
        // 다시 온라인이 된 디스플레이는 제거.
        #expect(DisconnectedDisplayList.reconciled(list, online: [1, 3], known: [1, 2, 3]) == [Self.legion])
        // 윈도 서버가 더 이상 알지 못하는 디스플레이는 제거.
        #expect(DisconnectedDisplayList.reconciled(list, online: [1], known: [1, 3]) == [Self.tv])
        #expect(DisconnectedDisplayList.reconciled(list, online: [1], known: [1, 2, 3]) == list)
        #expect(DisconnectedDisplayList.reconciled(list, online: [1], known: []).isEmpty)
    }

    @Test func 재연결_대상_지정() {
        let list = [Self.tv, Self.legion]
        #expect(DisconnectedDisplayList.resolve("id:2", in: list) == Self.legion)
        #expect(DisconnectedDisplayList.resolve("3", in: list) == Self.tv)
        #expect(DisconnectedDisplayList.resolve("legion", in: list) == Self.legion)
        #expect(DisconnectedDisplayList.resolve("id:9", in: list) == nil)
        #expect(DisconnectedDisplayList.resolve("없는이름", in: list) == nil)
        // 이름 일부가 여러 기록과 일치하면 선택하지 않음.
        #expect(DisconnectedDisplayList.resolve("l", in: list) == nil)
    }

    @Test func 파일_저장과_삭제() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("tbd-disconnected-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = DisconnectedDisplayStore(fileURL: folder.appendingPathComponent("disconnected.json"))
        #expect(store.load().isEmpty)
        try store.remember(Self.tv)
        try store.remember(Self.legion)
        #expect(store.load() == [Self.tv, Self.legion])
        // 대조 결과가 바뀌면 파일도 갱신.
        #expect(store.current(online: [1, 3], known: [1, 2, 3]) == [Self.legion])
        #expect(store.load() == [Self.legion])
        // 빈 목록이 되면 파일 삭제.
        #expect(store.current(online: [1, 2, 3], known: [1, 2, 3]).isEmpty)
        #expect(!FileManager.default.fileExists(atPath: store.fileURL.path))
        // 손상된 파일은 빈 목록.
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("손상".utf8).write(to: store.fileURL)
        #expect(store.load().isEmpty)
    }
}
