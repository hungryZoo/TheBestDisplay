import Foundation

/// 같은 해상도와 배율을 가진 모드 묶음. 주사율만 다름. (SRS-MOD-003)
public struct ModeGroup: Hashable, Sendable, Identifiable {
    public var width: Int
    public var height: Int
    public var pixelWidth: Int
    public var pixelHeight: Int
    public var isHiDPI: Bool
    /// 주사율 내림차순.
    public var modes: [DisplayMode]

    public var id: String { "\(width)x\(height)@\(isHiDPI ? 2 : 1)" }
    public var aspectRatio: String { modes.first?.aspectRatio ?? "" }
    /// 묶음의 모든 모드가 시스템 기본 목록 밖이면 참.
    public var isOutsideSystemDefaultList: Bool { modes.allSatisfy { !$0.isInSystemDefaultList } }
    public var label: String { "\(width) x \(height)\(isHiDPI ? " HiDPI" : "")" }
}

public struct ModeFilter: Hashable, Sendable {
    public enum HiDPI: String, CaseIterable, Sendable {
        case all, hiDPIOnly, lowDPIOnly

        public var title: String {
            switch self {
            case .all: "전체"
            case .hiDPIOnly: "HiDPI만"
            case .lowDPIOnly: "일반만"
            }
        }
    }

    public var hiDPI: HiDPI = .all
    /// 지정 시 이 주사율(반올림 정수)의 모드만.
    public var refreshRate: Int?
    /// 지정 시 이 종횡비의 모드만. 예: "16:9"
    public var aspectRatio: String?
    /// 시스템 기본 목록 밖 모드만.
    public var onlyOutsideSystemDefaultList = false

    public init() {}

    public func matches(_ mode: DisplayMode) -> Bool {
        switch hiDPI {
        case .all: break
        case .hiDPIOnly: if !mode.isHiDPI { return false }
        case .lowDPIOnly: if mode.isHiDPI { return false }
        }
        if let refreshRate, Int(mode.refreshRate.rounded()) != refreshRate { return false }
        if let aspectRatio, mode.aspectRatio != aspectRatio { return false }
        if onlyOutsideSystemDefaultList, mode.isInSystemDefaultList { return false }
        return true
    }
}

public enum ModeCatalog {
    /// 필터 적용 후 해상도별 묶음. 정렬: 논리 면적 내림차순, 같은 해상도는 HiDPI 먼저.
    public static func groups(_ modes: [DisplayMode], filter: ModeFilter = ModeFilter()) -> [ModeGroup] {
        var buckets: [String: ModeGroup] = [:]
        for mode in modes where filter.matches(mode) {
            let key = "\(mode.width)x\(mode.height)@\(mode.isHiDPI ? 2 : 1)"
            if buckets[key] == nil {
                buckets[key] = ModeGroup(width: mode.width, height: mode.height, pixelWidth: mode.pixelWidth, pixelHeight: mode.pixelHeight, isHiDPI: mode.isHiDPI, modes: [])
            }
            buckets[key]?.modes.append(mode)
        }
        return buckets.values
            .map { group in
                var g = group
                g.modes.sort { ($0.refreshRate, $0.isVRR ? 1 : 0) > ($1.refreshRate, $1.isVRR ? 1 : 0) }
                return g
            }
            .sorted { a, b in
                (a.width * a.height, a.width, a.isHiDPI ? 1 : 0) > (b.width * b.height, b.width, b.isHiDPI ? 1 : 0)
            }
    }

    /// 목록에 있는 주사율(반올림 정수)의 오름차순 집합.
    public static func refreshRates(_ modes: [DisplayMode]) -> [Int] {
        Array(Set(modes.map { Int($0.refreshRate.rounded()) })).sorted()
    }

    public static func aspectRatios(_ modes: [DisplayMode]) -> [String] {
        var counts: [String: Int] = [:]
        for mode in modes { counts[mode.aspectRatio, default: 0] += 1 }
        return counts.sorted { ($0.value, $1.key) > ($1.value, $0.key) }.map(\.key)
    }

    /// 원본 해상도 모드. 시스템 판정이 있으면 그 결과, 없으면 백킹 해상도가 패널 원본과 같은 모드(배율 1 우선).
    public static func nativeModes(_ modes: [DisplayMode], nativeWidth: Int, nativeHeight: Int) -> [DisplayMode] {
        let flagged = modes.filter(\.isNative)
        if !flagged.isEmpty { return flagged }
        let exact = modes.filter { $0.pixelWidth == nativeWidth && $0.pixelHeight == nativeHeight }
        let lowDPI = exact.filter { !$0.isHiDPI }
        return lowDPI.isEmpty ? exact : lowDPI
    }

    /// 시스템 판정을 얻을 수 없을 때의 대체: 공개 API 기본 열거 결과와 대조하여 `isInSystemDefaultList` 표시. 대조 키: 논리 해상도, 백킹 폭, 반올림 주사율.
    public static func markSystemDefault(_ modes: [DisplayMode], defaultKeys: Set<String>) -> [DisplayMode] {
        modes.map { mode in
            var m = mode
            m.isInSystemDefaultList = defaultKeys.contains(defaultKey(width: mode.width, height: mode.height, pixelWidth: mode.pixelWidth, refreshRate: mode.refreshRate))
            return m
        }
    }

    public static func defaultKey(width: Int, height: Int, pixelWidth: Int, refreshRate: Double) -> String {
        "\(width)x\(height)/\(pixelWidth)@\(Int(refreshRate.rounded()))"
    }
}
