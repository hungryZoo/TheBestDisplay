import CoreGraphics
import Foundation
import TBDCore

/// 배치 변경: 회전, 미러, 메인 지정, 위치, 연결 해제와 재연결, 언더스캔. (SRS-ARR-001-004)
public enum ArrangementService {
    // 시그니처 근거: platform-apis 문서 9.1절 (displayplacer, Crisp, lumen의 같은 선언), spikes 문서 6절(T04 실측의 SLSGetDisplayList).
    typealias ConfigureEnabledFn = @convention(c) (CGDisplayConfigRef?, CGDirectDisplayID, Bool) -> Int32
    typealias DisplayListFn = @convention(c) (UInt32, UnsafeMutablePointer<UInt32>?, UnsafeMutablePointer<UInt32>) -> Int32

    // MARK: - 회전 (SRS-ARR-002)

    public static func rotation(of display: CGDirectDisplayID) -> Int {
        Int(CGDisplayRotation(display).rounded())
    }

    /// 회전 지원 여부. 내장 디스플레이는 시스템이 지원을 보고하더라도 제외:
    /// 내장 패널 회전은 시스템 설정에 없는 동작이고 공개 소스(displayplacer)에 충돌 경고가 있음.
    public static func canRotate(_ display: CGDirectDisplayID, symbols: PrivateSymbols = .shared) -> Bool {
        guard CGDisplayIsBuiltin(display) == 0 else { return false }
        return MPDisplayBridge(display: display, symbols: symbols)?.bool("canChangeOrientation") ?? false
    }

    /// 회전 설정. 시스템 설정과 같은 MonitorPanel 경로. 적용은 비동기라 목표 각도가 될 때까지 최대 `timeout`초 대기.
    public static func setRotation(_ degrees: Int, on display: CGDirectDisplayID, timeout: TimeInterval = 10, symbols: PrivateSymbols = .shared) throws {
        guard ArrangementPlanner.isValidRotation(degrees) else { throw DisplayChangeError.modeNotFound("회전 \(degrees)도") }
        guard ModeService.isOnline(display) else { throw DisplayChangeError.displayNotFound }
        guard canRotate(display, symbols: symbols), let bridge = MPDisplayBridge(display: display, symbols: symbols) else {
            throw DisplayChangeError.unavailable("이 디스플레이는 회전을 지원하지 않음")
        }
        guard bridge.setInt("setOrientation:", Int32(degrees)) else { throw DisplayChangeError.unavailable("MPDisplay setOrientation: 없음") }
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if rotation(of: display) == degrees { return }
            usleep(100_000)
        }
        throw DisplayChangeError.system(operation: "회전 적용 대기", code: -1)
    }

    // MARK: - 미러, 메인, 위치 (SRS-ARR-001)

    /// 미러 설정. `master`가 nil이면 미러 해제.
    public static func setMirror(_ display: CGDirectDisplayID, master: CGDirectDisplayID?) throws {
        try ModeService.configure(permanently: true) { config in
            CGConfigureDisplayMirrorOfDisplay(config, display, master ?? kCGNullDirectDisplay).rawValue
        }
    }

    /// 전 디스플레이의 원점을 한 트랜잭션으로 지정.
    public static func apply(_ frames: [DisplayFrame]) throws {
        try ModeService.configure(permanently: true) { config in
            for frame in frames {
                let result = CGConfigureDisplayOrigin(config, frame.id, Int32(frame.x), Int32(frame.y))
                if result != .success { return result.rawValue }
            }
            return 0
        }
    }

    public static func setMain(_ display: CGDirectDisplayID, displays: [DisplaySummary]) throws {
        // 미러 대상은 독립 원점이 없으므로 제외.
        let frames = displays.filter { $0.mirrorsDisplayID == nil }.map(DisplayFrame.init)
        guard let planned = ArrangementPlanner.makeMain(display, frames: frames) else { throw DisplayChangeError.displayNotFound }
        try apply(planned)
    }

    /// 위치 이동. 요청 좌표는 다른 디스플레이와 맞닿는 가장 가까운 위치로 보정. 적용한 좌표 반환.
    @discardableResult
    public static func move(_ display: CGDirectDisplayID, toX x: Int, y: Int, displays: [DisplaySummary]) throws -> DisplayFrame {
        let frames = displays.filter { $0.mirrorsDisplayID == nil }.map(DisplayFrame.init)
        guard let moved = ArrangementPlanner.move(display, toX: x, y: y, frames: frames) else { throw DisplayChangeError.displayNotFound }
        // 메인 디스플레이가 원점에 있도록 평행 이동.
        let main = displays.first(where: \.isMain)?.id ?? display
        let planned = ArrangementPlanner.normalized(moved, main: main)
        try apply(planned)
        return planned.first { $0.id == display } ?? DisplayFrame(id: display, x: x, y: y, width: 0, height: 0)
    }

    // MARK: - 연결 해제와 재연결 (SRS-ARR-003)

    /// 윈도우 서버가 아는 디스플레이 ID 전체 (온라인이 아닌 것 포함).
    static func knownDisplayIDs(symbols: PrivateSymbols = .shared) -> [CGDirectDisplayID] {
        guard let list = symbols.function("SLSGetDisplayList", in: .skyLight, as: DisplayListFn.self) else { return [] }
        var count: UInt32 = 0
        var ids = [UInt32](repeating: 0, count: 16)
        guard list(16, &ids, &count) == 0 else { return [] }
        return Array(ids.prefix(Int(count)))
    }

    /// 온라인이 아닌 디스플레이 ID. 재연결 후보.
    public static func offlineDisplayIDs(symbols: PrivateSymbols = .shared) -> [CGDirectDisplayID] {
        let online = Set(DisplayCatalog.onlineDisplayIDs())
        return knownDisplayIDs(symbols: symbols).filter { !online.contains($0) }
    }

    static func setEnabled(_ enabled: Bool, display: CGDirectDisplayID, symbols: PrivateSymbols) throws {
        guard let configure = symbols.function("SLSConfigureDisplayEnabled", in: .skyLight, as: ConfigureEnabledFn.self) else {
            throw DisplayChangeError.unavailable("SLSConfigureDisplayEnabled 없음")
        }
        try ModeService.configure(permanently: true) { config in configure(config, display, enabled) }
    }

    /// 논리적 연결 해제. 마지막 온라인 디스플레이는 거부. (PRD-SAF-003)
    public static func disconnect(_ display: CGDirectDisplayID, symbols: PrivateSymbols = .shared) throws {
        if let refusal = ArrangementPlanner.disconnectRefusal(display, online: DisplayCatalog.onlineDisplayIDs()) {
            throw DisplayChangeError.unavailable(refusal)
        }
        try setEnabled(false, display: display, symbols: symbols)
    }

    /// 재연결. 구성 적용의 반환값만으로는 성공을 판정할 수 없어 온라인 목록에 나타날 때까지 최대 `timeout`초 대기.
    public static func reconnect(_ display: CGDirectDisplayID, timeout: TimeInterval = 15, symbols: PrivateSymbols = .shared) throws {
        guard !ModeService.isOnline(display) else { return }
        try setEnabled(true, display: display, symbols: symbols)
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if ModeService.isOnline(display) { return }
            usleep(200_000)
        }
        throw DisplayChangeError.system(operation: "재연결 대기", code: -1)
    }

    // MARK: - 언더스캔 (SRS-ARR-004)

    public struct Underscan: Equatable, Sendable {
        public var value: Int
        public var minimum: Int
        public var maximum: Int
    }

    /// 언더스캔 지원 디스플레이의 현재값과 범위. 미지원이면 nil. 시스템 설정과 같은 MonitorPanel 경로.
    public static func underscan(of display: CGDirectDisplayID, symbols: PrivateSymbols = .shared) -> Underscan? {
        guard let bridge = MPDisplayBridge(display: display, symbols: symbols), bridge.bool("supportsUnderscan") == true,
              let value = bridge.int("underscan"), let minimum = bridge.int("minUnderscan"), let maximum = bridge.int("maxUnderscan"), maximum > minimum
        else { return nil }
        return Underscan(value: value, minimum: minimum, maximum: maximum)
    }

    public static func setUnderscan(_ value: Int, on display: CGDirectDisplayID, symbols: PrivateSymbols = .shared) throws {
        guard let current = underscan(of: display, symbols: symbols), let bridge = MPDisplayBridge(display: display, symbols: symbols) else {
            throw DisplayChangeError.unavailable("이 디스플레이는 언더스캔을 지원하지 않음")
        }
        let clamped = min(max(value, current.minimum), current.maximum)
        guard bridge.setInt("setUnderscan:", Int32(clamped)) else { throw DisplayChangeError.unavailable("MPDisplay setUnderscan: 없음") }
    }
}
