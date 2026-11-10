import AppKit
import CoreGraphics
import Foundation
import TBDCore

/// HDR 상태 조회와 전환. (SRS-HDR-001)
public enum HDRService {
    // 시그니처 근거: SkyLight 디스어셈블(T06). 조회 함수는 인자 1개, 설정 함수는 인자 2개(x0 디스플레이, x1 켜기 여부).
    typealias QueryFn = @convention(c) (CGDirectDisplayID) -> Bool
    typealias SetFn = @convention(c) (CGDirectDisplayID, Bool) -> Int32

    public enum Method: String, CaseIterable, Sendable {
        /// 시스템 설정이 쓰는 MonitorPanel 경로.
        case monitorPanel
        /// 윈도우 서버 비공개 함수.
        case skyLight
    }

    public static let defaultMethods: [Method] = [.monitorPanel, .skyLight]

    public static func isSupported(_ display: CGDirectDisplayID, symbols: PrivateSymbols = .shared) -> Bool {
        if let query = symbols.function("SLSDisplaySupportsHDRMode", in: .skyLight, as: QueryFn.self) { return query(display) }
        return MPDisplayBridge(display: display, symbols: symbols)?.bool("hasHDRModes") ?? false
    }

    public static func isEnabled(_ display: CGDirectDisplayID, symbols: PrivateSymbols = .shared) -> Bool {
        if let query = symbols.function("SLSDisplayIsHDRModeEnabled", in: .skyLight, as: QueryFn.self) { return query(display) }
        return MPDisplayBridge(display: display, symbols: symbols)?.bool("preferHDRModes") ?? false
    }

    public static func status(for display: DisplaySummary, edid: EDID?, symbols: PrivateSymbols = .shared) -> HDRStatus {
        let screen = NSScreen.screens.first {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == display.id
        }
        return HDRStatus(
            displayID: display.id,
            isSupported: isSupported(display.id, symbols: symbols),
            isEnabled: isEnabled(display.id, symbols: symbols),
            currentEDRHeadroom: screen.map { Double($0.maximumExtendedDynamicRangeColorComponentValue) },
            maxEDRHeadroom: screen.map { Double($0.maximumPotentialExtendedDynamicRangeColorComponentValue) },
            supportedEOTFs: edid?.cta?.hdr?.eotfNames.filter { $0 != "SDR" } ?? [],
            maxLuminance: edid?.cta?.hdr?.maxLuminance
        )
    }

    /// HDR 켜기와 끄기. 사용한 경로 반환.
    @discardableResult
    public static func setEnabled(_ enabled: Bool, on display: CGDirectDisplayID, method: Method? = nil, symbols: PrivateSymbols = .shared) throws -> Method {
        guard ModeService.isOnline(display) else { throw DisplayChangeError.displayNotFound }
        guard isSupported(display, symbols: symbols) else { throw DisplayChangeError.unavailable("이 디스플레이는 HDR 미지원") }
        var lastError: Error = DisplayChangeError.unavailable("사용 가능한 HDR 전환 경로 없음")
        for candidate in method.map({ [$0] }) ?? defaultMethods {
            do {
                switch candidate {
                case .monitorPanel:
                    guard let bridge = MPDisplayBridge(display: display, symbols: symbols), bridge.setPreferHDRModes(enabled) else {
                        throw DisplayChangeError.unavailable("MPDisplay setPreferHDRModes: 없음")
                    }
                case .skyLight:
                    guard let set = symbols.function("SLSDisplaySetHDRModeEnabled", in: .skyLight, as: SetFn.self) else {
                        throw DisplayChangeError.unavailable("SLSDisplaySetHDRModeEnabled 없음")
                    }
                    let result = set(display, enabled)
                    guard result == 0 else { throw DisplayChangeError.system(operation: "HDR 전환", code: result) }
                }
                return candidate
            } catch DisplayChangeError.unavailable(let reason) {
                lastError = DisplayChangeError.unavailable(reason)
            }
        }
        throw lastError
    }
}
