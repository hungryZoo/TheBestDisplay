import AppKit
import TBDCore

/// 오버레이 방식 디밍: 대상 화면 전체를 덮는 검은 창의 불투명도로 밝기를 낮춤. (SRS-BRT-004)
/// 마우스 입력은 통과. 프로세스 수명에 종속. 화면 캡처에도 어둡게 찍힘.
@MainActor
public final class OverlayDimService {
    public static let shared = OverlayDimService()

    private var windows: [CGDirectDisplayID: NSWindow] = [:]
    private var strengths: [CGDirectDisplayID: Double] = [:]

    public func strength(for display: CGDirectDisplayID) -> Double { strengths[display] ?? 0 }

    public func setStrength(_ value: Double, for display: CGDirectDisplayID) throws {
        let strength = OverlayDim.clamped(value)
        guard strength > 0.001 else {
            close(display)
            return
        }
        guard let screen = XDRBoostService.screen(for: display) else {
            throw DisplayChangeError.unavailable("오버레이 창을 놓을 화면 없음 (미러 대상 또는 비활성)")
        }
        let window = windows[display] ?? {
            let w = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
            w.level = .screenSaver
            w.ignoresMouseEvents = true
            w.isOpaque = false
            w.hasShadow = false
            w.isReleasedWhenClosed = false
            w.backgroundColor = .black
            w.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
            windows[display] = w
            return w
        }()
        window.setFrame(screen.frame, display: true)
        window.alphaValue = strength
        window.orderFrontRegardless()
        strengths[display] = strength
    }

    public func resetAll() {
        for display in Array(windows.keys) { close(display) }
    }

    /// 구성 변경 뒤 호출: 사라진 화면의 창 정리, 남은 창은 화면 크기에 다시 맞춤.
    public func refresh(onlineDisplays: [CGDirectDisplayID]) {
        for (display, window) in windows {
            guard onlineDisplays.contains(display), let screen = XDRBoostService.screen(for: display) else {
                close(display)
                continue
            }
            window.setFrame(screen.frame, display: true)
        }
    }

    /// 확인용: 현재 덮개 창의 번호와 불투명도.
    public func windowInfo(for display: CGDirectDisplayID) -> (number: Int, alpha: Double, frame: CGRect)? {
        windows[display].map { ($0.windowNumber, Double($0.alphaValue), $0.frame) }
    }

    private func close(_ display: CGDirectDisplayID) {
        windows[display]?.orderOut(nil)
        windows[display] = nil
        strengths[display] = nil
    }
}
