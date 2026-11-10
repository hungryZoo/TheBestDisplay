import Foundation

/// 디스플레이의 HDR 상태와 정보. (PRD-HDR-001, PRD-HDR-003)
public struct HDRStatus: Codable, Hashable, Sendable {
    public var displayID: UInt32
    public var isSupported: Bool
    public var isEnabled: Bool
    /// 현재 EDR 헤드룸 (SDR 흰색 대비 배수). 1이면 헤드룸 없음. 조회 불가 시 nil.
    public var currentEDRHeadroom: Double?
    /// 디스플레이가 낼 수 있는 최대 EDR 헤드룸.
    public var maxEDRHeadroom: Double?
    /// 싱크가 선언한 HDR 전달 함수 이름 (EDID 기준).
    public var supportedEOTFs: [String]
    /// 싱크가 선언한 최대 휘도 (cd/m², EDID 기준). 미보고 시 nil.
    public var maxLuminance: Double?

    public init(displayID: UInt32, isSupported: Bool, isEnabled: Bool, currentEDRHeadroom: Double?, maxEDRHeadroom: Double?, supportedEOTFs: [String], maxLuminance: Double?) {
        self.displayID = displayID
        self.isSupported = isSupported
        self.isEnabled = isEnabled
        self.currentEDRHeadroom = currentEDRHeadroom
        self.maxEDRHeadroom = maxEDRHeadroom
        self.supportedEOTFs = supportedEOTFs
        self.maxLuminance = maxLuminance
    }

    public var stateLabel: String {
        if !isSupported { return hasAlwaysOnEDR ? "전환 항목 없음 (EDR 상시 지원)" : "미지원" }
        return isEnabled ? "켜짐" : "꺼짐"
    }

    /// HDR 전환 항목은 없지만 EDR 헤드룸을 가진 디스플레이 (내장 XDR 패널 등).
    public var hasAlwaysOnEDR: Bool {
        !isSupported && (maxEDRHeadroom ?? 1) > 1
    }

    /// 색 모드의 전달 함수가 HDR 상태와 어긋나는지. 어긋난 선택은 화면 이상(빈 화면, 색 왜곡) 가능성이 있어 경고 대상.
    public func isMismatched(with eotf: EOTF) -> Bool {
        isSupported && eotf.isHDR != isEnabled
    }
}

/// 명령행의 켜기와 끄기 값 해석.
public enum Toggle {
    public static func parse(_ text: String) -> Bool? {
        switch text.lowercased() {
        case "on", "1", "true", "yes": true
        case "off", "0", "false", "no": false
        default: nil
        }
    }
}
