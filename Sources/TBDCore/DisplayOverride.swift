import Foundation

/// 디스플레이 오버라이드 파일의 스케일 해상도 항목. (PRD-MOD-007, SRS-MOD-004)
///
/// `scale-resolutions` 배열의 항목은 폭과 높이를 4바이트 빅엔디언으로 이은 Data. 뒤에 플래그 4바이트가 붙은 형식도 있음.
/// 이 앱이 추가하는 항목은 논리 해상도의 2배 크기(백킹 크기)를 8바이트로 기록 (조사 문서 2.2절의 Apple Silicon 측정 기록).
public struct ScaleResolutionEntry: Hashable, Sendable, Codable {
    /// 파일의 원본 바이트. 이 앱이 만들지 않은 항목도 그대로 보존.
    public var raw: Data

    public init(raw: Data) { self.raw = raw }

    /// HiDPI 논리 해상도에서 생성: 백킹 크기 = 논리 크기 x 2.
    public init(logicalWidth: Int, logicalHeight: Int) {
        var bytes: [UInt8] = []
        for value in [logicalWidth * 2, logicalHeight * 2] {
            bytes += [UInt8((value >> 24) & 0xFF), UInt8((value >> 16) & 0xFF), UInt8((value >> 8) & 0xFF), UInt8(value & 0xFF)]
        }
        raw = Data(bytes)
    }

    private func word(_ index: Int) -> Int? {
        let bytes = [UInt8](raw)
        guard bytes.count >= (index + 1) * 4 else { return nil }
        return bytes[index * 4..<(index + 1) * 4].reduce(0) { $0 << 8 | Int($1) }
    }

    public var width: Int { word(0) ?? 0 }
    public var height: Int { word(1) ?? 0 }
    /// 플래그 4바이트. 8바이트 항목은 nil.
    public var flags: Int? { word(2) }

    /// 이 앱이 만든 형식(플래그 없는 8바이트, 짝수 크기)인지.
    public var isBackingSize: Bool { raw.count == 8 && width % 2 == 0 && height % 2 == 0 }

    public var label: String {
        if isBackingSize { return "\(width / 2) x \(height / 2) HiDPI (백킹 \(width) x \(height))" }
        return "\(width) x \(height)" + (flags.map { String(format: " (플래그 0x%X)", $0) } ?? "")
    }
}

/// 디스플레이 오버라이드 파일의 내용. 스케일 해상도 밖의 키는 그대로 보존.
public struct DisplayOverrideFile: Sendable {
    public static let defaultRoot = "/Library/Displays/Contents/Resources/Overrides"

    public var vendorID: UInt32
    public var productID: UInt32
    public var entries: [ScaleResolutionEntry]
    /// `scale-resolutions`, `DisplayVendorID`, `DisplayProductID` 밖의 키를 담은 plist 조각.
    var preserved: Data?

    public init(vendorID: UInt32, productID: UInt32, entries: [ScaleResolutionEntry] = []) {
        self.vendorID = vendorID
        self.productID = productID
        self.entries = entries
    }

    /// 루트 폴더 기준 상대 경로. 16진수 소문자, 앞자리 0 없음.
    public static func relativePath(vendorID: UInt32, productID: UInt32) -> String {
        String(format: "DisplayVendorID-%x/DisplayProductID-%x", vendorID, productID)
    }

    public var relativePath: String { Self.relativePath(vendorID: vendorID, productID: productID) }

    /// plist 해석. 형식이 맞지 않으면 nil.
    public static func decode(_ data: Data, vendorID: UInt32, productID: UInt32) -> DisplayOverrideFile? {
        guard var dict = (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any] else { return nil }
        var file = DisplayOverrideFile(vendorID: vendorID, productID: productID)
        file.entries = (dict["scale-resolutions"] as? [Data] ?? []).map(ScaleResolutionEntry.init(raw:))
        for key in ["scale-resolutions", "DisplayVendorID", "DisplayProductID"] { dict[key] = nil }
        if !dict.isEmpty {
            file.preserved = try? PropertyListSerialization.data(fromPropertyList: dict, format: .binary, options: 0)
        }
        return file
    }

    /// XML plist 생성.
    public func encode() throws -> Data {
        var dict: [String: Any] = [:]
        if let preserved, let extra = (try? PropertyListSerialization.propertyList(from: preserved, format: nil)) as? [String: Any] {
            dict = extra
        }
        dict["DisplayVendorID"] = Int(vendorID)
        dict["DisplayProductID"] = Int(productID)
        dict["scale-resolutions"] = entries.map(\.raw)
        return try PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0)
    }

    /// 스케일 해상도 밖의 키가 있는지. 파일을 지울지 판단할 때 사용.
    public var hasOtherKeys: Bool { preserved != nil }

    public enum EditError: Error, Equatable, LocalizedError {
        case invalidSize(String)
        case duplicate
        case notFound

        public var errorDescription: String? {
            switch self {
            case .invalidSize(let reason): reason
            case .duplicate: "이미 등록된 해상도"
            case .notFound: "등록되지 않은 해상도"
            }
        }
    }

    /// 논리 해상도 점검. 백킹 크기의 한도는 기기와 macOS 판에 따라 달라 상한은 넉넉히 두고 적용 결과로 확인.
    public static func validate(logicalWidth: Int, logicalHeight: Int) -> String? {
        guard (320...8192).contains(logicalWidth), (200...8192).contains(logicalHeight) else {
            return "논리 해상도 범위는 폭 320-8192, 높이 200-8192"
        }
        return nil
    }

    public mutating func add(logicalWidth: Int, logicalHeight: Int) throws {
        if let reason = Self.validate(logicalWidth: logicalWidth, logicalHeight: logicalHeight) { throw EditError.invalidSize(reason) }
        let entry = ScaleResolutionEntry(logicalWidth: logicalWidth, logicalHeight: logicalHeight)
        guard !entries.contains(entry) else { throw EditError.duplicate }
        entries.append(entry)
    }

    public mutating func remove(logicalWidth: Int, logicalHeight: Int) throws {
        let entry = ScaleResolutionEntry(logicalWidth: logicalWidth, logicalHeight: logicalHeight)
        guard let index = entries.firstIndex(of: entry) else { throw EditError.notFound }
        entries.remove(at: index)
    }

    /// `<폭>x<높이>` 해석.
    public static func parseSize(_ text: String) -> (width: Int, height: Int)? {
        let parts = text.lowercased().split(separator: "x").compactMap { Int($0) }
        return parts.count == 2 ? (parts[0], parts[1]) : nil
    }
}
