import Foundation

/// 디스플레이별 최대 휘도 기준값 (cd/m²): 밝기 비율을 휘도로 환산하는 데 사용. (PRD-BRT-010, SRS-BRT-007)
/// 휘도를 직접 읽을 수 없는 디스플레이는 사용자가 지정한 값, 없으면 EDID가 알린 최대 휘도를 씀.
public struct LuminanceReferenceStore: Sendable {
    public var fileURL: URL

    public init(fileURL: URL) { self.fileURL = fileURL }

    public static var standard: LuminanceReferenceStore {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return LuminanceReferenceStore(fileURL: base.appendingPathComponent("TheBestDisplay", isDirectory: true).appendingPathComponent("luminance-reference.json"))
    }

    /// 지정 가능한 범위 (cd/m²).
    public static let range = 10.0...10000.0

    static func key(for identity: DisplayIdentity) -> String { ModeFavoritesStore.key(for: identity) }

    func loadAll() -> [String: Double] {
        guard let data = try? Data(contentsOf: fileURL) else { return [:] }
        return (try? JSONDecoder().decode([String: Double].self, from: data)) ?? [:]
    }

    /// 사용자가 지정한 최대 휘도. 없으면 nil.
    public func userValue(for identity: DisplayIdentity) -> Double? {
        loadAll()[Self.key(for: identity)]
    }

    /// 지정 또는 해제(nil). 범위 밖 값은 거부.
    public func set(_ value: Double?, for identity: DisplayIdentity) throws {
        if let value, !Self.range.contains(value) { throw LuminanceReferenceError.outOfRange }
        var all = loadAll()
        all[Self.key(for: identity)] = value
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(all).write(to: fileURL, options: .atomic)
    }

    /// 환산에 쓸 최대 휘도와 출처. 사용자 지정값이 EDID 값보다 우선.
    public func reference(for identity: DisplayIdentity, edidMaximum: Double?) -> LuminanceReference? {
        if let user = userValue(for: identity) { return LuminanceReference(maximumNits: user, source: .user) }
        if let edidMaximum, edidMaximum > 0 { return LuminanceReference(maximumNits: edidMaximum, source: .edid) }
        return nil
    }
}

public enum LuminanceReferenceError: Error, LocalizedError {
    case outOfRange

    public var errorDescription: String? {
        "최대 휘도는 \(Int(LuminanceReferenceStore.range.lowerBound))-\(Int(LuminanceReferenceStore.range.upperBound)) cd/m² 범위"
    }
}

public struct LuminanceReference: Codable, Hashable, Sendable {
    public enum Source: String, Codable, Sendable {
        case user, edid

        public var title: String { self == .user ? "사용자 지정" : "EDID" }
    }

    public var maximumNits: Double
    public var source: Source

    public init(maximumNits: Double, source: Source) {
        self.maximumNits = maximumNits
        self.source = source
    }

    /// 밝기 비율(0-1)의 추정 휘도. 밝기 비율과 휘도가 비례한다고 가정한 값.
    public func estimatedNits(level: Double) -> Double {
        maximumNits * min(max(level, 0), 1)
    }

    /// 예: "추정 120 cd/m² (최대 300 cd/m², 사용자 지정)"
    public func summary(level: Double) -> String {
        "추정 \(BacklightLuminance.format(estimatedNits(level: level))) cd/m² (최대 \(BacklightLuminance.format(maximumNits)) cd/m², \(source.title))"
    }
}
