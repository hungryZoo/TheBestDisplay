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

    /// 회전. 복귀는 이전 각도 재적용.
    public static func rotationChange(display: DisplaySummary, to degrees: Int) -> RevertCoordinator.Change {
        let name = display.identity.name
        let displayID = display.id
        let previous = Int(display.rotationDegrees.rounded())
        return RevertCoordinator.Change(
            summary: "\(name): 회전 \(previous)도 → \(degrees)도",
            pending: PendingRevert(createdAt: Date(), summary: "\(name) 회전을 \(previous)도로 복귀", actions: [.rotation(target: DisplayRef(display.identity), degrees: previous)]),
            apply: { try ArrangementService.setRotation(degrees, on: displayID) },
            commit: { guard ModeService.isOnline(displayID) else { throw DisplayChangeError.displayNotFound } },
            restore: { try ArrangementService.setRotation(previous, on: displayID) }
        )
    }

    /// 미러 설정 또는 해제. 복귀는 이전 미러 상태 재적용.
    public static func mirrorChange(display: DisplaySummary, master: DisplaySummary?, displays: [DisplaySummary]) -> RevertCoordinator.Change {
        let name = display.identity.name
        let displayID = display.id
        let previousMaster = display.mirrorsDisplayID.flatMap { id in displays.first { $0.id == id } }
        return RevertCoordinator.Change(
            summary: master.map { "\(name): \($0.identity.name) 미러" } ?? "\(name): 미러 해제",
            pending: PendingRevert(
                createdAt: Date(),
                summary: previousMaster.map { "\(name)을(를) \($0.identity.name) 미러로 복귀" } ?? "\(name) 미러 해제로 복귀",
                actions: [.mirror(target: DisplayRef(display.identity), master: previousMaster.map { DisplayRef($0.identity) })]
            ),
            apply: {
                if let master, let refusal = ArrangementPlanner.mirrorRefusal(display: displayID, master: master.id, displays: displays) {
                    throw DisplayChangeError.unavailable(refusal)
                }
                try ArrangementService.setMirror(displayID, master: master?.id)
            },
            commit: {},
            restore: { try ArrangementService.setMirror(displayID, master: previousMaster?.id) }
        )
    }

    /// 논리적 연결 해제. 복귀는 재연결.
    public static func disconnectChange(display: DisplaySummary) -> RevertCoordinator.Change {
        let name = display.identity.name
        let displayID = display.id
        return RevertCoordinator.Change(
            summary: "\(name): 연결 해제",
            pending: PendingRevert(createdAt: Date(), summary: "\(name) 재연결", actions: [.reconnect(displayID: displayID, name: name)]),
            apply: { try ArrangementService.disconnect(displayID) },
            commit: {},
            restore: { try ArrangementService.reconnect(displayID) }
        )
    }

    /// 연결 수준 타이밍 직접 선택. 복귀는 이전 타이밍과 색 모드의 서술로 수행. (SRS-COL-007)
    public static func timingChange(display: DisplaySummary, from previous: TimingElement, previousColor: ColorElement, to target: TimingElement, color: ColorElement) -> RevertCoordinator.Change {
        let name = display.identity.name
        let previousTiming = TimingDescriptor(previous)
        return RevertCoordinator.Change(
            summary: "\(name): 타이밍 \(previous.label) → \(target.label) (\(color.label))",
            pending: PendingRevert(
                createdAt: Date(),
                summary: "\(name) 타이밍을 \(previous.label)(으)로 복귀",
                actions: [.timing(target: DisplayRef(display.identity), timing: previousTiming, color: previousColor.descriptor)]
            ),
            apply: { try SignalService.setColorMode(colorID: color.id, timingID: target.id, for: display) },
            commit: { guard ModeService.isOnline(display.id) else { throw DisplayChangeError.displayNotFound } },
            restore: {
                guard ModeService.isOnline(display.id) else { throw DisplayChangeError.displayNotFound }
                try SignalService.setTiming(matching: previousTiming, color: previousColor.descriptor, for: display)
            }
        )
    }

    /// 디스플레이 프리셋 전환. 복귀는 이전 프리셋 재적용. (SRS-CLR-004)
    public static func presetChange(display: DisplaySummary, from previous: DisplayPreset, to target: DisplayPreset) -> RevertCoordinator.Change {
        let name = display.identity.name
        let displayID = display.id
        return RevertCoordinator.Change(
            summary: "\(name): 프리셋 \(previous.name) → \(target.name)",
            pending: PendingRevert(createdAt: Date(), summary: "\(name) 프리셋을 \(previous.name)(으)로 복귀", actions: [.preset(target: DisplayRef(display.identity), index: previous.index, name: previous.name)]),
            apply: { try PresetService.setActive(index: target.index, on: displayID) },
            commit: { guard ModeService.isOnline(displayID) else { throw DisplayChangeError.displayNotFound } },
            restore: { try PresetService.setActive(index: previous.index, on: displayID) }
        )
    }

    /// 가상 EDID 적용. 복귀는 가상 EDID 해제(원본 EDID 복귀). (SRS-EDO-002)
    /// 적용 뒤 시스템이 디스플레이를 다시 감지하므로 디스플레이 ID와 식별 정보가 바뀔 수 있음.
    public static func edidOverrideChange(display: DisplaySummary, among displays: [DisplaySummary], edid: Data, detail: String) throws -> RevertCoordinator.Change {
        guard !display.identity.isBuiltin else { throw EDIDOverrideService.OverrideError.builtinNotSupported }
        guard let service = EDIDOverrideService.service(for: display, among: displays) else { throw EDIDOverrideService.OverrideError.serviceNotFound }
        let name = display.identity.name
        let entryID = service.registryEntryID
        return RevertCoordinator.Change(
            summary: "\(name): EDID 오버라이드 (\(detail))",
            pending: PendingRevert(createdAt: Date(), summary: "\(name) 원본 EDID 복귀", actions: [.edidReset(serviceEntryID: entryID, name: name)]),
            apply: { try EDIDOverrideService.apply(edid, to: display, among: displays) },
            commit: {},
            restore: { try EDIDOverrideService.reset(registryEntryID: entryID) }
        )
    }
}
