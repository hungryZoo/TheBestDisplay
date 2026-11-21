import Foundation
import Testing
@testable import TBDCore

/// TC-COL-012: 시스템 오류 코드 풀이.
@Suite("TC-COL-012 시스템 오류 코드 풀이")
struct SystemErrorCodeTests {
    @Test func 권한_없음_코드() {
        // macOS 27.2.1에서 색 모드 지정이 돌려준 값 (T72 실측).
        #expect(SystemErrorCode.describe(-536870207) == "권한 없음 (kIOReturnNotPrivileged, 0xE00002C1)")
        #expect(SystemErrorCode.isPermissionDenied(-536870207))
        #expect(SystemErrorCode.isPermissionDenied(Int32(bitPattern: 0xE00002E2)))
        #expect(!SystemErrorCode.isPermissionDenied(Int32(bitPattern: 0xE00002C2)))
        #expect(!SystemErrorCode.isPermissionDenied(0))
    }

    @Test func 그_밖의_코드() {
        #expect(SystemErrorCode.describe(Int32(bitPattern: 0xE00002C2)) == "잘못된 인자 (kIOReturnBadArgument, 0xE00002C2)")
        #expect(SystemErrorCode.describe(Int32(bitPattern: 0xE00002C7)) == "지원하지 않는 동작 (kIOReturnUnsupported, 0xE00002C7)")
        #expect(SystemErrorCode.describe(1001) == "오류 코드 1001 (0x000003E9)")
        #expect(SystemErrorCode.describe(-1) == "오류 코드 -1 (0xFFFFFFFF)")
    }
}
