import CoreGraphics
import Foundation
import TBDCore

/// 자동 복귀 안전장치에 넘길 화면 변경 묶음 생성. 앱과 명령행 도구가 같은 동작을 쓰도록 한곳에 둠.
public enum DisplayChanges {
    /// 모드 전환. 확인 전에는 적용만 하고, 확정 시 시스템 설정에 저장, 복귀 시 이전 모드 서술과 일치하는 모드로 전환.
    public static func modeChange(display: DisplaySummary, from previous: DisplayMode, to target: DisplayMode, method: ModeService.Method? = nil, onApplied: @escaping (ModeService.Method) -> Void = { _ in }) -> RevertCoordinator.Change {
        let displayID = display.id
        let name = display.identity.name
        return RevertCoordinator.Change(
            summary: "\(name): \(previous.label) → \(target.label)",
            pending: PendingRevert(
                createdAt: Date(),
                summary: "\(name) 모드를 \(previous.label)(으)로 복귀",
                actions: [.displayMode(target: DisplayRef(display.identity), mode: previous.descriptor)]
            ),
            apply: {
                onApplied(try ModeService.setMode(target, on: displayID, permanently: false, method: method))
            },
            commit: {
                // 적용 뒤 디스플레이가 사라졌으면 확정할 대상 없음.
                guard ModeService.isOnline(displayID) else { throw DisplayChangeError.displayNotFound }
                if ModeService.currentMode(for: displayID, in: ModeService.modes(for: displayID))?.descriptor != target.descriptor {
                    try ModeService.setMode(matching: target.descriptor, on: displayID, permanently: true, method: method)
                }
            },
            restore: {
                try ModeService.setMode(matching: previous.descriptor, on: displayID, permanently: true, method: method)
            }
        )
    }

    /// 색 모드 전환. 타이밍은 유지. 복귀는 이전 색 모드 서술과 일치하는 색 모드로 수행.
    public static func colorChange(display: DisplaySummary, timingID: Int, from previous: ColorElement, to target: ColorElement) -> RevertCoordinator.Change {
        let name = display.identity.name
        return RevertCoordinator.Change(
            summary: "\(name): \(previous.label) → \(target.label)",
            pending: PendingRevert(
                createdAt: Date(),
                summary: "\(name) 색 모드를 \(previous.label)(으)로 복귀",
                actions: [.colorMode(target: DisplayRef(display.identity), color: previous.descriptor)]
            ),
            apply: {
                try SignalService.setColorMode(colorID: target.id, timingID: timingID, for: display)
            },
            commit: {
                guard ModeService.isOnline(display.id) else { throw DisplayChangeError.displayNotFound }
            },
            restore: {
                guard ModeService.isOnline(display.id) else { throw DisplayChangeError.displayNotFound }
                // 같은 연결이면 ID로, ID가 바뀌었으면 서술로 복귀.
                if let info = SignalService.signalInfo(for: display), info.currentTimingID == timingID, info.selectableColorModes.contains(where: { $0.id == previous.id && $0.descriptor == previous.descriptor }) {
                    try SignalService.setColorMode(colorID: previous.id, timingID: timingID, for: display)
                } else {
                    try SignalService.setColorMode(matching: previous.descriptor, for: display)
                }
            }
        )
    }

    /// HDR 켜기와 끄기. 복귀는 이전 상태 재적용.
    public static func hdrChange(display: DisplaySummary, enable: Bool, method: HDRService.Method? = nil, onApplied: @escaping (HDRService.Method) -> Void = { _ in }) -> RevertCoordinator.Change {
        let name = display.identity.name
        let displayID = display.id
        return RevertCoordinator.Change(
            summary: "\(name): HDR \(enable ? "켜기" : "끄기")",
            pending: PendingRevert(
                createdAt: Date(),
                summary: "\(name) HDR을 \(enable ? "꺼짐" : "켜짐")(으)로 복귀",
                actions: [.hdr(target: DisplayRef(display.identity), enabled: !enable)]
            ),
            apply: { onApplied(try HDRService.setEnabled(enable, on: displayID, method: method)) },
            commit: { guard ModeService.isOnline(displayID) else { throw DisplayChangeError.displayNotFound } },
            restore: { try HDRService.setEnabled(!enable, on: displayID, method: method) }
        )
    }
}
