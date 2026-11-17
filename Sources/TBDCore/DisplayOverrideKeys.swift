import Foundation

/// 디스플레이 오버라이드 파일의 이름, 기본 해상도, TV 역할 키. (PRD-MOD-016, SRS-MOD-011)
///
/// 키와 형식은 Apple 제공 오버라이드 파일에서 확인하고 LG TV로 동작을 실측 (T69):
/// `DisplayProductName`(문자열)은 디스플레이 이름, `default-resolution`(12바이트)은 기본 모드의 논리 해상도,
/// `DisplayIsTV`(불)는 정보 사전의 TV 표시. 반영 시점은 디스플레이 재연결 또는 재초기화.
public extension DisplayOverrideFile {
    static let nameKey = "DisplayProductName"
    static let defaultResolutionKey = "default-resolution"
    static let isTVKey = "DisplayIsTV"
    /// `default-resolution` 뒤쪽 4바이트. Apple 제공 파일의 값을 그대로 사용.
    static let defaultResolutionSuffix: [UInt8] = [0x00, 0x3C, 0xFF, 0xFF]
    static let nameLengthRange = 1...64

    internal var extraKeys: [String: Any] {
        get {
            guard let preserved else { return [:] }
            return (try? PropertyListSerialization.propertyList(from: preserved, format: nil)) as? [String: Any] ?? [:]
        }
        set {
            preserved = newValue.isEmpty ? nil : try? PropertyListSerialization.data(fromPropertyList: newValue, format: .binary, options: 0)
        }
    }

    /// 지정한 디스플레이 이름. 언어별 사전 형식이면 영어 항목 또는 첫 항목.
    var productName: String? {
        get {
            let value = extraKeys[Self.nameKey]
            if let text = value as? String { return text }
            if let names = value as? [String: String] { return names["en_US"] ?? names.sorted { $0.key < $1.key }.first?.value }
            return nil
        }
        set {
            var keys = extraKeys
            keys[Self.nameKey] = newValue
            extraKeys = keys
        }
    }

    /// 기본 모드의 논리 해상도.
    var defaultResolution: (width: Int, height: Int)? {
        get {
            guard let data = extraKeys[Self.defaultResolutionKey] as? Data, data.count >= 8 else { return nil }
            let bytes = [UInt8](data)
            let width = bytes[0..<4].reduce(0) { $0 << 8 | Int($1) }, height = bytes[4..<8].reduce(0) { $0 << 8 | Int($1) }
            return width > 0 && height > 0 ? (width, height) : nil
        }
        set {
            var keys = extraKeys
            if let newValue {
                var bytes: [UInt8] = []
                for value in [newValue.width, newValue.height] {
                    bytes += [UInt8((value >> 24) & 0xFF), UInt8((value >> 16) & 0xFF), UInt8((value >> 8) & 0xFF), UInt8(value & 0xFF)]
                }
                keys[Self.defaultResolutionKey] = Data(bytes + Self.defaultResolutionSuffix)
            } else {
                keys[Self.defaultResolutionKey] = nil
            }
            extraKeys = keys
        }
    }

    /// TV 역할 표시. 키가 없으면 nil.
    var isTV: Bool? {
        get { (extraKeys[Self.isTVKey] as? NSNumber)?.boolValue }
        set {
            var keys = extraKeys
            keys[Self.isTVKey] = newValue
            extraKeys = keys
        }
    }

    /// 이름 점검: 길이 1-64, 제어 문자 없음. 문제가 없으면 nil.
    static func validateName(_ name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard nameLengthRange.contains(trimmed.count) else { return "이름 길이는 1-64자" }
        guard trimmed.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }) else { return "이름에 제어 문자 사용 불가" }
        return nil
    }

    /// 이름 지정 (앞뒤 공백 제거) 또는 해제(nil).
    mutating func setProductName(_ name: String?) throws {
        guard let name else {
            productName = nil
            return
        }
        if let reason = Self.validateName(name) { throw EditError.invalidSize(reason) }
        productName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 기본 해상도 지정 또는 해제(nil). 범위는 스케일 해상도와 같은 기준.
    mutating func setDefaultResolution(width: Int, height: Int) throws {
        if let reason = Self.validate(logicalWidth: width, logicalHeight: height) { throw EditError.invalidSize(reason) }
        defaultResolution = (width, height)
    }

    /// 이 앱이 다루는 세 키의 요약 행.
    var keySummary: [String] {
        [
            "이름: " + (productName ?? "지정 없음"),
            "기본 해상도: " + (defaultResolution.map { "\($0.width) x \($0.height)" } ?? "지정 없음"),
            "TV 역할 표시: " + (isTV.map { $0 ? "켬" : "끔" } ?? "지정 없음"),
        ]
    }
}
