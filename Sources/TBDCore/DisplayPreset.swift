import Foundation

/// 디스플레이 프리셋 (기준 모드). XDR 패널과 Apple 디스플레이가 제공. (PRD-CLR-005)
public struct DisplayPreset: Codable, Hashable, Sendable, Identifiable {
    public var index: Int
    public var name: String
    public var detail: String
    public var group: Int
    public var isActive: Bool
    public var isDefault: Bool
    public var isValid: Bool
    public var isWritable: Bool

    public var id: Int { index }

    public init(index: Int, name: String, detail: String, group: Int, isActive: Bool, isDefault: Bool, isValid: Bool, isWritable: Bool) {
        self.index = index
        self.name = name
        self.detail = detail
        self.group = group
        self.isActive = isActive
        self.isDefault = isDefault
        self.isValid = isValid
        self.isWritable = isWritable
    }

    /// 명령행 지정 해석: 번호 또는 이름의 일부(대소문자 무시). 이름이 여러 개와 맞으면 nil.
    public static func resolve(_ text: String, in presets: [DisplayPreset]) -> DisplayPreset? {
        if let index = Int(text) { return presets.first { $0.index == index } }
        let lower = text.lowercased()
        if let exact = presets.first(where: { $0.name.lowercased() == lower }) { return exact }
        let matches = presets.filter { $0.name.lowercased().contains(lower) }
        return matches.count == 1 ? matches[0] : nil
    }
}
