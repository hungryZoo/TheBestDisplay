import Foundation
import TBDCore
import TBDPlatform

struct ArrangementOutput: Encodable {
    struct Item: Encodable {
        var display: DisplayIdentity
        var frame: DisplayFrame
        var isMain: Bool
        var rotation: Int
        var canRotate: Bool
        var mirrorsDisplayID: UInt32?
        var underscan: Int?
    }

    var displays: [Item]
    var offlineDisplayIDs: [UInt32]
}

/// `tbdctl arrangement [--json]` (PRD-ARR-001-006): 배치, 회전, 미러 상태 조회.
func runArrangement(_ command: ParsedCommand, json: Bool) {
    let displays = DisplayCatalog.displays()
    let items = displays.map { d in
        ArrangementOutput.Item(display: d.identity, frame: DisplayFrame(d), isMain: d.isMain, rotation: ArrangementService.rotation(of: d.id), canRotate: ArrangementService.canRotate(d.id), mirrorsDisplayID: d.mirrorsDisplayID, underscan: ArrangementService.underscan(of: d.id)?.value)
    }
    let offline = ArrangementService.offlineDisplayIDs()
    if json {
        printJSON(ArrangementOutput(displays: items, offlineDisplayIDs: offline))
        return
    }
    for item in items {
        var tags: [String] = []
        if item.isMain { tags.append("메인") }
        if let mirror = item.mirrorsDisplayID { tags.append("미러 원본 id:\(mirror)") }
        print("\(item.display.name) [id:\(item.display.displayID)]\(tags.isEmpty ? "" : " (\(tags.joined(separator: ", ")))")")
        print("  위치 (\(item.frame.x), \(item.frame.y)), 크기 \(item.frame.width) x \(item.frame.height), 회전 \(item.rotation)도\(item.canRotate ? "" : " (회전 미지원)")\(item.underscan.map { ", 언더스캔 \($0)" } ?? "")")
    }
    if !offline.isEmpty {
        print("온라인이 아닌 디스플레이 ID: \(offline.map(String.init).joined(separator: ", ")) (재연결 후보)")
    }
}

/// `tbdctl rotate <디스플레이> <0|90|180|270> [--timeout <초>] [--yes]` (PRD-ARR-001)
func runRotate(_ command: ParsedCommand) {
    let (display, _) = resolveDisplay(command.positionals[0])
    guard let degrees = Int(command.positionals[1]), ArrangementPlanner.isValidRotation(degrees) else {
        writeError("오류: 회전 값은 0, 90, 180, 270 중 하나")
        exit(.usage)
    }
    guard ArrangementService.canRotate(display.id) else {
        writeError("오류: 이 디스플레이는 회전을 지원하지 않음")
        exit(.unsupported)
    }
    if ArrangementService.rotation(of: display.id) == degrees {
        print("이미 회전 \(degrees)도")
        return
    }
    performGuardedChange(DisplayChanges.rotationChange(display: display, to: degrees), timeout: timeoutOption(command), assumeYes: command.has("--yes"))
}

/// `tbdctl mirror <디스플레이> <원본 디스플레이|off> [--timeout <초>] [--yes]` (PRD-ARR-002)
func runMirror(_ command: ParsedCommand) {
    let (display, displays) = resolveDisplay(command.positionals[0])
    var master: DisplaySummary?
    if command.positionals[1].lowercased() != "off" {
        do {
            master = try DisplaySelector.resolve(command.positionals[1], in: displays)
        } catch let error as DisplaySelector.SelectionError {
            writeError("오류: \(error.message)")
            exit(error.exitCode)
        } catch {
            writeError("오류: \(error)")
            exit(.failure)
        }
        if let refusal = ArrangementPlanner.mirrorRefusal(display: display.id, master: master!.id, displays: displays) {
            writeError("오류: \(refusal)")
            exit(.unsupported)
        }
    } else if display.mirrorsDisplayID == nil {
        print("미러 상태가 아님")
        return
    }
    performGuardedChange(DisplayChanges.mirrorChange(display: display, master: master, displays: displays), timeout: timeoutOption(command), assumeYes: command.has("--yes"))
}

/// `tbdctl main <디스플레이>` (PRD-ARR-003)
func runMain(_ command: ParsedCommand) {
    let (display, displays) = resolveDisplay(command.positionals[0])
    if display.isMain {
        print("이미 메인 디스플레이")
        return
    }
    do {
        try ArrangementService.setMain(display.id, displays: displays)
    } catch {
        writeError("오류: \(RevertCoordinatorDescribe(error))")
        exit(.failure)
    }
    print("메인 디스플레이 지정: \(display.identity.name)")
}

/// `tbdctl move <디스플레이> <x> <y>` (PRD-ARR-004): 다른 디스플레이와 맞닿는 가장 가까운 위치로 보정.
func runMove(_ command: ParsedCommand) {
    let (display, displays) = resolveDisplay(command.positionals[0])
    guard let x = Int(command.positionals[1]), let y = Int(command.positionals[2]) else {
        writeError("오류: 좌표는 정수")
        exit(.usage)
    }
    do {
        let applied = try ArrangementService.move(display.id, toX: x, y: y, displays: displays)
        print("위치 지정: \(display.identity.name) (\(applied.x), \(applied.y))" + (applied.x != x || applied.y != y ? " (요청 (\(x), \(y))에서 보정)" : ""))
    } catch {
        writeError("오류: \(RevertCoordinatorDescribe(error))")
        exit(.failure)
    }
}

/// `tbdctl disconnect <디스플레이> [--timeout <초>] [--yes]` (PRD-ARR-005, PRD-SAF-003)
func runDisconnect(_ command: ParsedCommand) {
    let (display, displays) = resolveDisplay(command.positionals[0])
    if let refusal = ArrangementPlanner.disconnectRefusal(display.id, online: displays.map(\.id)) {
        writeError("오류: \(refusal)")
        exit(.unsupported)
    }
    performGuardedChange(DisplayChanges.disconnectChange(display: display), timeout: timeoutOption(command), assumeYes: command.has("--yes"))
}

/// `tbdctl reconnect [<디스플레이 ID>]` (PRD-ARR-005): ID 생략 시 온라인이 아닌 디스플레이 전부.
func runReconnect(_ command: ParsedCommand) {
    var targets = ArrangementService.offlineDisplayIDs()
    if let text = command.positionals.first {
        guard let id = UInt32(text.lowercased().replacingOccurrences(of: "id:", with: "")) else {
            writeError("오류: 디스플레이 ID는 숫자")
            exit(.usage)
        }
        targets = [id]
    }
    if targets.isEmpty {
        print("재연결할 디스플레이 없음")
        return
    }
    var failed = false
    for id in targets {
        do {
            try ArrangementService.reconnect(id, timeout: 8)
            print("재연결 완료: id:\(id)")
        } catch {
            writeError("재연결 실패: id:\(id) (\(RevertCoordinatorDescribe(error)))")
            failed = true
        }
    }
    if failed { exit(.failure) }
}

/// `tbdctl align <디스플레이> <기준 디스플레이> <위치>` (PRD-ARR-007)
/// 위치: left|right|top|bottom에 -top|-center|-bottom 또는 -left|-center|-right, 모서리는 corner-top-left 등.
func runAlign(_ command: ParsedCommand) {
    let (display, displays) = resolveDisplay(command.positionals[0])
    let (reference, _) = resolveDisplay(command.positionals[1])
    guard let position = AlignmentPosition.parse(command.positionals[2]) else {
        writeError("오류: 위치는 \(AlignmentPosition.allCases.map(\.rawValue).joined(separator: ", ")) 중 하나 (left, right, top, bottom은 가운데 맞춤)")
        exit(.usage)
    }
    guard display.id != reference.id else {
        writeError("오류: 대상과 기준이 같은 디스플레이")
        exit(.unsupported)
    }
    let origin = ArrangementPlanner.alignedOrigin(target: DisplayFrame(display), reference: DisplayFrame(reference), position: position)
    do {
        let applied = try ArrangementService.move(display.id, toX: origin.x, y: origin.y, displays: displays)
        print("정렬: \(display.identity.name)을(를) \(reference.identity.name)의 \(position.title) 위치로 이동 (\(applied.x), \(applied.y))" + (applied.x != origin.x || applied.y != origin.y ? " (계산값 (\(origin.x), \(origin.y))에서 보정)" : ""))
    } catch {
        writeError("오류: \(RevertCoordinatorDescribe(error))")
        exit(.failure)
    }
}
