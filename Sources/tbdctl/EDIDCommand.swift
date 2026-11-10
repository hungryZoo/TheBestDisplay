import Foundation
import TBDCore
import TBDPlatform

struct EDIDCheckOutput: Encodable {
    var source: String
    var byteCount: Int
    var issues: [String]
    var capabilities: SinkCapabilities?
}

struct EDIDPatchOutput: Encodable {
    var source: String
    var results: [EDIDPatchResult]
    var before: SinkCapabilities
    var after: SinkCapabilities
    var outputPath: String?
    var applied: Bool
}

private func readEDIDFile(_ path: String) -> Data {
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
        writeError("오류: 파일을 읽을 수 없음: \(path)")
        exit(.failure)
    }
    return data
}

/// 편집 입력: `--in` 파일 또는 디스플레이의 현재 EDID.
private func sourceEDID(_ command: ParsedCommand, display: DisplaySummary, displays: [DisplaySummary]) -> (data: Data, source: String) {
    if let path = command.options["--in"] { return (readEDIDFile(path), path) }
    guard let record = EDIDSource.record(for: display, among: displays) else {
        writeError("오류: EDID 없음 (\(display.identity.isBuiltin ? "내장 패널은 EDID 미제공" : "획득 실패")). --in <파일>로 입력 지정 가능")
        exit(.unsupported)
    }
    return (record.data, "\(display.identity.name) (\(record.source))")
}

private func applyOverride(_ edid: Data, display: DisplaySummary, displays: [DisplaySummary], detail: String, command: ParsedCommand) {
    guard PrivateSymbols.shared.status(of: .edidOverride).isAvailable else {
        writeError("오류: 이 시스템에서 EDID 오버라이드 사용 불가")
        exit(.unsupported)
    }
    do {
        let change = try DisplayChanges.edidOverrideChange(display: display, among: displays, edid: edid, detail: detail)
        print("화면이 나오지 않으면 제한 시간 뒤 원본 EDID로 복귀. 복귀도 실패하면 재시동 시 원본 EDID로 돌아옴")
        performGuardedChange(change, timeout: timeoutOption(command), assumeYes: command.has("--yes"))
    } catch {
        writeError("오류: \(RevertCoordinator.describe(error))")
        exit(.unsupported)
    }
}

/// 편집 적용, 전후 비교 출력, 저장, 가상 EDID 적용.
private func runEDIDEdit(_ patches: [EDIDPatch], command: ParsedCommand, display: DisplaySummary, displays: [DisplaySummary], json: Bool) {
    let (data, source) = sourceEDID(command, display: display, displays: displays)
    let output: (data: Data, results: [EDIDPatchResult])
    do {
        output = try EDIDEditor.apply(patches, to: data)
    } catch {
        writeError("오류: \(RevertCoordinator.describe(error))")
        exit(.failure)
    }
    let before = EDIDParser.parse(data).sinkCapabilities
    let after = EDIDParser.parse(output.data).sinkCapabilities
    if let path = command.options["--out"] {
        do {
            try output.data.write(to: URL(fileURLWithPath: path))
        } catch {
            writeError("오류: 파일 저장 실패: \(error.localizedDescription)")
            exit(.failure)
        }
    }
    let changed = output.results.contains(where: \.changed)
    if json {
        printJSON(EDIDPatchOutput(source: source, results: output.results, before: before, after: after, outputPath: command.options["--out"], applied: command.has("--apply") && changed))
    } else {
        print("EDID \(source) 편집")
        for result in output.results {
            print("  \(result.title): \(result.changed ? result.changes.joined(separator: ", ") : "대상 선언 없음 (변경 없음)")")
        }
        print("능력 요약 (편집 전 → 편집 후)")
        for (a, b) in zip(before.comparisonRows, after.comparisonRows) {
            print("  \(a.label): \(a.value)\(a.value == b.value ? "" : " → \(b.value)")")
        }
        if let path = command.options["--out"] { print("저장: \(path)") }
    }
    if command.has("--apply") {
        guard changed else {
            print("변경 내용이 없어 적용하지 않음")
            return
        }
        applyOverride(output.data, display: display, displays: displays, detail: patches.map(\.title).joined(separator: ", "), command: command)
    }
}

/// `tbdctl edid <디스플레이> check [<파일>]`
/// `tbdctl edid <디스플레이> patch <편집 목록> [--in <파일>] [--out <파일>] [--apply] [--timeout <초>] [--yes]`
/// `tbdctl edid <디스플레이> timing <타이밍> [--preferred] [--in <파일>] [--out <파일>] [--apply] [--timeout <초>] [--yes]`
/// `tbdctl edid <디스플레이> apply <파일> [--timeout <초>] [--yes]`
/// `tbdctl edid <디스플레이> reset`
/// (PRD-EDO-001-003, PRD-EDO-005, PRD-CLI-002)
func runEDID(_ command: ParsedCommand, json: Bool) {
    let (display, displays) = resolveDisplay(command.positionals[0])
    let action = command.positionals[1].lowercased()
    let value = command.positionals.count > 2 ? command.positionals[2] : nil

    switch action {
    case "check":
        let (data, source): (Data, String)
        if let value {
            (data, source) = (readEDIDFile(value), value)
        } else {
            (data, source) = sourceEDID(command, display: display, displays: displays)
        }
        let issues = EDIDEditor.validate(data)
        let capabilities = data.count >= 128 ? EDIDParser.parse(data).sinkCapabilities : nil
        if json {
            printJSON(EDIDCheckOutput(source: source, byteCount: data.count, issues: issues, capabilities: capabilities))
        } else {
            print("EDID \(source): \(data.count)바이트, \(issues.isEmpty ? "구조 검증 통과" : "구조 검증 실패")")
            for issue in issues { print("  문제: \(issue)") }
            for row in capabilities?.comparisonRows ?? [] { print("  \(row.label): \(row.value)") }
        }
        if !issues.isEmpty { exit(.failure) }

    case "patch":
        guard let value, let patches = EDIDPatch.parseList(value) else {
            writeError("오류: 편집 목록 형식은 쉼표로 이은 remove-dsc, remove-hdr, remove-ycbcr, remove-420, remove-vrr, limit-frl:<0-6>, limit-tmds:<MHz>")
            exit(.usage)
        }
        runEDIDEdit(patches, command: command, display: display, displays: displays, json: json)

    case "timing":
        guard let value, let spec = DetailedTimingSpec.parse(value) else {
            writeError("오류: 타이밍 형식은 <폭>x<높이>@<주사율>[:rb|:rb2] 또는 raw:<수평 활성>,<프런트 포치>,<동기>,<백 포치>,<수직 활성>,<프런트 포치>,<동기>,<백 포치>,<픽셀 클록 kHz>[,+h|-h][,+v|-v]")
            exit(.usage)
        }
        if !json {
            print("타이밍: \(spec.label)")
            print("  수평: 활성 \(spec.hActive), 프런트 포치 \(spec.hFrontPorch), 동기 \(spec.hSyncWidth), 백 포치 \(spec.hBackPorch), 총 \(spec.hTotal)")
            print("  수직: 활성 \(spec.vActive), 프런트 포치 \(spec.vFrontPorch), 동기 \(spec.vSyncWidth), 백 포치 \(spec.vBackPorch), 총 \(spec.vTotal)")
            print("  기록 방식: \(spec.fitsDescriptor ? "EDID 18바이트 상세 타이밍 서술자" : "DisplayID 상세 타이밍 (픽셀 클록 655.35 MHz 초과 또는 서술자 범위 초과)")")
        }
        runEDIDEdit([.addTiming(spec, preferred: command.has("--preferred"))], command: command, display: display, displays: displays, json: json)

    case "i2c":
        // I2C 직접 읽기와 시스템 제공 EDID의 비교. (PRD-INF-005)
        guard !display.identity.isBuiltin, let service = EDIDOverrideService.service(for: display, among: displays) else {
            writeError("오류: \(display.identity.isBuiltin ? "내장 패널은 I2C EDID 읽기 대상이 아님" : "디스플레이에 대응하는 AV 서비스를 찾을 수 없음")")
            exit(.unsupported)
        }
        guard let direct = DDCService.readEDID(service: service) else {
            writeError("오류: I2C EDID 응답 없음 (독, 허브, 변환 어댑터가 I2C를 전달하지 않거나 디스플레이가 응답하지 않음)")
            exit(.unsupported)
        }
        let system = EDIDSource.record(for: display, among: displays)?.data
        let issues = EDIDEditor.validate(direct)
        let comparable = system.map { $0.prefix(direct.count) }
        let differing = comparable.map { sys in zip(direct, sys).enumerated().filter { $0.element.0 != $0.element.1 }.map(\.offset) } ?? []
        if let path = command.options["--out"] {
            do {
                try direct.write(to: URL(fileURLWithPath: path))
            } catch {
                writeError("오류: 파일 저장 실패: \(error.localizedDescription)")
                exit(.failure)
            }
        }
        if json {
            struct Output: Encodable { var byteCount: Int; var issues: [String]; var systemByteCount: Int?; var differingOffsets: [Int] }
            printJSON(Output(byteCount: direct.count, issues: issues, systemByteCount: system?.count, differingOffsets: differing))
        } else {
            print("I2C 직접 읽기: \(direct.count)바이트\(issues.isEmpty ? ", 읽은 범위의 블록 체크섬 정상" : "")")
            for issue in issues { print("  참고: \(issue)") }
            if let system {
                print("시스템 제공 EDID: \(system.count)바이트. 앞 \(direct.count)바이트 비교: \(differing.isEmpty ? "일치" : "다른 바이트 \(differing.count)개 (오프셋 \(differing.prefix(12).map(String.init).joined(separator: ", ")))")")
            }
            if let path = command.options["--out"] { print("저장: \(path)") }
        }

    case "apply":
        guard let value else {
            writeError("오류: 인자 누락: <파일>")
            exit(.usage)
        }
        let data = readEDIDFile(value)
        let issues = EDIDEditor.validate(data)
        guard issues.isEmpty else {
            writeError("오류: EDID 검증 실패: \(issues.joined(separator: ", "))")
            exit(.failure)
        }
        applyOverride(data, display: display, displays: displays, detail: URL(fileURLWithPath: value).lastPathComponent, command: command)

    case "reset":
        guard !display.identity.isBuiltin else {
            writeError("오류: 내장 디스플레이는 EDID 오버라이드 대상이 아님")
            exit(.unsupported)
        }
        do {
            let entryID = EDIDOverrideService.service(for: display, among: displays)?.registryEntryID
            try EDIDOverrideService.reset(registryEntryID: entryID)
            print("가상 EDID 해제 요청 완료. 원본 EDID로 재감지")
        } catch {
            writeError("오류: \(RevertCoordinator.describe(error))")
            exit(.failure)
        }

    default:
        writeError("오류: 동작은 check, i2c, patch, timing, apply, reset 중 하나")
        exit(.usage)
    }
}

/// `tbdctl redetect` (PRD-EDO-004)
func runRedetect() {
    guard PrivateSymbols.shared.status(of: .redetect).isAvailable else {
        writeError("오류: 이 시스템에서 디스플레이 재감지 사용 불가")
        exit(.unsupported)
    }
    guard EDIDOverrideService.redetect() else {
        writeError("오류: 디스플레이 재감지 요청 실패")
        exit(.failure)
    }
    print("디스플레이 재감지 요청 완료")
}
