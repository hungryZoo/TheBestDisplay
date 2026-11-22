import CoreGraphics
import Foundation
import TBDCore

/// 윈도 서버의 출력 모드 조회와 지정. (SRS-COL-011)
///
/// 프레임버퍼의 색 모드 직접 지정이 거부되는 macOS 판에서 색 모드 전환의 대체 경로.
/// 지정은 윈도 서버가 수행하므로 호출 프로세스에 프레임버퍼 권한이 필요 없음.
public enum OutputModeService {
    // 시그니처 근거: spikes 문서 T73 (SkyLight 디스어셈블과 읽기 실측).
    typealias CountFn = @convention(c) (UInt32, Int32, UnsafeMutablePointer<Int32>) -> Int32
    typealias DescriptionsFn = @convention(c) (UInt32, Int32, UnsafeMutableRawPointer, UnsafeMutablePointer<Int32>, UnsafeMutablePointer<Int32>) -> Int32
    // 두 번째 인자는 16바이트 링크 서술의 값 전달. arm64 호출 규약에서 64비트 레지스터 2개에 실림.
    typealias SetFn = @convention(c) (UInt32, UInt64, UInt64) -> Int32

    /// 목록 크기의 상한. 실측은 1-5개.
    static let maxCount: Int32 = 64

    /// 현재 모드에서 시스템이 제공하는 출력 모드 목록. 조회 불가 시 nil.
    public static func list(for display: CGDirectDisplayID, symbols: PrivateSymbols = .shared) -> OutputModeList? {
        guard let getCount = symbols.function("SLSGetDisplayOutputModeCount", in: .skyLight, as: CountFn.self),
              let getDescriptions = symbols.function("SLSGetDisplayOutputModeLinkDescriptions", in: .skyLight, as: DescriptionsFn.self),
              let modeNumber = ModeService.currentModeNumber(for: display, symbols: symbols)
        else { return nil }
        var count: Int32 = 0
        guard getCount(display, modeNumber, &count) == 0, count > 0, count <= maxCount else { return nil }
        var buffer = [UInt8](repeating: 0, count: Int(count) * LinkDescription.byteCount)
        var returned = count
        var current: Int32 = -1
        let result = buffer.withUnsafeMutableBytes { getDescriptions(display, modeNumber, $0.baseAddress!, &returned, &current) }
        guard result == 0, returned > 0, returned <= count else { return nil }
        return OutputModeList(modes: LinkDescription.decodeList(buffer, count: Int(returned)), currentIndex: current >= 0 ? Int(current) : nil)
    }

    /// 출력 모드 지정. 목록에 있는 서술만 허용.
    public static func set(_ description: LinkDescription, for display: CGDirectDisplayID, symbols: PrivateSymbols = .shared) throws {
        #if arch(arm64)
        guard let set = symbols.function("SLSSetDisplayOutputMode", in: .skyLight, as: SetFn.self) else {
            throw DisplayChangeError.unavailable("SLSSetDisplayOutputMode 없음")
        }
        guard let offered = list(for: display, symbols: symbols), offered.modes.contains(description) else {
            throw DisplayChangeError.modeNotFound(description.label)
        }
        let registers = description.registers
        let result = set(display, registers.first, registers.second)
        guard result == 0 else { throw DisplayChangeError.system(operation: "출력 모드 지정", code: result) }
        #else
        throw DisplayChangeError.unavailable("출력 모드 지정은 Apple Silicon 전용")
        #endif
    }
}
