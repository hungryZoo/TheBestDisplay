import Foundation
import Testing
import TBDCore
@testable import TBDPlatform

/// TC-MOD-006: 오버라이드 파일 읽기와 쓰기 (임시 폴더 대상).
@Suite("TC-MOD-006 오버라이드 파일 서비스")
struct DisplayOverrideServiceTests {
    static func temporaryRoot() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("tbd-override-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test func 쓰기_읽기_삭제() throws {
        let service = DisplayOverrideService(root: try Self.temporaryRoot())
        var file = try service.read(vendorID: 0x1E6D, productID: 0xC0C8)
        #expect(file.entries.isEmpty)
        try file.add(logicalWidth: 2560, logicalHeight: 1440)
        try service.write(file)

        let url = service.url(vendorID: 0x1E6D, productID: 0xC0C8)
        #expect(url.path.hasSuffix("DisplayVendorID-1e6d/DisplayProductID-c0c8"))
        #expect(FileManager.default.fileExists(atPath: url.path))
        var loaded = try service.read(vendorID: 0x1E6D, productID: 0xC0C8)
        #expect(loaded.entries.map(\.label) == ["2560 x 1440 HiDPI (백킹 5120 x 2880)"])

        // 항목이 모두 없어지면 파일 삭제.
        try loaded.remove(logicalWidth: 2560, logicalHeight: 1440)
        try service.write(loaded)
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test func 쓰기_권한이_없으면_설치_명령_반환() throws {
        let root = try Self.temporaryRoot()
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: root.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: root.path) }
        let service = DisplayOverrideService(root: root)
        var file = DisplayOverrideFile(vendorID: 0x1E6D, productID: 0xC0C8)
        try file.add(logicalWidth: 2560, logicalHeight: 1440)
        do {
            try service.write(file)
            Issue.record("권한 오류 기대")
        } catch DisplayOverrideService.ServiceError.needsPrivilege(let staged, let commands) {
            let stagedURL = try #require(staged)
            #expect(FileManager.default.fileExists(atPath: stagedURL.path))
            #expect(commands.count == 3)
            #expect(commands[0].hasPrefix("mkdir -p '"))
            #expect(commands[1].contains(stagedURL.path) && commands[1].contains("DisplayVendorID-1e6d/DisplayProductID-c0c8"))
            #expect(commands[2].hasPrefix("chmod 644 '"))
            // 준비한 파일은 올바른 plist.
            let decoded = DisplayOverrideFile.decode(try Data(contentsOf: stagedURL), vendorID: 0x1E6D, productID: 0xC0C8)
            #expect(decoded?.entries.count == 1)
        }
        #expect(!FileManager.default.fileExists(atPath: service.url(vendorID: 0x1E6D, productID: 0xC0C8).path))
    }

    @Test func 해석할_수_없는_파일은_오류() throws {
        let service = DisplayOverrideService(root: try Self.temporaryRoot())
        let url = service.url(vendorID: 1, productID: 2)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("plist 아님".utf8).write(to: url)
        #expect(throws: DisplayOverrideService.ServiceError.self) { try service.read(vendorID: 1, productID: 2) }
    }

    @Test func 경로의_작은따옴표_처리() {
        #expect(DisplayOverrideService.quoted("/a/b c") == "'/a/b c'")
        #expect(DisplayOverrideService.quoted("/a/it's") == "'/a/it'\\''s'")
    }
}
