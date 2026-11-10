import CoreGraphics
import Foundation
import TBDCore

/// 프로파일 저장(현재 구성 수집)과 적용. (SRS-PRF-002)
public enum ProfileApplier {
    /// 현재 구성을 프로파일로 수집.
    public static func capture(name: String, displays: [DisplaySummary]? = nil) -> DisplayProfile {
        let displays = displays ?? DisplayCatalog.displays()
        let entries = displays.map { display -> DisplayProfileEntry in
            let modes = ModeService.modes(for: display.id)
            let signal = SignalService.signalInfo(for: display)
            let hdrSupported = HDRService.isSupported(display.id)
            let master = display.mirrorsDisplayID.flatMap { id in displays.first { $0.id == id } }
            return DisplayProfileEntry(
                ref: DisplayRef(display.identity),
                mode: ModeService.currentMode(for: display.id, in: modes)?.descriptor,
                // 내장 패널은 색 모드 선택 대상이 아님.
                color: display.identity.isBuiltin ? nil : (signal?.linkData?.descriptor ?? signal?.currentColor?.descriptor),
                hdrEnabled: hdrSupported ? HDRService.isEnabled(display.id) : nil,
                rotation: ArrangementService.rotation(of: display.id),
                originX: display.originX,
                originY: display.originY,
                isMain: display.isMain,
                mirrorOf: master.map { DisplayRef($0.identity) },
                brightness: BrightnessService.supportsNative(display) ? BrightnessService.nativeBrightness(display.id) : nil
            )
        }
        return DisplayProfile(name: name, createdAt: Date(), displays: entries)
    }

    /// 프로파일 적용. 단계 순서는 `ProfileStepKind`의 정의 순서. 한 단계가 실패해도 나머지 단계는 계속 수행하고 결과에 기록.
    /// - Parameter only: 지정하면 해당 종류의 단계만 수행 (구성 보호의 복원에 사용).
    public static func apply(_ profile: DisplayProfile, only kinds: Set<ProfileStepKind>? = nil) -> [ProfileStepResult] {
        var displays = DisplayCatalog.displays()
        let current = capture(name: "현재", displays: displays)
        var plan = ProfilePlanner.plan(profile, current: current, displays: displays)
        if let kinds { plan.steps = plan.steps.filter { kinds.contains($0.kind) } }
        var results: [ProfileStepResult] = plan.unmatched.map {
            ProfileStepResult(kind: .mode, displayName: $0.ref.name, outcome: .skipped, detail: "연결되지 않은 디스플레이")
        }
        if plan.steps.isEmpty, plan.unmatched.isEmpty {
            return [ProfileStepResult(kind: .mode, displayName: "전체", outcome: .unchanged, detail: "현재 구성이 프로파일과 같음")]
        }
        let matches = ProfilePlanner.match(profile, displays: displays)
        func entry(for id: UInt32) -> DisplayProfileEntry? { matches.first { $0.display?.id == id }?.entry }

        for step in plan.steps {
            // 앞 단계가 구성을 바꿨을 수 있으므로 단계마다 디스플레이 목록을 다시 읽음.
            displays = DisplayCatalog.displays()
            do {
                switch step.kind {
                case .arrangement:
                    let frames = matches.compactMap { entry, display -> DisplayFrame? in
                        guard let display, entry.mirrorOf == nil, let live = displays.first(where: { $0.id == display.id }) else { return nil }
                        return DisplayFrame(id: live.id, x: entry.originX, y: entry.originY, width: live.pointWidth, height: live.pointHeight)
                    }
                    let main = matches.first { $0.entry.isMain && $0.display != nil }?.display?.id
                    try ArrangementService.apply(main.map { ArrangementPlanner.normalized(frames, main: $0) } ?? frames)
                default:
                    guard let id = step.displayID, let display = displays.first(where: { $0.id == id }), let target = entry(for: id) else {
                        results.append(ProfileStepResult(kind: step.kind, displayName: step.displayName, outcome: .skipped, detail: "대상 디스플레이가 온라인 상태가 아님"))
                        continue
                    }
                    switch step.kind {
                    case .mirror:
                        try ArrangementService.setMirror(id, master: target.mirrorOf?.resolve(in: displays)?.id)
                    case .rotation:
                        try ArrangementService.setRotation(target.rotation, on: id)
                    case .mode:
                        if let mode = target.mode { try ModeService.setMode(matching: mode, on: id, permanently: true) }
                    case .hdr:
                        if let hdr = target.hdrEnabled { try HDRService.setEnabled(hdr, on: id) }
                    case .color:
                        if let color = target.color {
                            // 모드와 HDR 전환 직후에는 시스템이 색 모드를 고르는 중일 수 있어 잠시 대기 후 비교.
                            usleep(800_000)
                            let live = SignalService.signalInfo(for: display)
                            if (live?.linkData?.descriptor ?? live?.currentColor?.descriptor) == color {
                                results.append(ProfileStepResult(kind: .color, displayName: step.displayName, outcome: .unchanged, detail: color.label))
                                continue
                            }
                            try SignalService.setColorMode(matching: color, for: display)
                        }
                    case .brightness:
                        if let brightness = target.brightness { try BrightnessService.setNativeBrightness(brightness, on: id) }
                    case .arrangement:
                        break
                    }
                }
                results.append(ProfileStepResult(kind: step.kind, displayName: step.displayName, outcome: .applied, detail: step.detail))
            } catch {
                results.append(ProfileStepResult(kind: step.kind, displayName: step.displayName, outcome: .failed, detail: "\(step.detail): \(RevertCoordinator.describe(error))"))
            }
        }
        return results
    }
}
