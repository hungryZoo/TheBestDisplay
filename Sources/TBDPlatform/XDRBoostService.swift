import AppKit
import Metal
import QuartzCore
import TBDCore

/// XDR 밝기 업스케일. (SRS-BRT-002, PRD-BRT-005)
///
/// 2단계 구조:
/// - (1) EDR 유지 창: 대상 화면 구석의 8포인트 창에 1.0을 넘는 값을 그려 시스템이 EDR 헤드룸을 열어 두게 함.
/// - (2) 전달 테이블: `GammaService`가 출력값에 배율을 곱함. 헤드룸 안의 값은 SDR 흰색보다 밝게 출력.
///
/// 프로세스 수명에 종속. 창이 닫히거나 프로세스가 끝나면 원래 밝기로 복귀.
/// 근거: `spikes/03_xdr_probe` (1.4배 전달 테이블 값의 유지 확인).
@MainActor
public final class XDRBoostService {
    public static let shared = XDRBoostService()

    private var windows: [CGDirectDisplayID: NSWindow] = [:]
    private let device = MTLCreateSystemDefaultDevice()
    private lazy var queue = device?.makeCommandQueue()

    public static func screen(for display: CGDirectDisplayID) -> NSScreen? {
        NSScreen.screens.first { ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == display }
    }

    /// 화면이 낼 수 있는 최대 EDR 헤드룸. 1 이하이면 업스케일 대상이 아님.
    public static func potentialHeadroom(_ display: CGDirectDisplayID) -> Double {
        Double(screen(for: display)?.maximumPotentialExtendedDynamicRangeColorComponentValue ?? 1)
    }

    public static func currentHeadroom(_ display: CGDirectDisplayID) -> Double {
        Double(screen(for: display)?.maximumExtendedDynamicRangeColorComponentValue ?? 1)
    }

    public static func isSupported(_ display: CGDirectDisplayID) -> Bool {
        potentialHeadroom(display) > 1.01
    }

    /// 허용 배율 상한: 조정 범위 상한과 잠재 헤드룸 중 작은 값.
    public static func maximumBoost(_ display: CGDirectDisplayID) -> Double {
        min(ColorAdjustment.xdrBoostRange.upperBound, max(1, potentialHeadroom(display)))
    }

    public func boost(for display: CGDirectDisplayID) -> Double {
        GammaService.shared.adjustment(for: display).xdrBoost
    }

    public var isActive: Bool { !windows.isEmpty }

    /// 배율 지정. 1 이하이면 해제.
    public func setBoost(_ value: Double, for display: CGDirectDisplayID) throws {
        var adjustment = GammaService.shared.adjustment(for: display)
        if value <= 1.001 {
            adjustment.xdrBoost = 1
            try GammaService.shared.apply(adjustment, to: display)
            closeWindow(display)
            return
        }
        guard Self.isSupported(display) else {
            throw DisplayChangeError.unavailable("이 디스플레이는 EDR 헤드룸이 없어 XDR 밝기 업스케일 불가")
        }
        try openWindow(display)
        adjustment.xdrBoost = min(value, Self.maximumBoost(display))
        try GammaService.shared.apply(adjustment, to: display)
    }

    /// 전체 해제. 앱 종료 시 호출.
    public func resetAll() {
        for display in Array(windows.keys) {
            var adjustment = GammaService.shared.adjustment(for: display)
            adjustment.xdrBoost = 1
            try? GammaService.shared.apply(adjustment, to: display)
            closeWindow(display)
        }
    }

    /// 디스플레이 구성 변경 뒤 호출: 사라진 디스플레이의 창 정리, 남은 창은 화면 구석으로 다시 배치하고 다시 그림.
    public func refresh(onlineDisplays: [CGDirectDisplayID]) {
        for display in Array(windows.keys) {
            guard onlineDisplays.contains(display), let screen = Self.screen(for: display), let window = windows[display] else {
                closeWindow(display)
                continue
            }
            window.setFrame(Self.frame(on: screen), display: true)
            draw(window)
        }
    }

    static func frame(on screen: NSScreen) -> NSRect {
        NSRect(x: screen.frame.minX, y: screen.frame.minY, width: 8, height: 8)
    }

    private func openWindow(_ display: CGDirectDisplayID) throws {
        if let existing = windows[display] {
            draw(existing)
            return
        }
        guard let screen = Self.screen(for: display), let device else {
            throw DisplayChangeError.unavailable("EDR 유지 창을 만들 수 없음 (화면 또는 Metal 장치 없음)")
        }
        let window = NSWindow(contentRect: Self.frame(on: screen), styleMask: .borderless, backing: .buffered, defer: false)
        window.level = .screenSaver
        window.ignoresMouseEvents = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        let layer = CAMetalLayer()
        layer.device = device
        layer.pixelFormat = .rgba16Float
        layer.wantsExtendedDynamicRangeContent = true
        layer.colorspace = CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3)
        layer.frame = CGRect(x: 0, y: 0, width: 8, height: 8)
        layer.drawableSize = CGSize(width: 16, height: 16)
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 8, height: 8))
        view.wantsLayer = true
        view.layer = layer
        window.contentView = view
        window.orderFrontRegardless()
        windows[display] = window
        draw(window)
    }

    private func closeWindow(_ display: CGDirectDisplayID) {
        windows[display]?.orderOut(nil)
        windows[display] = nil
    }

    /// 1.0을 넘는 단색을 그려 EDR 콘텐츠가 화면에 있는 상태 유지.
    private func draw(_ window: NSWindow) {
        guard let layer = window.contentView?.layer as? CAMetalLayer, let drawable = layer.nextDrawable(), let queue else { return }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = drawable.texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = MTLClearColor(red: 4, green: 4, blue: 4, alpha: 1)
        guard let buffer = queue.makeCommandBuffer(), let encoder = buffer.makeRenderCommandEncoder(descriptor: pass) else { return }
        encoder.endEncoding()
        buffer.present(drawable)
        buffer.commit()
    }
}
