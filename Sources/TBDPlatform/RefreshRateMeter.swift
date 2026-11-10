import AppKit
import QuartzCore
import TBDCore

/// 화면 갱신 콜백으로 주사율 측정. (SRS-MOD-005)
/// `NSScreen.displayLink`의 콜백 시각을 모아 `RefreshMeasurement.compute`로 계산. 메인 런 루프가 돌아야 콜백 수신.
@MainActor
public final class RefreshRateMeter: NSObject {
    private var link: CADisplayLink?
    private var timestamps: [Double] = []
    private var durations: [Double] = []
    private let nominalHz: Double

    public init?(display: DisplaySummary) {
        nominalHz = display.refreshRate
        super.init()
        guard let screen = NSScreen.screens.first(where: { ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == display.id }) else { return nil }
        let link = screen.displayLink(target: self, selector: #selector(tick(_:)))
        self.link = link
    }

    public func start() {
        timestamps.removeAll()
        durations.removeAll()
        link?.add(to: .main, forMode: .common)
    }

    /// 측정 종료와 결과 반환.
    public func stop() -> RefreshMeasurement {
        link?.invalidate()
        link = nil
        return RefreshMeasurement.compute(nominalHz: nominalHz, timestamps: timestamps, reportedDurations: durations)
    }

    @objc private func tick(_ link: CADisplayLink) {
        timestamps.append(link.timestamp)
        durations.append(link.targetTimestamp - link.timestamp)
    }
}
