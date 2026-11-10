import CoreGraphics
import Foundation
import TBDCore

public enum DisplayChangeError: Error, LocalizedError, Equatable {
    case unavailable(String)
    case displayNotFound
    case modeNotFound(String)
    case system(operation: String, code: Int32)

    public var errorDescription: String? {
        switch self {
        case .unavailable(let reason): "사용할 수 없는 기능: \(reason)"
        case .displayNotFound: "대상 디스플레이를 찾을 수 없음"
        case .modeNotFound(let text): "일치하는 모드 없음: \(text)"
        case .system(let operation, let code): "\(operation) 실패 (오류 코드 \(code))"
        }
    }
}

/// 디스플레이 모드 열거와 전환. (SRS-MOD-001, SRS-MOD-002)
public enum ModeService {
    // 시그니처 근거: platform-apis 문서 1.1절 (displayplacer, AllRez, Crisp의 같은 선언), spikes 문서 S1.
    typealias GetCountFn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Int32>) -> Int32
    typealias GetDescriptionFn = @convention(c) (CGDirectDisplayID, Int32, UnsafeMutableRawPointer, Int32) -> Int32
    typealias GetCurrentFn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Int32>) -> Int32
    typealias ModeFlagFn = @convention(c) (CGDirectDisplayID, Int32) -> Bool
    /// 첫 인자는 `CGBeginDisplayConfiguration`의 설정 토큰.
    typealias ConfigureModeFn = @convention(c) (CGDisplayConfigRef?, CGDirectDisplayID, Int32) -> Int32

    /// 숨은 모드를 포함한 전체 모드. 비공개 열거를 쓸 수 없으면 공개 API로 대체.
    /// 프레임버퍼가 보고하는 소스 크기와 스케일 한도. 대응하는 노드나 속성이 없으면 nil (가상 디스플레이 등). (SRS-MOD-009)
    public static func framebufferLimits(for display: DisplaySummary) -> FramebufferLimits? {
        guard let node = SignalService.framebufferNode(for: display) else { return nil }
        defer { IOObjectRelease(node.service) }
        var properties: [String: Any] = [:]
        for key in ["IOMFBMaxSrcPixels", "IOMFBScalingLimits"] { properties[key] = IORegistry.property(node.service, key) }
        return FramebufferLimits(properties: properties)
    }

    public static func modes(for display: CGDirectDisplayID, symbols: PrivateSymbols = .shared) -> [DisplayMode] {
        let defaults = systemDefaultKeys(for: display)
        guard let getCount = symbols.function("SLSGetNumberOfDisplayModes", in: .skyLight, as: GetCountFn.self),
              let getDescription = symbols.function("SLSGetDisplayModeDescriptionOfLength", in: .skyLight, as: GetDescriptionFn.self)
        else {
            return ModeCatalog.markSystemDefault(publicModes(for: display), defaultKeys: defaults)
        }
        let isVRR = symbols.function("SLSIsDisplayModeVRR", in: .skyLight, as: ModeFlagFn.self)
        let isProMotion = symbols.function("SLSIsDisplayModeProMotion", in: .skyLight, as: ModeFlagFn.self)

        var count: Int32 = 0
        guard getCount(display, &count) == 0, count > 0 else {
            return ModeCatalog.markSystemDefault(publicModes(for: display), defaultKeys: defaults)
        }
        var result: [DisplayMode] = []
        result.reserveCapacity(Int(count))
        var buffer = [UInt8](repeating: 0, count: DisplayMode.descriptionLength)
        for index in 0..<count {
            buffer.withUnsafeMutableBytes { $0.initializeMemory(as: UInt8.self, repeating: 0) }
            guard getDescription(display, index, &buffer, Int32(DisplayMode.descriptionLength)) == 0, var mode = DisplayMode.decode(buffer) else { continue }
            mode.isVRR = isVRR?(display, index) ?? false
            mode.isProMotion = isProMotion?(display, index) ?? false
            result.append(mode)
        }
        // 시스템 설정과 같은 판정: MPDisplay의 모드별 표시 여부, 원본, 기본 모드. 조회 불가 시 공개 API 열거와 대조.
        let traits = MPDisplayBridge(display: display, symbols: symbols)?.modeTraits() ?? [:]
        guard !traits.isEmpty else { return ModeCatalog.markSystemDefault(result, defaultKeys: defaults) }
        return result.map { mode in
            var m = mode
            let t = traits[mode.modeNumber]
            m.isInSystemDefaultList = t?.isUserVisible ?? false
            m.isNative = t?.isNative ?? false
            m.isDefault = t?.isDefault ?? false
            return m
        }
    }

    public static func currentModeNumber(for display: CGDirectDisplayID, symbols: PrivateSymbols = .shared) -> Int32? {
        guard let getCurrent = symbols.function("SLSGetCurrentDisplayMode", in: .skyLight, as: GetCurrentFn.self) else { return nil }
        var number: Int32 = -1
        return getCurrent(display, &number) == 0 && number >= 0 ? number : nil
    }

    /// 현재 모드. 비공개 조회 불가 시 공개 API의 현재 모드와 해상도, 주사율이 같은 모드.
    public static func currentMode(for display: CGDirectDisplayID, in modes: [DisplayMode]) -> DisplayMode? {
        if let number = currentModeNumber(for: display), let mode = modes.first(where: { $0.modeNumber == number }) { return mode }
        guard let cg = CGDisplayCopyDisplayMode(display) else { return nil }
        return ModeDescriptor(width: cg.width, height: cg.height, isHiDPI: cg.pixelWidth >= cg.width * 2, refreshRate: cg.refreshRate).find(in: modes)
    }

    /// 모드 전환 경로.
    public enum Method: String, CaseIterable, Sendable {
        /// 시스템 설정이 쓰는 MonitorPanel 경로. 항상 시스템 설정에 저장.
        case monitorPanel
        /// 공개 API. 공개 목록에 있는 모드만 가능.
        case coreGraphics
        /// 윈도우 서버 비공개 함수. 숨은 모드 포함 전체 가능.
        case skyLight
    }

    /// 기본 경로 순서. skyLight 경로는 기본 순서에서 제외하고 명시 지정 시에만 사용.
    /// T04 실측: skyLight 경로로 외장 디스플레이(독 경유 TV)의 주사율을 바꾼 뒤 디스플레이가 재인식되지 않아 케이블 재연결이 필요했음.
    /// 같은 전환을 monitorPanel 경로로 수행하면 정상 동작 (spikes 문서 6절).
    public static let defaultMethods: [Method] = [.monitorPanel, .coreGraphics]

    /// 모드 전환. `permanently`가 거짓이면 로그인 세션 동안만 유지 요청(monitorPanel 경로는 해당 없음), 참이면 시스템 설정에 저장.
    /// `method`가 nil이면 `defaultMethods` 순서로 가능한 첫 경로 사용.
    @discardableResult
    public static func setMode(_ mode: DisplayMode, on display: CGDirectDisplayID, permanently: Bool, method: Method? = nil, symbols: PrivateSymbols = .shared) throws -> Method {
        var lastError: Error = DisplayChangeError.unavailable("사용 가능한 모드 전환 경로 없음")
        for candidate in method.map({ [$0] }) ?? defaultMethods {
            do {
                switch candidate {
                case .monitorPanel:
                    guard let bridge = MPDisplayBridge(display: display, symbols: symbols), let result = bridge.setModeNumber(mode.modeNumber) else {
                        throw DisplayChangeError.unavailable("MPDisplay setModeNumber: 없음")
                    }
                    guard result == 0 else { throw DisplayChangeError.system(operation: "모드 지정 (MonitorPanel)", code: result) }
                case .coreGraphics:
                    guard let cgMode = publicCGMode(matching: mode, on: display) else {
                        throw DisplayChangeError.unavailable("공개 API 목록에 해당 모드 없음")
                    }
                    try configure(permanently: permanently) { config in
                        CGConfigureDisplayWithDisplayMode(config, display, cgMode, nil).rawValue
                    }
                case .skyLight:
                    guard let configureMode = symbols.function("SLSConfigureDisplayMode", in: .skyLight, as: ConfigureModeFn.self) else {
                        throw DisplayChangeError.unavailable("SLSConfigureDisplayMode 없음")
                    }
                    try configure(permanently: permanently) { config in
                        configureMode(config, display, mode.modeNumber)
                    }
                }
                return candidate
            } catch DisplayChangeError.unavailable(let reason) {
                // 이 경로를 쓸 수 없으면 다음 경로 시도. 시스템이 거부한 경우(오류 코드)는 다른 경로로 재시도하지 않음.
                lastError = DisplayChangeError.unavailable(reason)
            }
        }
        throw lastError
    }

    /// CoreGraphics 구성 트랜잭션 수행.
    static func configure(permanently: Bool, _ body: (CGDisplayConfigRef) -> Int32) throws {
        var config: CGDisplayConfigRef?
        let begin = CGBeginDisplayConfiguration(&config)
        guard begin == .success, let config else { throw DisplayChangeError.system(operation: "구성 시작", code: begin.rawValue) }
        let result = body(config)
        guard result == 0 else {
            CGCancelDisplayConfiguration(config)
            throw DisplayChangeError.system(operation: "모드 지정", code: result)
        }
        let complete = CGCompleteDisplayConfiguration(config, permanently ? .permanently : .forSession)
        guard complete == .success else { throw DisplayChangeError.system(operation: "구성 적용", code: complete.rawValue) }
    }

    /// 모드 서술과 일치하는 모드로 전환. 모드 번호가 바뀌어도 동작.
    public static func setMode(matching descriptor: ModeDescriptor, on display: CGDirectDisplayID, permanently: Bool, method: Method? = nil) throws {
        guard isOnline(display) else { throw DisplayChangeError.displayNotFound }
        guard let mode = descriptor.find(in: modes(for: display)) else {
            throw DisplayChangeError.modeNotFound("\(descriptor.width)x\(descriptor.height)@\(DisplaySummary.formatHz(descriptor.refreshRate))")
        }
        try setMode(mode, on: display, permanently: permanently, method: method)
    }

    public static func isOnline(_ display: CGDirectDisplayID) -> Bool {
        DisplayCatalog.onlineDisplayIDs().contains(display)
    }

    // MARK: - 공개 API

    static let allModesOptions = [kCGDisplayShowDuplicateLowResolutionModes: kCFBooleanTrue] as CFDictionary

    static func publicCGModes(for display: CGDirectDisplayID, includeDuplicates: Bool) -> [CGDisplayMode] {
        (CGDisplayCopyAllDisplayModes(display, includeDuplicates ? allModesOptions : nil) as? [CGDisplayMode]) ?? []
    }

    /// 공개 API만으로 얻은 모드 목록. 모드 번호는 `ioDisplayModeID`.
    static func publicModes(for display: CGDirectDisplayID) -> [DisplayMode] {
        publicCGModes(for: display, includeDuplicates: true).map { m in
            DisplayMode(
                modeNumber: m.ioDisplayModeID, width: m.width, height: m.height,
                pixelWidth: m.pixelWidth, pixelHeight: m.pixelHeight,
                scale: m.width > 0 ? Double(m.pixelWidth) / Double(m.width) : 1,
                refreshRate: m.refreshRate, flags: m.ioFlags
            )
        }
    }

    static func publicCGMode(matching mode: DisplayMode, on display: CGDirectDisplayID) -> CGDisplayMode? {
        publicCGModes(for: display, includeDuplicates: true).first {
            $0.width == mode.width && $0.height == mode.height && $0.pixelWidth == mode.pixelWidth && abs($0.refreshRate - mode.refreshRate) < 0.01
        }
    }

    /// 공개 API 기본 열거(옵션 없음)의 대조 키 집합. 시스템 설정 기본 목록 판정의 근거.
    static func systemDefaultKeys(for display: CGDirectDisplayID) -> Set<String> {
        Set(publicCGModes(for: display, includeDuplicates: false).map {
            ModeCatalog.defaultKey(width: $0.width, height: $0.height, pixelWidth: $0.pixelWidth, refreshRate: $0.refreshRate)
        })
    }
}
