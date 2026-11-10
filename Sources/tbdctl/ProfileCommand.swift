import Foundation
import TBDCore
import TBDPlatform

/// `tbdctl profile list | show <이름> | save <이름> [--replace] | apply <이름> [--timeout <초>] [--yes] | rename <이름> <새 이름> | delete <이름>` (PRD-PRF-001-003)
func runProfile(_ command: ParsedCommand, json: Bool) {
    let store = ProfileStore.standard
    let action = command.positionals[0].lowercased()
    func requireName(_ index: Int = 1) -> String {
        guard command.positionals.count > index else {
            writeError("오류: 프로파일 이름 필요")
            exit(.usage)
        }
        return command.positionals[index]
    }
    func requireProfile() -> DisplayProfile {
        let name = requireName()
        guard let profile = store.find(named: name) else {
            writeError("오류: 프로파일 없음: \(name)")
            exit(.unsupported)
        }
        return profile
    }
    func describe(_ profile: DisplayProfile) {
        print("\(profile.name) (디스플레이 \(profile.displays.count)대, \(ISO8601DateFormatter().string(from: profile.createdAt)))")
        for entry in profile.displays { print("  \(entry.summary)") }
    }

    do {
        switch action {
        case "list":
            let profiles = store.load()
            if json { printJSON(profiles); return }
            if profiles.isEmpty { print("저장된 프로파일 없음") }
            profiles.forEach(describe)
        case "show":
            let profile = requireProfile()
            if json { printJSON(profile) } else { describe(profile) }
        case "save":
            let profile = try store.add(ProfileApplier.capture(name: requireName()), replace: command.has("--replace"))
            print("프로파일 저장:")
            describe(profile)
        case "rename":
            let profile = requireProfile()
            try store.rename(profile.id, to: requireName(2))
            print("이름 변경: \(profile.name) → \(requireName(2))")
        case "delete":
            let profile = requireProfile()
            try store.delete(profile.id)
            print("프로파일 삭제: \(profile.name)")
        case "apply":
            let profile = requireProfile()
            let previous = ProfileApplier.capture(name: "적용 전")
            var results: [ProfileStepResult] = []
            let change = RevertCoordinator.Change(
                summary: "프로파일 적용: \(profile.name)",
                pending: nil,
                apply: {
                    results = ProfileApplier.apply(profile)
                    for r in results { print("  [\(r.outcome.title)] \(r.kind.title) \(r.displayName): \(r.detail)") }
                },
                commit: {},
                restore: { _ = ProfileApplier.apply(previous) }
            )
            // 바뀌는 것이 없으면 확인 대기 없이 종료.
            let plan = ProfilePlanner.plan(profile, current: previous, displays: DisplayCatalog.displays())
            if plan.steps.isEmpty {
                try change.apply()
                return
            }
            performGuardedChange(change, timeout: timeoutOption(command), assumeYes: command.has("--yes"))
            if results.contains(where: { $0.outcome == .failed }) { exit(.failure) }
        default:
            writeError("오류: 첫 인자는 list, show, save, apply, rename, delete 중 하나")
            exit(.usage)
        }
    } catch {
        writeError("오류: \(RevertCoordinatorDescribe(error))")
        exit(.failure)
    }
}
