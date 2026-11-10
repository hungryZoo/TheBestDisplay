import CoreGraphics
import Foundation
import TBDCore

/// 가상 디스플레이 생성과 삭제, HiDPI 스케일링. `CGVirtualDisplay` 동적 호출. 형식 부호는 T13 실측. (SRS-VRT-001, SRS-VRT-002)
/// 가상 디스플레이는 객체가 살아 있는 동안만 존재하므로 프로세스 수명에 종속. (ADR-0004)
public final class VirtualDisplayService: @unchecked Sendable {
    public static let shared = VirtualDisplayService()

    /// 가상 디스플레이 식별용 제조사와 제품 ID.
    public static let vendorID: UInt32 = 0x5442
    public static let productID: UInt32 = 0x4431

    private struct Active {
        var object: NSObject
        var displayID: CGDirectDisplayID
        var config: VirtualDisplayConfig
    }

    private let lock = NSLock()
    private let callbackQueue = DispatchQueue(label: "dev.thebestdisplay.virtual-display")
    private var active: [UUID: Active] = [:]
    /// HiDPI 스케일링 중인 대상: 실제 디스플레이 ID와 가상 디스플레이 구성 식별자.
    private var scaling: [CGDirectDisplayID: UUID] = [:]

    public init() {}

    public var activeDisplayIDs: [UUID: CGDirectDisplayID] {
        lock.lock()
        defer { lock.unlock() }
        return active.mapValues(\.displayID)
    }

    public func isVirtual(_ display: CGDirectDisplayID) -> Bool {
        activeDisplayIDs.values.contains(display)
    }

    public func scalingConfig(for display: CGDirectDisplayID) -> VirtualDisplayConfig? {
        lock.lock()
        defer { lock.unlock() }
        return scaling[display].flatMap { active[$0]?.config }
    }

    /// 가상 디스플레이 생성. 온라인 목록에 나타날 때까지 최대 `timeout`초 대기.
    @discardableResult
    public func create(_ config: VirtualDisplayConfig, timeout: TimeInterval = 5, symbols: PrivateSymbols = .shared) throws -> CGDirectDisplayID {
        let issues = config.validationIssues()
        guard issues.isEmpty else { throw DisplayChangeError.unavailable(issues.joined(separator: ", ")) }
        // 구성 검증과 별개의 최종 방어: 상한을 넘는 크기를 윈도우 서버에 넘기면 WindowServer가 중단될 수 있음 (T50 실측).
        guard config.pixelWidth <= VirtualDisplayConfig.maxPixelWidth, config.pixelHeight <= VirtualDisplayConfig.maxPixelHeight else {
            throw DisplayChangeError.unavailable("가상 디스플레이 크기가 상한 \(VirtualDisplayConfig.maxPixelWidth) x \(VirtualDisplayConfig.maxPixelHeight) 픽셀 초과")
        }
        lock.lock()
        let existing = active[config.id]?.displayID
        lock.unlock()
        if let existing { return existing }

        guard let descriptorClass = symbols.objcClass("CGVirtualDisplayDescriptor", in: .skyLight) as? NSObject.Type,
              let displayClass = symbols.objcClass("CGVirtualDisplay", in: .skyLight) as? NSObject.Type,
              let settingsClass = symbols.objcClass("CGVirtualDisplaySettings", in: .skyLight) as? NSObject.Type,
              let modeClass = symbols.objcClass("CGVirtualDisplayMode", in: .skyLight) as? NSObject.Type
        else { throw DisplayChangeError.unavailable("CGVirtualDisplay 클래스 없음") }

        let descriptor = descriptorClass.init()
        let size = config.sizeInMillimeters
        descriptor.setValue(config.name, forKey: "name")
        descriptor.setValue(NSNumber(value: UInt32(config.pixelWidth)), forKey: "maxPixelsWide")
        descriptor.setValue(NSNumber(value: UInt32(config.pixelHeight)), forKey: "maxPixelsHigh")
        descriptor.setValue(NSValue(size: NSSize(width: size.width, height: size.height)), forKey: "sizeInMillimeters")
        descriptor.setValue(NSNumber(value: Self.vendorID), forKey: "vendorID")
        descriptor.setValue(NSNumber(value: Self.productID), forKey: "productID")
        descriptor.setValue(NSNumber(value: config.serialNumber), forKey: "serialNum")
        // 메인 큐를 쓰면 메인 스레드에서 생성을 기다리는 동안 디스플레이가 온라인이 되지 않음 (T13 실측). 전용 큐 사용.
        descriptor.setValue(callbackQueue, forKey: "queue")

        // initWithDescriptor: `@24@0:8@16`
        typealias InitFn = @convention(c) (NSObject, Selector, NSObject) -> Unmanaged<NSObject>?
        let initSelector = NSSelectorFromString("initWithDescriptor:")
        guard displayClass.instancesRespond(to: initSelector),
              let allocated = displayClass.perform(NSSelectorFromString("alloc"))?.takeUnretainedValue() as? NSObject,
              let display = unsafeBitCast(allocated.method(for: initSelector), to: InitFn.self)(allocated, initSelector, descriptor)?.takeRetainedValue()
        else { throw DisplayChangeError.system(operation: "가상 디스플레이 생성", code: -1) }

        // initWithWidth:height:refreshRate:transferFunction: `@36@0:8I16I20d24I32`
        // 전달 함수 값 1은 HDR 지원 디스플레이, 0과 2는 SDR로 인식 (실험 04).
        typealias ModeInitFn = @convention(c) (NSObject, Selector, UInt32, UInt32, Double, UInt32) -> Unmanaged<NSObject>?
        let modeSelector = NSSelectorFromString("initWithWidth:height:refreshRate:transferFunction:")
        guard modeClass.instancesRespond(to: modeSelector),
              let modeAllocated = modeClass.perform(NSSelectorFromString("alloc"))?.takeUnretainedValue() as? NSObject,
              let mode = unsafeBitCast(modeAllocated.method(for: modeSelector), to: ModeInitFn.self)(modeAllocated, modeSelector, UInt32(config.width), UInt32(config.height), config.refreshRate, config.hdr ? 1 : 0)?.takeRetainedValue()
        else { throw DisplayChangeError.system(operation: "가상 디스플레이 모드 생성", code: -1) }

        let settings = settingsClass.init()
        settings.setValue(NSNumber(value: UInt32(config.hiDPI ? 1 : 0)), forKey: "hiDPI")
        settings.setValue([mode], forKey: "modes")

        // applySettings: `B24@0:8@16`
        typealias ApplyFn = @convention(c) (NSObject, Selector, NSObject) -> Bool
        let applySelector = NSSelectorFromString("applySettings:")
        guard unsafeBitCast(display.method(for: applySelector), to: ApplyFn.self)(display, applySelector, settings) else {
            throw DisplayChangeError.system(operation: "가상 디스플레이 설정 적용", code: -1)
        }
        guard let displayID = (display.value(forKey: "displayID") as? NSNumber)?.uint32Value, displayID != 0 else {
            throw DisplayChangeError.system(operation: "가상 디스플레이 ID 조회", code: -1)
        }

        lock.lock()
        active[config.id] = Active(object: display, displayID: displayID, config: config)
        lock.unlock()

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if ModeService.isOnline(displayID) {
                if config.hiDPI { selectHiDPIMode(config, displayID: displayID) }
                return displayID
            }
            Self.pause(0.1)
        }
        destroy(config.id)
        throw DisplayChangeError.system(operation: "가상 디스플레이 온라인 대기", code: -1)
    }

    /// 대기. 창 앱의 메인 스레드에서는 런 루프를 돌려야 새 디스플레이가 프로세스의 온라인 목록에 반영됨
    /// (T39 실측: 메인 스레드를 막고 기다리면 다른 프로세스에는 보이는 가상 디스플레이가 앱 안에서는 온라인으로 잡히지 않음).
    static func pause(_ seconds: TimeInterval) {
        if Thread.isMainThread {
            RunLoop.current.run(until: Date().addingTimeInterval(seconds))
        } else {
            usleep(useconds_t(seconds * 1_000_000))
        }
    }

    /// 생성 직후의 가상 디스플레이를 HiDPI 모드로 맞춤. 판정은 윈도우 서버의 현재 모드 기준.
    /// 실패해도 디스플레이는 유지 (해상도 탭에서 수동 전환 가능).
    private func selectHiDPIMode(_ config: VirtualDisplayConfig, displayID: CGDirectDisplayID) {
        for _ in 0..<30 {
            let modes = ModeService.modes(for: displayID)
            if let target = modes.first(where: { $0.width == config.width && $0.height == config.height && $0.isHiDPI }) {
                if ModeService.currentModeNumber(for: displayID) == target.modeNumber { return }
                _ = try? ModeService.setMode(target, on: displayID, permanently: true)
            }
            Self.pause(0.1)
        }
    }

    /// 가상 디스플레이 삭제: 객체를 놓으면 시스템이 디스플레이를 제거.
    public func destroy(_ id: UUID) {
        lock.lock()
        active[id] = nil
        scaling = scaling.filter { $0.value != id }
        lock.unlock()
    }

    public func destroyAll() {
        lock.lock()
        active.removeAll()
        scaling.removeAll()
        lock.unlock()
    }

    // MARK: - HiDPI 스케일링

    /// 대상 디스플레이를 HiDPI 가상 디스플레이의 미러로 구성. 가상 디스플레이의 ID 반환.
    @discardableResult
    public func startScaling(target: DisplaySummary, logicalWidth: Int, logicalHeight: Int) throws -> CGDirectDisplayID {
        try stopScaling(target: target.id)
        let config = HiDPIScaling.config(for: target, logicalWidth: logicalWidth, logicalHeight: logicalHeight)
        let virtualID = try create(config)
        do {
            // 실제 디스플레이가 가상 디스플레이를 미러: 가상 디스플레이가 미러 원본.
            try ArrangementService.setMirror(target.id, master: virtualID)
        } catch {
            destroy(config.id)
            throw error
        }
        lock.lock()
        scaling[target.id] = config.id
        lock.unlock()
        return virtualID
    }

    /// 스케일링 해제: 미러 해제 후 가상 디스플레이 삭제.
    public func stopScaling(target: CGDirectDisplayID) throws {
        lock.lock()
        let id = scaling[target]
        lock.unlock()
        guard let id else { return }
        defer { destroy(id) }
        if ModeService.isOnline(target) {
            try ArrangementService.setMirror(target, master: nil)
        }
    }
}
