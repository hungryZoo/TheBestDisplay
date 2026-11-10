import Foundation

/// 렌더링 한계: 모드 목록에서 관찰한 최대 백킹 크기. 시스템이 허용한 스케일 모드의 상한을 보여 줌. (PRD-MOD-009)
public struct RenderingLimits: Codable, Hashable, Sendable {
    /// 전체 모드 중 최대 백킹 폭과 높이 (픽셀). 서로 다른 모드에서 나올 수 있음.
    public var maxPixelWidth: Int
    public var maxPixelHeight: Int
    /// 가장 큰 HiDPI 모드의 논리 해상도와 백킹 해상도.
    public var largestHiDPILogicalWidth: Int?
    public var largestHiDPILogicalHeight: Int?
    public var largestHiDPIPixelWidth: Int?
    public var largestHiDPIPixelHeight: Int?
    public var modeCount: Int
    public var hiDPIModeCount: Int

    public var summary: String {
        var text = "최대 백킹 \(maxPixelWidth) x \(maxPixelHeight) 픽셀"
        if let w = largestHiDPILogicalWidth, let h = largestHiDPILogicalHeight, let pw = largestHiDPIPixelWidth, let ph = largestHiDPIPixelHeight {
            text += ", 가장 큰 HiDPI 모드 \(w) x \(h) (백킹 \(pw) x \(ph))"
        }
        return text + ", 모드 \(modeCount)개 중 HiDPI \(hiDPIModeCount)개"
    }
}

public extension ModeCatalog {
    /// 모드 목록 기준 렌더링 한계. 목록이 비면 nil.
    static func renderingLimits(_ modes: [DisplayMode]) -> RenderingLimits? {
        guard let maxWidth = modes.map(\.pixelWidth).max(), let maxHeight = modes.map(\.pixelHeight).max() else { return nil }
        let hiDPI = modes.filter(\.isHiDPI)
        let largest = hiDPI.max { ($0.pixelWidth * $0.pixelHeight, $0.pixelWidth) < ($1.pixelWidth * $1.pixelHeight, $1.pixelWidth) }
        return RenderingLimits(
            maxPixelWidth: maxWidth, maxPixelHeight: maxHeight,
            largestHiDPILogicalWidth: largest?.width, largestHiDPILogicalHeight: largest?.height,
            largestHiDPIPixelWidth: largest?.pixelWidth, largestHiDPIPixelHeight: largest?.pixelHeight,
            modeCount: modes.count, hiDPIModeCount: hiDPI.count
        )
    }

    /// 해상도 슬라이더의 단계: 현재 모드와 같은 배율(HiDPI 여부)과 종횡비(차이 2% 이내)를 가진 해상도를 폭 오름차순으로 나열.
    /// 단계마다 현재 주사율과 가장 가까운 모드 하나를 고름 (같으면 가변 주사율이 아닌 모드 우선). (PRD-MOD-010)
    static func sliderSteps(_ modes: [DisplayMode], current: DisplayMode) -> [DisplayMode] {
        let ratio = Double(current.width) / Double(max(current.height, 1))
        let candidates = modes.filter { $0.isHiDPI == current.isHiDPI && abs(Double($0.width) / Double(max($0.height, 1)) / ratio - 1) < 0.02 }
        var best: [String: DisplayMode] = [:]
        for mode in candidates {
            let key = "\(mode.width)x\(mode.height)"
            func rank(_ m: DisplayMode) -> (Double, Int, Int32) {
                (abs(m.refreshRate - current.refreshRate), m.isVRR == current.isVRR ? 0 : 1, m.modeNumber)
            }
            if let existing = best[key], rank(existing) <= rank(mode) { continue }
            best[key] = mode
        }
        return best.values.sorted { ($0.width, $0.height) < ($1.width, $1.height) }
    }
}

/// 디스플레이별 즐겨찾기 모드. 디스플레이는 제조사, 제품 코드, 일련번호로 구분. (PRD-MOD-010, SRS-MOD-006)
public struct ModeFavoritesStore: Sendable {
    public var fileURL: URL

    public init(fileURL: URL) { self.fileURL = fileURL }

    public static var standard: ModeFavoritesStore {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return ModeFavoritesStore(fileURL: base.appendingPathComponent("TheBestDisplay", isDirectory: true).appendingPathComponent("mode-favorites.json"))
    }

    public static func key(for identity: DisplayIdentity) -> String {
        String(format: "%x-%x-%u", identity.vendorID, identity.productID, identity.serialNumber)
    }

    func loadAll() -> [String: [ModeDescriptor]] {
        guard let data = try? Data(contentsOf: fileURL) else { return [:] }
        return (try? JSONDecoder().decode([String: [ModeDescriptor]].self, from: data)) ?? [:]
    }

    func saveAll(_ all: [String: [ModeDescriptor]]) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(all.filter { !$0.value.isEmpty }).write(to: fileURL, options: .atomic)
    }

    /// 즐겨찾기 목록. 저장 순서 유지.
    public func favorites(for identity: DisplayIdentity) -> [ModeDescriptor] {
        loadAll()[Self.key(for: identity)] ?? []
    }

    public func contains(_ mode: ModeDescriptor, for identity: DisplayIdentity) -> Bool {
        favorites(for: identity).contains(mode)
    }

    /// 추가. 이미 있으면 변화 없음. 추가했으면 참.
    @discardableResult
    public func add(_ mode: ModeDescriptor, for identity: DisplayIdentity) throws -> Bool {
        var all = loadAll()
        let key = Self.key(for: identity)
        guard !(all[key] ?? []).contains(mode) else { return false }
        all[key, default: []].append(mode)
        try saveAll(all)
        return true
    }

    /// 삭제. 없으면 변화 없음. 삭제했으면 참.
    @discardableResult
    public func remove(_ mode: ModeDescriptor, for identity: DisplayIdentity) throws -> Bool {
        var all = loadAll()
        let key = Self.key(for: identity)
        guard let index = all[key]?.firstIndex(of: mode) else { return false }
        all[key]?.remove(at: index)
        try saveAll(all)
        return true
    }
}

/// notch 모드 판정과 전환 대상. notch가 있는 내장 패널은 같은 폭에 높이가 다른 모드 쌍을 가짐:
/// 화면 전체를 쓰는 모드(예: 1512 x 982)와 notch 아래 16:10 영역만 쓰는 모드(예: 1512 x 945). (PRD-MOD-011)
public struct NotchModePair: Hashable, Sendable {
    /// 화면 전체를 쓰는 모드 (notch 영역 포함).
    public var full: DisplayMode
    /// notch 아래 영역만 쓰는 16:10 모드.
    public var belowNotch: DisplayMode
}

public extension ModeCatalog {
    /// 현재 모드의 notch 모드 쌍. 같은 폭, 같은 배율, 같은 주사율과 가변 주사율 여부를 가진 모드 가운데
    /// 한쪽이 16:10이고 다른 쪽이 그보다 높은 쌍을 찾음. 없으면 nil.
    static func notchPair(_ modes: [DisplayMode], current: DisplayMode) -> NotchModePair? {
        func is16by10(_ m: DisplayMode) -> Bool { m.width * 10 == m.height * 16 }
        let siblings = modes.filter {
            $0.width == current.width && $0.isHiDPI == current.isHiDPI && $0.isVRR == current.isVRR
                && abs($0.refreshRate - current.refreshRate) < 0.01 && $0.height != current.height
        }
        if is16by10(current) {
            // 현재가 notch 아래 모드: 같은 폭에서 더 높은 모드가 전체 모드. 높이 차이는 notch 높이(폭의 5% 이내).
            guard let full = siblings.filter({ $0.height > current.height && ($0.height - current.height) * 20 <= current.width }).min(by: { $0.height < $1.height }) else { return nil }
            return NotchModePair(full: full, belowNotch: current)
        }
        guard let below = siblings.first(where: { is16by10($0) && $0.height < current.height && (current.height - $0.height) * 20 <= current.width }) else { return nil }
        return NotchModePair(full: current, belowNotch: below)
    }
}
