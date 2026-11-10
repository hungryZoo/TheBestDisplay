import Foundation

/// Night Shift 상태. (PRD-CLR-003)
public struct NightShiftStatus: Codable, Hashable, Sendable {
    /// 이 기기의 Night Shift 지원 여부.
    public var isSupported: Bool
    /// 사용자가 켠 상태인지 (수동 또는 일정).
    public var isEnabled: Bool
    /// 상태 구조체의 첫 플래그. 의미 미확정: Night Shift가 꺼진 상태에서도 참으로 관측(T11 실측)되어 화면에 표시하지 않음.
    public var isActive: Bool
    /// 강도 0-1. 조회 불가 시 nil.
    public var strength: Double?
    /// 0 일정 없음, 1 일몰부터 일출까지, 2 사용자 지정 시간.
    public var scheduleMode: Int

    public init(isSupported: Bool, isEnabled: Bool, isActive: Bool, strength: Double?, scheduleMode: Int) {
        self.isSupported = isSupported
        self.isEnabled = isEnabled
        self.isActive = isActive
        self.strength = strength
        self.scheduleMode = scheduleMode
    }

    public var scheduleName: String {
        switch scheduleMode {
        case 0: "일정 없음"
        case 1: "일몰부터 일출까지"
        case 2: "사용자 지정 시간"
        default: "알 수 없음 (\(scheduleMode))"
        }
    }

    /// `CBBlueLightClient getBlueLightStatus:`가 채우는 구조체 해석.
    /// 형식 부호 `{BBBi{{ii}{ii}}QB}`: 0 활성, 1 켜짐, 2 일출 일몰 일정 허용, 4 모드, 8 일정(16바이트), 24 비활성 플래그, 32 사용 가능.
    public static let statusStructSize = 40

    public static func decodeStatus(_ bytes: [UInt8], strength: Double?) -> NightShiftStatus? {
        guard bytes.count >= statusStructSize else { return nil }
        let mode = Int(Int32(bitPattern: UInt32(bytes[4]) | UInt32(bytes[5]) << 8 | UInt32(bytes[6]) << 16 | UInt32(bytes[7]) << 24))
        return NightShiftStatus(isSupported: bytes[32] != 0, isEnabled: bytes[1] != 0, isActive: bytes[0] != 0, strength: strength, scheduleMode: mode)
    }
}

/// True Tone 상태. (PRD-CLR-004)
public struct TrueToneStatus: Codable, Hashable, Sendable {
    /// 하드웨어 지원 여부.
    public var isSupported: Bool
    /// 현재 구성에서 사용 가능한지 (주변광 센서가 있는 디스플레이가 켜져 있어야 함).
    public var isAvailable: Bool
    public var isEnabled: Bool

    public init(isSupported: Bool, isAvailable: Bool, isEnabled: Bool) {
        self.isSupported = isSupported
        self.isAvailable = isAvailable
        self.isEnabled = isEnabled
    }

    public var stateLabel: String {
        if !isSupported { return "미지원" }
        if !isAvailable { return "현재 사용 불가" }
        return isEnabled ? "켜짐" : "꺼짐"
    }
}

/// 디스플레이에 지정할 수 있는 색 프로파일 1개. (PRD-CLR-001)
public struct ColorProfileInfo: Codable, Hashable, Sendable, Identifiable {
    public var name: String
    public var path: String
    /// 디스플레이의 기본(공장) 프로파일인지.
    public var isFactoryDefault: Bool

    public init(name: String, path: String, isFactoryDefault: Bool) {
        self.name = name
        self.path = path
        self.isFactoryDefault = isFactoryDefault
    }

    public var id: String { path }
}

public enum ColorProfileCatalog {
    /// 표시 순서: 기본 프로파일 먼저, 나머지는 이름순. 같은 경로는 한 번만.
    public static func sorted(_ profiles: [ColorProfileInfo]) -> [ColorProfileInfo] {
        var seen = Set<String>()
        return profiles
            .filter { seen.insert($0.path).inserted }
            .sorted { ($0.isFactoryDefault ? 0 : 1, $0.name.lowercased(), $0.path) < ($1.isFactoryDefault ? 0 : 1, $1.name.lowercased(), $1.path) }
    }
}
