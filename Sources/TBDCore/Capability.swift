import Foundation

/// 비공개 심볼이 속한 프레임워크. (SRS-ARC-002)
public enum PrivateFramework: String, Codable, CaseIterable, Sendable {
    case skyLight
    case ioMobileFramebuffer
    case displayServices
    case coreDisplay
    case ioKit
    case monitorPanel
    case coreBrightness

    public var path: String {
        switch self {
        case .skyLight: "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight"
        case .ioMobileFramebuffer: "/System/Library/PrivateFrameworks/IOMobileFramebuffer.framework/IOMobileFramebuffer"
        case .displayServices: "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices"
        case .coreDisplay: "/System/Library/Frameworks/CoreDisplay.framework/CoreDisplay"
        case .ioKit: "/System/Library/Frameworks/IOKit.framework/IOKit"
        case .monitorPanel: "/System/Library/PrivateFrameworks/MonitorPanel.framework/MonitorPanel"
        case .coreBrightness: "/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness"
        }
    }
}

/// 기능이 요구하는 심볼 또는 Objective-C 클래스.
public enum SymbolRequirement: Hashable, Sendable {
    case function(PrivateFramework, String)
    case objcClass(PrivateFramework, String)

    public var name: String {
        switch self {
        case .function(_, let name), .objcClass(_, let name): name
        }
    }
}

/// 실행 환경에 따라 가용 여부가 달라지는 기능 단위. (PRD-APP-005)
public enum Capability: String, Codable, CaseIterable, Sendable {
    case modeEnumeration
    case modeSwitch
    case signalRead
    case signalWrite
    case linkData
    case hdr
    case dpcd
    case ddc
    case nativeBrightness
    case rotation
    case displayEnable
    case underscan
    case virtualDisplay
    case nightShift
    case trueTone
    case edidOverride
    case redetect

    public var title: String {
        switch self {
        case .modeEnumeration: "전체 모드 열거"
        case .modeSwitch: "모드 전환"
        case .signalRead: "신호 형식 조회"
        case .signalWrite: "색 모드 전환"
        case .linkData: "링크 데이터 조회"
        case .hdr: "HDR 조회와 전환"
        case .dpcd: "DPCD 읽기"
        case .ddc: "DDC 제어"
        case .nativeBrightness: "하드웨어 밝기 제어"
        case .rotation: "회전"
        case .displayEnable: "연결 해제와 재연결"
        case .underscan: "언더스캔"
        case .virtualDisplay: "가상 디스플레이"
        case .nightShift: "Night Shift"
        case .trueTone: "True Tone"
        case .edidOverride: "EDID 오버라이드"
        case .redetect: "디스플레이 재감지"
        }
    }

    public var requirements: [SymbolRequirement] {
        switch self {
        case .modeEnumeration:
            [.function(.skyLight, "SLSGetNumberOfDisplayModes"), .function(.skyLight, "SLSGetDisplayModeDescriptionOfLength"), .function(.skyLight, "SLSGetCurrentDisplayMode")]
        case .modeSwitch:
            [.function(.skyLight, "SLSConfigureDisplayMode")]
        case .signalRead:
            [.function(.ioMobileFramebuffer, "IOMobileFramebufferOpen"), .function(.ioMobileFramebuffer, "IOMobileFramebufferGetDigitalOutMode")]
        case .signalWrite:
            [.function(.ioMobileFramebuffer, "IOMobileFramebufferOpen"), .function(.ioMobileFramebuffer, "IOMobileFramebufferSetDigitalOutMode")]
        case .linkData:
            [.function(.ioKit, "IOAVServiceCreateWithService"), .function(.ioKit, "IOAVServiceGetLinkData")]
        case .hdr:
            [.function(.skyLight, "SLSDisplaySupportsHDRMode"), .function(.skyLight, "SLSDisplayIsHDRModeEnabled"), .function(.skyLight, "SLSDisplaySetHDRModeEnabled")]
        case .dpcd:
            [.function(.ioKit, "IODPDeviceCreateWithService"), .function(.ioKit, "IODPDeviceReadDPCD")]
        case .ddc:
            [.function(.ioKit, "IOAVServiceCreateWithService"), .function(.ioKit, "IOAVServiceReadI2C"), .function(.ioKit, "IOAVServiceWriteI2C")]
        case .nativeBrightness:
            [.function(.displayServices, "DisplayServicesGetBrightness"), .function(.displayServices, "DisplayServicesSetBrightness"), .function(.displayServices, "DisplayServicesCanChangeBrightness")]
        case .rotation:
            [.objcClass(.monitorPanel, "MPDisplay")]
        case .displayEnable:
            [.function(.skyLight, "SLSConfigureDisplayEnabled")]
        case .underscan:
            [.function(.skyLight, "SLSDisplayGetUnderscan"), .function(.skyLight, "SLSDisplaySetUnderscan")]
        case .virtualDisplay:
            [.objcClass(.skyLight, "CGVirtualDisplay"), .objcClass(.skyLight, "CGVirtualDisplayDescriptor"), .objcClass(.skyLight, "CGVirtualDisplaySettings"), .objcClass(.skyLight, "CGVirtualDisplayMode")]
        case .nightShift:
            [.objcClass(.coreBrightness, "CBBlueLightClient")]
        case .trueTone:
            [.objcClass(.coreBrightness, "CBTrueToneClient")]
        case .edidOverride:
            [.function(.ioKit, "IOAVServiceCreateWithService"), .function(.ioKit, "IOAVServiceSetVirtualEDIDMode")]
        case .redetect:
            [.function(.skyLight, "SLSDetectDisplays")]
        }
    }
}

/// 기능 1개의 가용성 판정 결과.
public struct CapabilityStatus: Codable, Hashable, Sendable {
    public var capability: Capability
    public var isAvailable: Bool
    public var missingSymbols: [String]

    public init(capability: Capability, isAvailable: Bool, missingSymbols: [String]) {
        self.capability = capability
        self.isAvailable = isAvailable
        self.missingSymbols = missingSymbols
    }

    /// 비활성 사유 문구. 가용이면 nil.
    public var unavailableReason: String? {
        guard !isAvailable else { return nil }
        return "이 macOS에서 필요한 시스템 기능을 찾을 수 없음: \(missingSymbols.joined(separator: ", "))"
    }
}

public extension Capability {
    /// 심볼 존재 판정 함수를 받아 가용성을 계산. 판정 함수 주입으로 단위 테스트 가능.
    func status(isPresent: (SymbolRequirement) -> Bool) -> CapabilityStatus {
        let missing = requirements.filter { !isPresent($0) }.map(\.name)
        return CapabilityStatus(capability: self, isAvailable: missing.isEmpty, missingSymbols: missing)
    }
}
