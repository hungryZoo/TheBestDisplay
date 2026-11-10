import Foundation

/// 가상 디스플레이 구성. (PRD-VRT-001, PRD-VRT-003)
public struct VirtualDisplayConfig: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var name: String
    /// 논리 해상도 (포인트).
    public var width: Int
    public var height: Int
    /// 참이면 백킹 해상도가 논리 해상도의 2배.
    public var hiDPI: Bool
    public var refreshRate: Double
    /// 앱 실행 시 자동 생성 여부.
    public var restoreAtLaunch: Bool
    /// HDR 가상 디스플레이 여부. 모드의 전달 함수 값을 1로 지정 (실험 04). (PRD-VRT-004)
    public var hdr: Bool = false

    enum CodingKeys: String, CodingKey { case id, name, width, height, hiDPI, refreshRate, restoreAtLaunch, hdr }

    /// 이전 판의 저장 파일에는 `hdr` 키가 없으므로 없으면 거짓.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        width = try c.decode(Int.self, forKey: .width)
        height = try c.decode(Int.self, forKey: .height)
        hiDPI = try c.decode(Bool.self, forKey: .hiDPI)
        refreshRate = try c.decode(Double.self, forKey: .refreshRate)
        restoreAtLaunch = try c.decode(Bool.self, forKey: .restoreAtLaunch)
        hdr = try c.decodeIfPresent(Bool.self, forKey: .hdr) ?? false
    }

    public init(id: UUID = UUID(), name: String, width: Int, height: Int, hiDPI: Bool, refreshRate: Double = 60, restoreAtLaunch: Bool = false, hdr: Bool = false) {
        self.hdr = hdr
        self.id = id
        self.name = name
        self.width = width
        self.height = height
        self.hiDPI = hiDPI
        self.refreshRate = refreshRate
        self.restoreAtLaunch = restoreAtLaunch
    }

    public var pixelWidth: Int { hiDPI ? width * 2 : width }
    public var pixelHeight: Int { hiDPI ? height * 2 : height }

    /// 물리 크기 (mm). 실제 패널이 없으므로 일반 모니터의 화소 밀도(약 110 PPI)에 맞춘 값.
    public var sizeInMillimeters: (width: Double, height: Double) {
        (Double(width) / 110 * 25.4, Double(height) / 110 * 25.4)
    }

    /// 구성 식별자에서 만든 일련번호. 같은 구성은 재생성 뒤에도 같은 디스플레이로 인식.
    public var serialNumber: UInt32 {
        withUnsafeBytes(of: id.uuid) { bytes in
            bytes.reduce(UInt32(2166136261)) { ($0 ^ UInt32($1)) &* 16777619 }
        }
    }

    public var label: String {
        "\(width) x \(height)\(hiDPI ? " HiDPI" : ""), \(DisplaySummary.formatHz(refreshRate)) Hz\(hdr ? ", HDR" : "")"
    }

    public static let widthRange = 640...7680
    public static let heightRange = 480...4320
    /// 백킹 폭 상한. 조사 문서 기준 보급형 칩의 HiDPI 렌더링 폭 한도는 6144픽셀, 상위 칩은 7680픽셀. 칩별 실제 한도는 생성 결과로 확인.
    public static let maxPixelWidth = 7680

    /// 구성의 문제 목록. 비어 있으면 유효.
    public func validationIssues() -> [String] {
        var issues: [String] = []
        if name.trimmingCharacters(in: .whitespaces).isEmpty { issues.append("이름이 비어 있음") }
        if !Self.widthRange.contains(width) { issues.append("폭은 \(Self.widthRange.lowerBound)-\(Self.widthRange.upperBound) 범위") }
        if !Self.heightRange.contains(height) { issues.append("높이는 \(Self.heightRange.lowerBound)-\(Self.heightRange.upperBound) 범위") }
        if pixelWidth > Self.maxPixelWidth { issues.append("백킹 폭 \(pixelWidth)픽셀이 상한 \(Self.maxPixelWidth)픽셀 초과") }
        if !(24...240).contains(refreshRate) { issues.append("주사율은 24-240 Hz 범위") }
        return issues
    }
}

/// 가상 디스플레이 구성 저장. (SRS-VRT-001)
public struct VirtualDisplayStore: Sendable {
    public var fileURL: URL

    public init(fileURL: URL) { self.fileURL = fileURL }

    public static var standard: VirtualDisplayStore {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return VirtualDisplayStore(fileURL: base.appendingPathComponent("TheBestDisplay", isDirectory: true).appendingPathComponent("virtual-displays.json"))
    }

    /// 파일이 없거나 손상되었으면 빈 목록.
    public func load() -> [VirtualDisplayConfig] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([VirtualDisplayConfig].self, from: data)) ?? []
    }

    public func save(_ configs: [VirtualDisplayConfig]) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(configs).write(to: fileURL, options: .atomic)
    }
}

/// HiDPI 스케일링 계획: 실제 디스플레이를 HiDPI 가상 디스플레이의 미러로 구성. (SRS-VRT-002, PRD-VRT-002)
public enum HiDPIScaling {
    /// 대상 디스플레이의 종횡비에 맞는 논리 해상도 후보. 원본 픽셀 폭 기준 배율별 계산.
    /// 배율 1.0은 원본의 절반(2배 HiDPI), 배율이 클수록 화면에 더 많은 내용 표시.
    public static func presets(nativeWidth: Int, nativeHeight: Int) -> [(width: Int, height: Int)] {
        guard nativeWidth > 0, nativeHeight > 0 else { return [] }
        let ratio = Double(nativeHeight) / Double(nativeWidth)
        let scales = [0.5, 0.6, 2.0 / 3, 0.75, 0.8, 0.9, 1.0]
        var seen = Set<Int>()
        var result: [(Int, Int)] = []
        for scale in scales {
            // 폭은 8의 배수로 맞춤.
            let width = Int((Double(nativeWidth) * scale / 8).rounded()) * 8
            let height = Int((Double(width) * ratio).rounded())
            guard width * 2 <= VirtualDisplayConfig.maxPixelWidth, VirtualDisplayConfig.widthRange.contains(width), VirtualDisplayConfig.heightRange.contains(height), seen.insert(width).inserted else { continue }
            result.append((width, height))
        }
        return result
    }

    /// 스케일링용 가상 디스플레이 구성. 주사율은 대상의 현재 주사율.
    public static func config(for target: DisplaySummary, logicalWidth: Int, logicalHeight: Int) -> VirtualDisplayConfig {
        VirtualDisplayConfig(name: "\(target.identity.name) HiDPI", width: logicalWidth, height: logicalHeight, hiDPI: true, refreshRate: target.refreshRate > 0 ? target.refreshRate : 60)
    }

    /// 스케일링 결과의 선명도 설명. 백킹 해상도가 패널 원본보다 크면 축소 표시, 작으면 확대 표시.
    public static func sharpnessNote(logicalWidth: Int, nativeWidth: Int) -> String {
        let backing = logicalWidth * 2
        if backing == nativeWidth { return "패널 화소와 1대1 대응" }
        if backing > nativeWidth { return String(format: "%d픽셀로 그린 뒤 패널 %d픽셀로 축소 (%.0f%%)", backing, nativeWidth, Double(nativeWidth) / Double(backing) * 100) }
        return String(format: "%d픽셀로 그린 뒤 패널 %d픽셀로 확대 (%.0f%%)", backing, nativeWidth, Double(nativeWidth) / Double(backing) * 100)
    }
}
