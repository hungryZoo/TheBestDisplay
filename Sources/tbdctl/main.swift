import Foundation
import TBDCore
import TBDPlatform

// tbdctl: TheBestDisplay 명령행 도구. (SRS-CLI-001)

let parser = CommandLineParser(specs: [
    CommandSpec(name: "list", summary: "디스플레이 목록"),
    CommandSpec(name: "capabilities", summary: "기능별 가용성"),
    CommandSpec(name: "info", summary: "제품 정보와 EDID 해석", positionals: ["디스플레이"], valueOptions: ["--edid-out"], flags: ["--hex"]),
    CommandSpec(name: "modes", summary: "전체 모드 목록", positionals: ["디스플레이"], flags: ["--hidpi", "--outside-default"]),
    CommandSpec(name: "scaled", summary: "사용자 정의 스케일 해상도 조회, 추가, 삭제 (오버라이드 파일, 관리자 권한)", positionals: ["디스플레이", "list|add|remove", "해상도"], optionalPositionals: 2),
    CommandSpec(name: "refresh", summary: "주사율 측정 (화면 갱신 콜백 기준)", positionals: ["디스플레이"], valueOptions: ["--seconds"]),
    CommandSpec(name: "favorites", summary: "즐겨찾기 모드 조회, 추가, 삭제", positionals: ["디스플레이", "list|add|remove", "모드"], optionalPositionals: 2),
    CommandSpec(name: "set-mode", summary: "모드 전환 (자동 복귀 적용)", positionals: ["디스플레이", "모드"], valueOptions: ["--timeout", "--method"], flags: ["--yes"]),
    CommandSpec(name: "signal", summary: "현재 신호 형식과 색 모드 목록", positionals: ["디스플레이"], flags: ["--timings"]),
    CommandSpec(name: "link", summary: "링크 정보와 대역폭", positionals: ["디스플레이"]),
    CommandSpec(name: "ports", summary: "포트, 케이블, 독, 연결 경로"),
    CommandSpec(name: "diagnose", summary: "포트 점검과 진단 발견 항목"),
    CommandSpec(name: "report", summary: "진단 보고서 저장 (기본 JSON)", positionals: ["경로"], flags: ["--redact", "--text"]),
    CommandSpec(name: "set-color", summary: "색 모드 전환 (자동 복귀 적용)", positionals: ["디스플레이", "색 모드"], valueOptions: ["--timeout"], flags: ["--yes"]),
    CommandSpec(name: "dsc", summary: "DSC 상태 조회와 전환 (자동 복귀 적용)", positionals: ["디스플레이", "on|off"], optionalPositionals: 1, valueOptions: ["--timeout"], flags: ["--yes"]),
    CommandSpec(name: "set-timing", summary: "연결 수준 타이밍 직접 선택 (자동 복귀 적용)", positionals: ["디스플레이", "타이밍"], valueOptions: ["--timeout"], flags: ["--yes"]),
    CommandSpec(name: "hdr", summary: "HDR 상태 조회와 전환 (자동 복귀 적용)", positionals: ["디스플레이", "on|off"], optionalPositionals: 1, valueOptions: ["--timeout"], flags: ["--yes"]),
    CommandSpec(name: "brightness", summary: "밝기 조회와 설정 (0-100)", positionals: ["디스플레이", "값"], optionalPositionals: 1),
    CommandSpec(name: "preset", summary: "디스플레이 프리셋 조회와 전환 (자동 복귀 적용)", positionals: ["디스플레이", "번호 또는 이름"], optionalPositionals: 1, valueOptions: ["--timeout"], flags: ["--yes"]),
    CommandSpec(name: "brightness-sync", summary: "원본 디스플레이의 밝기를 다른 디스플레이에 동기화 (지정 시간 동안)", positionals: ["원본 디스플레이"], valueOptions: ["--seconds"]),
    CommandSpec(name: "xdr", summary: "XDR 밝기 업스케일 조회와 적용 (지정 시간 동안 유지)", positionals: ["디스플레이", "배율 %"], optionalPositionals: 1, valueOptions: ["--seconds"]),
    CommandSpec(name: "ddc", summary: "DDC 탐지와 VCP 읽기, 쓰기", positionals: ["디스플레이", "probe|get|set", "코드", "값"], optionalPositionals: 2),
    CommandSpec(name: "color", summary: "색 프로파일, Night Shift, True Tone 상태", positionals: ["디스플레이"], flags: ["--profiles"]),
    CommandSpec(name: "arrangement", summary: "배치, 회전, 미러 상태"),
    CommandSpec(name: "rotate", summary: "회전 (자동 복귀 적용)", positionals: ["디스플레이", "각도"], valueOptions: ["--timeout"], flags: ["--yes"]),
    CommandSpec(name: "mirror", summary: "미러 설정 또는 해제 (자동 복귀 적용)", positionals: ["디스플레이", "원본|off"], valueOptions: ["--timeout"], flags: ["--yes"]),
    CommandSpec(name: "main", summary: "메인 디스플레이 지정", positionals: ["디스플레이"]),
    CommandSpec(name: "move", summary: "디스플레이 위치 지정", positionals: ["디스플레이", "x", "y"]),
    CommandSpec(name: "align", summary: "기준 디스플레이에 대한 16방향 정렬", positionals: ["디스플레이", "기준 디스플레이", "위치"]),
    CommandSpec(name: "disconnect", summary: "논리적 연결 해제 (자동 복귀 적용)", positionals: ["디스플레이"], valueOptions: ["--timeout"], flags: ["--yes"]),
    CommandSpec(name: "reconnect", summary: "연결 해제한 디스플레이 재연결", positionals: ["디스플레이 ID"], optionalPositionals: 1),
    CommandSpec(name: "virtual", summary: "가상 디스플레이를 만들고 지정 시간 동안 유지", positionals: ["해상도"], valueOptions: ["--name", "--seconds"], flags: ["--hidpi"]),
    CommandSpec(name: "profile", summary: "구성 프로파일 (list, show, save, apply, rename, delete, check, protect, unprotect, protection)", positionals: ["동작", "이름", "새 이름"], optionalPositionals: 2, valueOptions: ["--timeout"], flags: ["--yes", "--replace"]),
    CommandSpec(name: "edid", summary: "EDID 검증, 편집, 오버라이드 적용과 해제 (자동 복귀 적용)", positionals: ["디스플레이", "check|patch|timing|apply|reset", "값"], optionalPositionals: 1, valueOptions: ["--in", "--out", "--timeout"], flags: ["--apply", "--preferred", "--yes"]),
    CommandSpec(name: "redetect", summary: "디스플레이 재감지 요청"),
    CommandSpec(name: "revert-pending", summary: "확인 없이 종료된 변경의 복귀", flags: ["--discard"]),
    CommandSpec(name: "help", summary: "사용법"),
])

func writeError(_ text: String) {
    FileHandle.standardError.write(Data((text + "\n").utf8))
}

func exit(_ code: ExitCode) -> Never {
    Foundation.exit(code.rawValue)
}

func printJSON<T: Encodable>(_ value: T) {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    encoder.dateEncodingStrategy = .iso8601
    guard let data = try? encoder.encode(value), let text = String(data: data, encoding: .utf8) else {
        writeError("JSON 변환 실패")
        exit(.failure)
    }
    print(text)
}

/// 디스플레이 지정자를 해석. 대상이 없으면 종료 코드 3.
func resolveDisplay(_ selector: String) -> (DisplaySummary, [DisplaySummary]) {
    let displays = DisplayCatalog.displays()
    do {
        return (try DisplaySelector.resolve(selector, in: displays), displays)
    } catch let error as DisplaySelector.SelectionError {
        writeError("오류: \(error.message)")
        exit(error.exitCode)
    } catch {
        writeError("오류: \(error)")
        exit(.failure)
    }
}

let arguments = Array(CommandLine.arguments.dropFirst())
if arguments.isEmpty || arguments.contains("--help") || arguments.contains("-h") {
    print(parser.usage)
    exit(arguments.isEmpty ? .usage : .success)
}

let command: ParsedCommand
do {
    command = try parser.parse(arguments)
} catch let error as CommandLineError {
    writeError("오류: \(error.message)")
    writeError(parser.usage)
    exit(error.exitCode)
} catch {
    writeError("오류: \(error)")
    exit(.failure)
}

let json = command.has("--json")

switch command.name {
case "help":
    print(parser.usage)

case "list":
    let displays = DisplayCatalog.displays()
    if json {
        printJSON(displays)
    } else if displays.isEmpty {
        print("온라인 디스플레이 없음")
    } else {
        for (index, d) in displays.enumerated() {
            var tags: [String] = [d.identity.isBuiltin ? "내장" : "외장"]
            if d.isMain { tags.append("메인") }
            if let mirror = d.mirrorsDisplayID { tags.append("미러 대상 id:\(mirror)") }
            if d.rotationDegrees != 0 { tags.append("회전 \(Int(d.rotationDegrees))도") }
            print("\(index + 1). \(d.identity.name) [id:\(d.identity.displayID)] (\(tags.joined(separator: ", ")))")
            print("   \(d.modeDescription), 픽셀 \(d.pixelWidth) x \(d.pixelHeight), 위치 (\(d.originX), \(d.originY))")
        }
    }

case "capabilities":
    let statuses = PrivateSymbols.shared.allStatuses()
    if json {
        printJSON(statuses)
    } else {
        for s in statuses {
            print("\(s.isAvailable ? "가용  " : "미가용") \(s.capability.title)" + (s.isAvailable ? "" : " — 누락: \(s.missingSymbols.joined(separator: ", "))"))
        }
    }

case "info":
    runInfo(command, json: json)

case "modes":
    runModes(command, json: json)

case "scaled":
    runScaled(command, json: json)

case "refresh":
    MainActor.assumeIsolated { runRefresh(command, json: json) }

case "favorites":
    runFavorites(command, json: json)

case "set-mode":
    runSetMode(command)

case "signal":
    runSignal(command, json: json)

case "link":
    runLink(command, json: json)

case "ports":
    runPorts(command, json: json)

case "diagnose":
    runDiagnose(command, json: json)

case "report":
    runReport(command)

case "set-color":
    runSetColor(command)

case "dsc":
    runDSC(command, json: json)

case "set-timing":
    runSetTiming(command)

case "hdr":
    runHDR(command, json: json)

case "brightness":
    runBrightness(command, json: json)

case "preset":
    runPreset(command, json: json)

case "brightness-sync":
    runBrightnessSync(command)

case "xdr":
    MainActor.assumeIsolated { runXDR(command, json: json) }

case "ddc":
    runDDC(command, json: json)

case "color":
    runColor(command, json: json)

case "arrangement":
    runArrangement(command, json: json)

case "rotate":
    runRotate(command)

case "mirror":
    runMirror(command)

case "main":
    runMain(command)

case "move":
    runMove(command)

case "align":
    runAlign(command)

case "disconnect":
    runDisconnect(command)

case "reconnect":
    runReconnect(command)

case "virtual":
    runVirtual(command)

case "profile":
    runProfile(command, json: json)

case "edid":
    runEDID(command, json: json)

case "redetect":
    runRedetect()

case "revert-pending":
    runRevertPending(command)

default:
    writeError("오류: 미구현 명령 \(command.name)")
    exit(.unsupported)
}

exit(.success)
