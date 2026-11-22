import Foundation

/// 이 앱(창 앱과 `tbdctl`)이 논리적으로 연결 해제한 디스플레이 1대의 기록. (PRD-ARR-010, SRS-ARR-008)
public struct DisconnectedDisplayRecord: Codable, Hashable, Sendable, Identifiable {
    public var displayID: UInt32
    public var name: String
    public var isBuiltin: Bool
    public var disconnectedAt: Date

    public var id: UInt32 { displayID }

    public init(displayID: UInt32, name: String, isBuiltin: Bool, disconnectedAt: Date) {
        self.displayID = displayID
        self.name = name
        self.isBuiltin = isBuiltin
        self.disconnectedAt = disconnectedAt
    }
}

/// 연결 해제 기록의 갱신 규칙.
///
/// 윈도 서버의 디스플레이 목록은 케이블을 분리한 디스플레이의 ID도 반환하므로 (spikes 문서 T12)
/// 온라인이 아닌 ID만으로는 논리적 해제를 가려낼 수 없음. 이 앱이 해제한 디스플레이를 따로 기록.
public enum DisconnectedDisplayList {
    /// 기록 추가. 같은 ID의 기존 기록은 교체. 해제 시각 순서로 정렬.
    public static func remembering(_ record: DisconnectedDisplayRecord, in list: [DisconnectedDisplayRecord]) -> [DisconnectedDisplayRecord] {
        (list.filter { $0.displayID != record.displayID } + [record]).sorted { ($0.disconnectedAt, $0.displayID) < ($1.disconnectedAt, $1.displayID) }
    }

    /// 현재 상태와 대조: 다시 온라인이 된 디스플레이와 윈도 서버가 더 이상 알지 못하는 디스플레이는 제거.
    public static func reconciled(_ list: [DisconnectedDisplayRecord], online: [UInt32], known: [UInt32]) -> [DisconnectedDisplayRecord] {
        let online = Set(online), known = Set(known)
        return list.filter { !online.contains($0.displayID) && known.contains($0.displayID) }
    }

    /// 재연결 대상 지정 해석: `id:<번호>`, 숫자, 또는 이름의 일부. 일치가 1개일 때만 반환.
    public static func resolve(_ selector: String, in list: [DisconnectedDisplayRecord]) -> DisconnectedDisplayRecord? {
        let lower = selector.lowercased()
        if let id = UInt32(lower.hasPrefix("id:") ? String(lower.dropFirst(3)) : lower) {
            return list.first { $0.displayID == id }
        }
        let matches = list.filter { $0.name.lowercased().contains(lower) }
        return matches.count == 1 ? matches[0] : nil
    }
}

/// 연결 해제 기록 파일. 창 앱과 `tbdctl`이 같은 파일을 사용.
public struct DisconnectedDisplayStore: Sendable {
    public var fileURL: URL

    public init(fileURL: URL) { self.fileURL = fileURL }

    public static var standard: DisconnectedDisplayStore {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return DisconnectedDisplayStore(fileURL: base.appendingPathComponent("TheBestDisplay", isDirectory: true).appendingPathComponent("disconnected.json"))
    }

    public func load() -> [DisconnectedDisplayRecord] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = try? Data(contentsOf: fileURL), let list = try? decoder.decode([DisconnectedDisplayRecord].self, from: data) else { return [] }
        return list
    }

    /// 저장. 빈 목록이면 파일 삭제.
    public func save(_ list: [DisconnectedDisplayRecord]) throws {
        if list.isEmpty {
            if FileManager.default.fileExists(atPath: fileURL.path) { try FileManager.default.removeItem(at: fileURL) }
            return
        }
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(list).write(to: fileURL, options: .atomic)
    }

    public func remember(_ record: DisconnectedDisplayRecord) throws {
        try save(DisconnectedDisplayList.remembering(record, in: load()))
    }

    /// 현재 상태와 대조한 목록. 바뀌었으면 파일도 갱신.
    public func current(online: [UInt32], known: [UInt32]) -> [DisconnectedDisplayRecord] {
        let stored = load()
        let kept = DisconnectedDisplayList.reconciled(stored, online: online, known: known)
        if kept != stored { try? save(kept) }
        return kept
    }
}
