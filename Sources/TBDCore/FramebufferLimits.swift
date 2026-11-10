import Foundation

/// 프레임버퍼가 보고하는 소스 크기와 스케일 한도. (PRD-MOD-014, SRS-MOD-009)
///
/// 출처는 프레임버퍼 노드(`IOMobileFramebufferShim`)의 `IOMFBMaxSrcPixels`와 `IOMFBScalingLimits`.
/// 모드 목록에서 관찰한 값(`RenderingLimits`)과 달리 시스템이 직접 알린 값.
public struct FramebufferLimits: Codable, Hashable, Sendable {
    /// 파이프별 소스 사각형 최대 폭과 높이 (픽셀). 0은 쓰지 않는 파이프.
    public var maxSourceWidths: [Int]
    public var maxSourceHeights: [Int]
    /// 소스 버퍼 최대 크기.
    public var maxBufferWidth: Int?
    public var maxBufferHeight: Int?
    /// 영상 소스 축소의 최대 폭. 0이면 nil.
    public var maxVideoDownscalingWidth: Int?
    /// RGB 레이어의 최대 확대 배율과 최소 축소 분모 (2면 1/2배).
    public var rgbMaxScale: Int?
    public var rgbMinScaleFraction: Int?

    public init(maxSourceWidths: [Int], maxSourceHeights: [Int], maxBufferWidth: Int? = nil, maxBufferHeight: Int? = nil, maxVideoDownscalingWidth: Int? = nil, rgbMaxScale: Int? = nil, rgbMinScaleFraction: Int? = nil) {
        self.maxSourceWidths = maxSourceWidths
        self.maxSourceHeights = maxSourceHeights
        self.maxBufferWidth = maxBufferWidth
        self.maxBufferHeight = maxBufferHeight
        self.maxVideoDownscalingWidth = maxVideoDownscalingWidth
        self.rgbMaxScale = rgbMaxScale
        self.rgbMinScaleFraction = rgbMinScaleFraction
    }

    /// 프레임버퍼 노드 속성 해석. 소스 한도 속성이 없으면 nil.
    public init?(properties: [String: Any]) {
        guard let source = properties["IOMFBMaxSrcPixels"] as? [String: Any] else { return nil }
        func ints(_ key: String) -> [Int] { (source[key] as? [NSNumber] ?? []).map(\.intValue) }
        func int(_ dictionary: [String: Any], _ key: String) -> Int? { (dictionary[key] as? NSNumber)?.intValue }
        let widths = ints("MaxSrcRectWidthForPipe"), heights = ints("MaxSrcRectHeightForPipe")
        guard widths.contains(where: { $0 > 0 }) else { return nil }
        let scaling = properties["IOMFBScalingLimits"] as? [String: Any] ?? [:]
        self.init(
            maxSourceWidths: widths, maxSourceHeights: heights,
            maxBufferWidth: int(source, "MaxSrcBufferWidth").flatMap { $0 > 0 ? $0 : nil },
            maxBufferHeight: int(source, "MaxSrcBufferHeight").flatMap { $0 > 0 ? $0 : nil },
            maxVideoDownscalingWidth: int(source, "MaxVideoSrcDownscalingWidth").flatMap { $0 > 0 ? $0 : nil },
            rgbMaxScale: int(scaling, "RGBLayer_MaxScale"),
            rgbMinScaleFraction: int(scaling, "RGBLayer_MinScaleFraction")
        )
    }

    /// 첫 파이프의 소스 한도. 디스플레이의 기본 화면이 쓰는 값으로 봄 (LG TV 실측: 모드 목록의 최대 백킹 폭 6016이 첫 파이프 한도 6144 이하).
    public var primarySourceWidth: Int? { maxSourceWidths.first.flatMap { $0 > 0 ? $0 : nil } }
    public var primarySourceHeight: Int? { maxSourceHeights.first.flatMap { $0 > 0 ? $0 : nil } }
    /// 전체 파이프 중 가장 큰 소스 폭.
    public var largestSourceWidth: Int? { maxSourceWidths.max().flatMap { $0 > 0 ? $0 : nil } }

    /// 백킹 크기가 첫 파이프의 소스 한도 안인지. 한도를 모르면 nil.
    public func allows(pixelWidth: Int, pixelHeight: Int) -> Bool? {
        guard let width = primarySourceWidth, let height = primarySourceHeight else { return nil }
        return pixelWidth <= width && pixelHeight <= height
    }

    /// 한도를 넘는 백킹 크기에 대한 안내. 한도 안이거나 한도를 모르면 nil.
    public func excessNotice(pixelWidth: Int, pixelHeight: Int) -> String? {
        guard allows(pixelWidth: pixelWidth, pixelHeight: pixelHeight) == false, let width = primarySourceWidth, let height = primarySourceHeight else { return nil }
        return "백킹 \(pixelWidth) x \(pixelHeight)은 프레임버퍼 소스 한도 \(width) x \(height) 초과. 등록해도 모드 목록에 나오지 않을 수 있음"
    }

    /// 예: "소스 최대 6144 x 4320 (파이프별 폭 6144, 7680, 7680, 7680), 버퍼 최대 16384 x 16384, 스케일 1/2-4배"
    public var summary: String {
        var parts: [String] = []
        if let width = primarySourceWidth, let height = primarySourceHeight {
            let active = maxSourceWidths.filter { $0 > 0 }
            let pipes = active.count > 1 ? " (파이프별 폭 \(active.map(String.init).joined(separator: ", ")))" : ""
            parts.append("소스 최대 \(width) x \(height)\(pipes)")
        }
        if let width = maxBufferWidth, let height = maxBufferHeight { parts.append("버퍼 최대 \(width) x \(height)") }
        if let fraction = rgbMinScaleFraction, let scale = rgbMaxScale, fraction > 0 { parts.append("스케일 1/\(fraction)-\(scale)배") }
        if let width = maxVideoDownscalingWidth { parts.append("영상 축소 최대 폭 \(width)") }
        return parts.joined(separator: ", ")
    }
}
