import Foundation
import TBDCore

/// 디스플레이 오버라이드 파일 읽기와 쓰기. (SRS-MOD-004)
///
/// 대상 폴더는 root 소유라 쓰기에 관리자 권한 필요. 권한이 없으면 임시 파일에 준비하고 설치 명령을 돌려줌.
/// 반영 시점은 디스플레이 재연결 또는 재시동 (조사 문서 2.2절).
public struct DisplayOverrideService: Sendable {
    public var root: URL

    public init(root: URL = URL(fileURLWithPath: DisplayOverrideFile.defaultRoot)) { self.root = root }

    public enum ServiceError: Error, LocalizedError {
        /// 쓰기 권한 없음. `staged`는 준비한 파일, `commands`는 관리자 권한으로 차례로 실행할 셸 명령.
        case needsPrivilege(staged: URL?, commands: [String])
        case unreadable(String)

        public var errorDescription: String? {
            switch self {
            case .needsPrivilege(_, let commands): "관리자 권한 필요. 실행할 명령: \(commands.joined(separator: " && "))"
            case .unreadable(let path): "오버라이드 파일 형식을 해석할 수 없음: \(path)"
            }
        }
    }

    public func url(vendorID: UInt32, productID: UInt32) -> URL {
        root.appendingPathComponent(DisplayOverrideFile.relativePath(vendorID: vendorID, productID: productID))
    }

    /// 현재 파일. 없으면 빈 내용.
    public func read(vendorID: UInt32, productID: UInt32) throws -> DisplayOverrideFile {
        let url = url(vendorID: vendorID, productID: productID)
        guard let data = try? Data(contentsOf: url) else { return DisplayOverrideFile(vendorID: vendorID, productID: productID) }
        guard let file = DisplayOverrideFile.decode(data, vendorID: vendorID, productID: productID) else { throw ServiceError.unreadable(url.path) }
        return file
    }

    static func quoted(_ path: String) -> String { "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'" }

    /// 파일 쓰기. 항목과 다른 키가 모두 없으면 파일 삭제.
    /// 권한이 없으면 `needsPrivilege` 오류로 설치 명령 반환.
    public func write(_ file: DisplayOverrideFile) throws {
        let target = url(vendorID: file.vendorID, productID: file.productID)
        let manager = FileManager.default
        if file.entries.isEmpty, !file.hasOtherKeys {
            guard manager.fileExists(atPath: target.path) else { return }
            do {
                try manager.removeItem(at: target)
            } catch {
                throw ServiceError.needsPrivilege(staged: nil, commands: ["rm \(Self.quoted(target.path))"])
            }
            return
        }
        let data = try file.encode()
        do {
            try manager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: target, options: .atomic)
        } catch {
            let staged = manager.temporaryDirectory.appendingPathComponent("tbd-override-\(String(format: "%x-%x", file.vendorID, file.productID)).plist")
            try data.write(to: staged, options: .atomic)
            let folder = target.deletingLastPathComponent().path
            throw ServiceError.needsPrivilege(staged: staged, commands: [
                "mkdir -p \(Self.quoted(folder))",
                "cp \(Self.quoted(staged.path)) \(Self.quoted(target.path))",
                "chmod 644 \(Self.quoted(target.path))",
            ])
        }
    }
}
