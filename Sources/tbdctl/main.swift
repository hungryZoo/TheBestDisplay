import Foundation
import TBDCore
import TBDPlatform

// tbdctl: TheBestDisplay 명령행 도구. (SRS-CLI-001)

let parser = CommandLineParser(specs: [
    CommandSpec(name: "list", summary: "디스플레이 목록"),
    CommandSpec(name: "capabilities", summary: "기능별 가용성"),
    CommandSpec(name: "info", summary: "제품 정보와 EDID 해석", positionals: ["디스플레이"], valueOptions: ["--edid-out"], flags: ["--hex"]),
    CommandSpec(name: "modes", summary: "전체 모드 목록", positionals: ["디스플레이"], flags: ["--hidpi", "--outside-default"]),
    CommandSpec(name: "set-mode", summary: "모드 전환 (자동 복귀 적용)", positionals: ["디스플레이", "모드"], valueOptions: ["--timeout", "--method"], flags: ["--yes"]),
    CommandSpec(name: "signal", summary: "현재 신호 형식과 색 모드 목록", positionals: ["디스플레이"], flags: ["--timings"]),
    CommandSpec(name: "set-color", summary: "색 모드 전환 (자동 복귀 적용)", positionals: ["디스플레이", "색 모드"], valueOptions: ["--timeout"], flags: ["--yes"]),
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

case "set-mode":
    runSetMode(command)

case "signal":
    runSignal(command, json: json)

case "set-color":
    runSetColor(command)

case "revert-pending":
    runRevertPending(command)

default:
    writeError("오류: 미구현 명령 \(command.name)")
    exit(.unsupported)
}

exit(.success)
