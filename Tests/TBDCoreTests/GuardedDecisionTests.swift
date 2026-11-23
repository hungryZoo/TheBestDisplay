import Foundation
import Testing
@testable import TBDCore

/// TC-AGT-004: 확인 대기 중인 변경에 전하는 결정 파일.
@Suite("TC-AGT-004 변경 결정 파일")
struct GuardedDecisionTests {
    @Test func 기록과_한_번_읽기() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("tbd-decision-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = GuardedDecisionStore(fileURL: folder.appendingPathComponent("pending-decision"))
        #expect(store.take() == nil)
        try store.write(.keep)
        #expect(store.take() == .keep)
        // 읽으면 파일 삭제.
        #expect(store.take() == nil)
        try store.write(.revert)
        #expect(store.take() == .revert)
        // 나중에 쓴 결정이 앞의 결정을 대체.
        try store.write(.keep)
        try store.write(.revert)
        #expect(store.take() == .revert)
    }

    @Test func 해석할_수_없는_내용과_정리() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("tbd-decision-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let store = GuardedDecisionStore(fileURL: folder.appendingPathComponent("pending-decision"))
        try Data("아무 글".utf8).write(to: store.fileURL)
        #expect(store.take() == nil)
        #expect(!FileManager.default.fileExists(atPath: store.fileURL.path))
        // 앞뒤 공백과 대문자는 허용.
        try Data(" KEEP\n".utf8).write(to: store.fileURL)
        #expect(store.take() == .keep)
        try store.write(.keep)
        store.clear()
        #expect(store.take() == nil)
    }
}
