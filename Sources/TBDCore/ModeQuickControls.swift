import Foundation

/// 해상도 탭의 빠른 설정: 현재 해상도에서 주사율만 바꾸기, HiDPI 켜기와 끄기, 해상도 구성 요약. (PRD-MOD-015, SRS-MOD-010)
public extension ModeCatalog {
    /// 현재 해상도(논리 크기, 백킹 크기, HiDPI 여부가 같은 모드)에서 고를 수 있는 모드. 주사율 내림차순.
    static func refreshOptions(_ modes: [DisplayMode], current: DisplayMode) -> [DisplayMode] {
        modes
            .filter { $0.width == current.width && $0.height == current.height && $0.pixelWidth == current.pixelWidth && $0.pixelHeight == current.pixelHeight }
            .sorted { ($0.refreshRate, $0.isVRR ? 1 : 0) > ($1.refreshRate, $1.isVRR ? 1 : 0) }
    }

    /// 후보 가운데 현재 모드와 주사율이 가장 가까운 모드. 같은 주사율이면 가변 주사율 여부가 같은 쪽 우선.
    private static func closestRefresh(_ candidates: [DisplayMode], to current: DisplayMode) -> DisplayMode? {
        candidates.min { a, b in
            let da = (abs(a.refreshRate - current.refreshRate), a.isVRR == current.isVRR ? 0 : 1)
            let db = (abs(b.refreshRate - current.refreshRate), b.isVRR == current.isVRR ? 0 : 1)
            return da < db
        }
    }

    /// HiDPI 상태를 반대로 바꿀 때의 대상 모드.
    /// 선택 순서: (1) 논리 해상도가 같은 모드, (2) 켤 때는 백킹 크기가 패널 해상도와 같은 모드(논리 해상도가 패널의 절반),
    /// (3) 논리 화면 넓이가 현재와 가장 가까운 모드. 주사율은 현재와 가장 가까운 값.
    static func hiDPICounterpart(_ modes: [DisplayMode], current: DisplayMode, nativeWidth: Int, nativeHeight: Int) -> DisplayMode? {
        let wanted = !current.isHiDPI
        let candidates = modes.filter { $0.isHiDPI == wanted }
        guard !candidates.isEmpty else { return nil }
        let sameSize = candidates.filter { $0.width == current.width && $0.height == current.height }
        if let match = closestRefresh(sameSize, to: current) { return match }
        if wanted {
            let pixelExact = candidates.filter { $0.pixelWidth == nativeWidth && $0.pixelHeight == nativeHeight }
            if let match = closestRefresh(pixelExact, to: current) { return match }
        } else {
            let native = candidates.filter { $0.width == nativeWidth && $0.height == nativeHeight }
            if let match = closestRefresh(native, to: current) { return match }
        }
        let area = current.width * current.height
        guard let nearest = candidates.min(by: { abs($0.width * $0.height - area) < abs($1.width * $1.height - area) }) else { return nil }
        return closestRefresh(candidates.filter { $0.width == nearest.width && $0.height == nearest.height }, to: current)
    }
}

/// 현재 모드의 해상도 구성: 보이는 해상도, 배율, 렌더링 해상도, 전송 해상도.
public struct ResolutionBreakdown: Equatable, Sendable {
    /// 보이는 해상도 (논리 해상도, 포인트). 창과 글자의 크기를 정함.
    public var logicalWidth: Int
    public var logicalHeight: Int
    /// 렌더링 해상도 (백킹 해상도, 픽셀). 시스템이 실제로 그리는 크기.
    public var renderWidth: Int
    public var renderHeight: Int
    public var isHiDPI: Bool
    /// 디스플레이로 보내는 신호의 해상도와 주사율. 알 수 없으면 nil.
    public var transmitWidth: Int?
    public var transmitHeight: Int?
    public var transmitRefreshRate: Double?

    public init(mode: DisplayMode, transmitWidth: Int? = nil, transmitHeight: Int? = nil, transmitRefreshRate: Double? = nil) {
        logicalWidth = mode.width
        logicalHeight = mode.height
        renderWidth = mode.pixelWidth
        renderHeight = mode.pixelHeight
        isHiDPI = mode.isHiDPI
        self.transmitWidth = transmitWidth
        self.transmitHeight = transmitHeight
        self.transmitRefreshRate = transmitRefreshRate
    }

    public var logicalText: String { "\(logicalWidth) x \(logicalHeight)" }
    public var renderText: String { "\(renderWidth) x \(renderHeight) 픽셀" }

    /// 예: "2배 (HiDPI: 1포인트를 2 x 2 픽셀로 그림)"
    public var scaleText: String {
        let factor = logicalWidth > 0 ? Double(renderWidth) / Double(logicalWidth) : 1
        let number = abs(factor - factor.rounded()) < 0.01 ? String(format: "%.0f", factor) : String(format: "%.2f", factor)
        return isHiDPI ? "\(number)배 (HiDPI: 1포인트를 2 x 2 픽셀로 그림)" : "\(number)배 (HiDPI 꺼짐)"
    }

    public var transmitText: String? {
        guard let transmitWidth, let transmitHeight else { return nil }
        let rate = transmitRefreshRate.map { ", \(DisplaySummary.formatHz($0)) Hz" } ?? ""
        return "\(transmitWidth) x \(transmitHeight) 픽셀\(rate)"
    }

    /// 렌더링 해상도와 전송 해상도의 관계. 예: "렌더링한 화면을 83%로 축소해 전송"
    public var transmitNote: String? {
        guard let transmitWidth, let transmitHeight, renderWidth > 0 else { return nil }
        if transmitWidth == renderWidth && transmitHeight == renderHeight { return "렌더링한 화면을 그대로 전송 (1:1, 가장 선명)" }
        let percent = Int((Double(transmitWidth) / Double(renderWidth) * 100).rounded())
        return transmitWidth < renderWidth
            ? "렌더링한 화면을 \(percent)%로 축소해 전송"
            : "렌더링한 화면을 \(percent)%로 확대해 전송 (흐리게 보일 수 있음)"
    }
}
