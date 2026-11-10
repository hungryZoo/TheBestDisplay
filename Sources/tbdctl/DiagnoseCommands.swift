import Foundation
import TBDCore
import TBDPlatform

let tbdVersion = "0.1.0"

/// `tbdctl diagnose [--json]` (PRD-DGN-001-003, PRD-DGN-006)
func runDiagnose(_ command: ParsedCommand, json: Bool) {
    let snapshot = SnapshotBuilder.build()
    let result = DiagnosticEngine.evaluate(snapshot)
    if json {
        printJSON(result)
        return
    }
    print("포트 점검")
    for d in result.portDiagnoses {
        if d.isIdle {
            print("  \(d.port.label): 연결 없음")
            continue
        }
        print("  \(d.port.label): \(d.isFullyPassed ? "전 단계 통과" : "\(d.firstFailure?.title ?? "") 단계 미통과")")
        for c in d.checks {
            let mark = c.result == .pass ? "통과" : c.result == .fail ? "실패" : "생략"
            print("    [\(mark)] \(c.stage.title): \(c.detail)")
        }
    }
    print("발견 항목 \(result.findings.count)건")
    for f in result.findings {
        print("  [\(f.severity.label)] \(f.subject.map { "\($0): " } ?? "")\(f.title)  (\(f.code))")
        print("    근거: \(f.detail)")
        print("    조치: \(f.remedy)")
    }
}

/// `tbdctl report <경로> [--redact] [--text]` (PRD-DGN-005): 확장자와 무관하게 `--text`가 없으면 JSON.
func runReport(_ command: ParsedCommand) {
    let report = DiagnosticReport(snapshot: SnapshotBuilder.build(), events: [], appVersion: tbdVersion, redact: command.has("--redact"))
    let url = URL(fileURLWithPath: command.positionals[0])
    do {
        if command.has("--text") {
            try Data(ReportExporter.text(report).utf8).write(to: url)
        } else {
            try ReportExporter.json(report).write(to: url)
        }
    } catch {
        writeError("오류: 보고서 저장 실패: \(error.localizedDescription)")
        exit(.failure)
    }
    print("보고서 저장: \(url.path) (발견 항목 \(report.result.findings.count)건\(report.redacted ? ", 일련번호 가림" : ""))")
}
