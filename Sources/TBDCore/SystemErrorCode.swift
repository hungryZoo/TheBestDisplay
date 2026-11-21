import Foundation

/// 시스템 호출이 돌려준 오류 코드의 풀이. IOKit 반환 코드(0xE00002xx) 가운데 자주 나오는 값. (SRS-COL-010)
public enum SystemErrorCode {
    static let names: [UInt32: (name: String, meaning: String)] = [
        0xE00002BC: ("kIOReturnError", "일반 오류"),
        0xE00002BD: ("kIOReturnNoMemory", "메모리 부족"),
        0xE00002BE: ("kIOReturnNoResources", "자원 부족"),
        0xE00002C0: ("kIOReturnNoDevice", "장치 없음"),
        0xE00002C1: ("kIOReturnNotPrivileged", "권한 없음"),
        0xE00002C2: ("kIOReturnBadArgument", "잘못된 인자"),
        0xE00002C5: ("kIOReturnExclusiveAccess", "다른 프로세스가 독점 사용 중"),
        0xE00002C7: ("kIOReturnUnsupported", "지원하지 않는 동작"),
        0xE00002CD: ("kIOReturnNotOpen", "장치가 열려 있지 않음"),
        0xE00002D5: ("kIOReturnBusy", "장치 사용 중"),
        0xE00002D6: ("kIOReturnTimeout", "제한 시간 초과"),
        0xE00002D8: ("kIOReturnNotReady", "장치 준비 안 됨"),
        0xE00002E2: ("kIOReturnNotPermitted", "허용되지 않음"),
        0xE00002ED: ("kIOReturnNotResponding", "장치 응답 없음"),
        0xE00002F0: ("kIOReturnNotFound", "대상 없음"),
    ]

    /// 권한 부족으로 거부된 코드인지.
    public static func isPermissionDenied(_ code: Int32) -> Bool {
        let value = UInt32(bitPattern: code)
        return value == 0xE00002C1 || value == 0xE00002E2
    }

    /// 예: "권한 없음 (kIOReturnNotPrivileged, 0xE00002C1)". 목록에 없는 코드는 16진수만 표기.
    public static func describe(_ code: Int32) -> String {
        let value = UInt32(bitPattern: code)
        let hex = String(format: "0x%08X", value)
        guard let entry = names[value] else { return "오류 코드 \(code) (\(hex))" }
        return "\(entry.meaning) (\(entry.name), \(hex))"
    }
}
