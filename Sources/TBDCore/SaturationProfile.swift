import Foundation

/// 채도 조정: 디스플레이 프로파일의 색 좌표를 바꾼 프로파일을 만들어 색 관리 단계에서 채도를 조절. (PRD-CLR-008, SRS-CLR-007)
///
/// 전달 테이블은 채널별 곡선이라 채널을 섞는 채도 조정을 표현할 수 없음. 색 관리가 출력값을 `M⁻¹`로 계산하므로
/// 프로파일의 색 좌표 행렬을 `M · S⁻¹`로 바꾸면 출력값에 채도 행렬 `S`가 곱해짐. `S = s·I + (1-s)·1wᵀ` (w는 원색의 휘도 비율).
public enum SaturationAdjustment {
    /// 지정 가능한 범위. 1은 변화 없음.
    public static let range = 0.5...1.5

    public static func parsePercent(_ text: String) -> Double? {
        guard let value = Double(text), (range.lowerBound * 100...range.upperBound * 100).contains(value) else { return nil }
        return value / 100
    }

    /// 채도 `saturation`을 내도록 바꾼 색 좌표. 원색의 휘도(Y)와 흰색(세 원색의 합)은 유지.
    public static func adjustedColorants(red: ICCProfile.XYZ, green: ICCProfile.XYZ, blue: ICCProfile.XYZ, saturation: Double) -> (red: ICCProfile.XYZ, green: ICCProfile.XYZ, blue: ICCProfile.XYZ) {
        let white = red + green + blue
        guard white.y > 0, saturation > 0 else { return (red, green, blue) }
        let inverse = 1 / saturation
        func adjust(_ colorant: ICCProfile.XYZ) -> ICCProfile.XYZ {
            colorant * inverse + white * ((1 - inverse) * colorant.y / white.y)
        }
        return (adjust(red), adjust(green), adjust(blue))
    }

    /// 채도 행렬 `S`를 선형 RGB 값에 적용. 검증과 미리 계산에 사용.
    public static func apply(_ saturation: Double, to rgb: (Double, Double, Double), weights: (Double, Double, Double)) -> (Double, Double, Double) {
        let luma = rgb.0 * weights.0 + rgb.1 * weights.1 + rgb.2 * weights.2
        return (luma + (rgb.0 - luma) * saturation, luma + (rgb.1 - luma) * saturation, luma + (rgb.2 - luma) * saturation)
    }

    /// 프로파일에 채도 조정 적용. 행렬 방식 RGB 디스플레이 프로파일(`rXYZ`, `gXYZ`, `bXYZ` 보유)만 대상.
    public static func adjustedProfile(_ profile: ICCProfile, saturation: Double, baseName: String) throws -> ICCProfile {
        guard profile.colorSpace == "RGB " else { throw ICCProfile.ParseError.wrongTagType("colorSpace") }
        let (red, green, blue) = (try profile.xyz("rXYZ"), try profile.xyz("gXYZ"), try profile.xyz("bXYZ"))
        let adjusted = adjustedColorants(red: red, green: green, blue: blue, saturation: saturation)
        var result = profile
        result.setXYZ(adjusted.red, for: "rXYZ")
        result.setXYZ(adjusted.green, for: "gXYZ")
        result.setXYZ(adjusted.blue, for: "bXYZ")
        let percent = Int((saturation * 100).rounded())
        result.setDescription(ascii: "TheBestDisplay saturation \(percent)%", localized: "\(baseName) (채도 \(percent)%)")
        return result
    }
}

/// 채도 조정 상태 저장: 조정 전 프로파일과 적용한 값. 색 프로파일 지정은 재시동 뒤에도 남으므로 복원 정보를 파일로 보관. (SRS-CLR-007)
public struct SaturationStore: Sendable {
    public struct Entry: Codable, Hashable, Sendable {
        /// 조정 전 프로파일. 공장 기본값이었으면 `baseIsFactoryDefault`가 참.
        public var basePath: String
        public var baseName: String
        public var baseIsFactoryDefault: Bool
        public var saturation: Double
        /// 만들어 지정한 프로파일 파일.
        public var generatedPath: String

        public init(basePath: String, baseName: String, baseIsFactoryDefault: Bool, saturation: Double, generatedPath: String) {
            self.basePath = basePath
            self.baseName = baseName
            self.baseIsFactoryDefault = baseIsFactoryDefault
            self.saturation = saturation
            self.generatedPath = generatedPath
        }
    }

    public var fileURL: URL

    public init(fileURL: URL) { self.fileURL = fileURL }

    public static var standardFolder: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent("TheBestDisplay", isDirectory: true)
    }

    public static var standard: SaturationStore { SaturationStore(fileURL: standardFolder.appendingPathComponent("saturation.json")) }

    func loadAll() -> [String: Entry] {
        guard let data = try? Data(contentsOf: fileURL) else { return [:] }
        return (try? JSONDecoder().decode([String: Entry].self, from: data)) ?? [:]
    }

    public func entry(for identity: DisplayIdentity) -> Entry? {
        loadAll()[ModeFavoritesStore.key(for: identity)]
    }

    public func set(_ entry: Entry?, for identity: DisplayIdentity) throws {
        var all = loadAll()
        all[ModeFavoritesStore.key(for: identity)] = entry
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(all).write(to: fileURL, options: .atomic)
    }
}
