import Foundation
import IOKit
import TBDCore

/// GPU 디더링(시간 축 디더링) 조회와 전환. 프레임버퍼 노드의 `enableDither` 레지스트리 속성 사용. (SRS-COL-008, PRD-COL-008)
/// 근거: 실험 기기의 `IOMobileFramebufferShim` 노드에 `enableDither` 속성 존재 (내장 Yes, 12 bpc 송출 중인 LG TV No),
/// 공개 도구 Stillcolor의 같은 속성 사용. 설정은 재시동 또는 디스플레이 재연결 시 시스템 기본값으로 돌아감.
public enum DitherService {
    static let key = "enableDither"

    /// 현재 설정. 속성이 없거나 디스플레이에 대응하는 노드를 찾지 못하면 nil.
    public static func isEnabled(for display: DisplaySummary) -> Bool? {
        guard let node = SignalService.framebufferNode(for: display) else { return nil }
        defer { IOObjectRelease(node.service) }
        return IORegistry.property(node.service, key) as? Bool
    }

    /// 설정 변경 후 다시 읽어 확인.
    public static func setEnabled(_ enabled: Bool, for display: DisplaySummary) throws {
        guard let node = SignalService.framebufferNode(for: display) else { throw DisplayChangeError.displayNotFound }
        defer { IOObjectRelease(node.service) }
        guard IORegistry.property(node.service, key) is Bool else {
            throw DisplayChangeError.unavailable("이 디스플레이의 프레임버퍼에 디더링 설정 속성 없음")
        }
        let result = IORegistryEntrySetCFProperty(node.service, key as CFString, enabled ? kCFBooleanTrue : kCFBooleanFalse)
        guard result == KERN_SUCCESS else { throw DisplayChangeError.system(operation: "디더링 설정", code: result) }
        guard (IORegistry.property(node.service, key) as? Bool) == enabled else {
            throw DisplayChangeError.system(operation: "디더링 설정 반영 확인", code: -1)
        }
    }
}
