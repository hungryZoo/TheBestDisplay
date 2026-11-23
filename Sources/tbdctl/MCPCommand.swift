import Foundation
import TBDCore

/// `tbdctl mcp` (PRD-AGT-001, SRS-AGT-002): 표준 입출력의 MCP 서버. AI 에이전트 클라이언트가 실행.
///
/// 도구 호출은 같은 실행 파일을 하위 프로세스로 실행해 처리. 명령마다 종료 코드로 끝나는 기존 구조를 그대로 쓰기 위함.
/// 표준 출력에는 JSON-RPC 메시지만 내보냄.
func runMCPServer() {
    // 하위 프로세스가 먼저 끝난 뒤의 파이프 쓰기가 서버를 종료시키지 않게 함.
    signal(SIGPIPE, SIG_IGN)
    var session = MCPSession()
    let runner = MCPToolRunner()
    while let line = readLine(strippingNewline: true) {
        guard let response = session.handle(line: line, callTool: runner.call) else { continue }
        print(response)
        fflush(stdout)
    }
    // 입력이 닫히면 종료. 확인 대기 중인 변경은 하위 프로세스가 제한 시간 뒤 스스로 복귀.
}

/// 도구 실행기: 실행 계획을 `tbdctl` 하위 프로세스로 수행.
final class MCPToolRunner {
    /// 읽기와 즉시 실행 명령의 제한 시간 (초). 재초기화의 재연결 대기 15초보다 길게.
    static let commandTimeout: TimeInterval = 90
    /// 확인 대기 안내문의 표지. `performGuardedChange`의 출력과 같아야 함.
    static let promptMarker = "유지하려면 Return 입력"

    private var pending: PendingChange?

    private var executable: URL {
        Bundle.main.executableURL ?? URL(fileURLWithPath: CommandLine.arguments[0])
    }

    func call(tool: String, arguments: [String: Any]) -> MCPToolResult? {
        do {
            guard let plan = try MCPToolCatalog.plan(tool: tool, arguments: arguments) else { return nil }
            switch plan {
            case .run(let commands):
                return run(commands)
            case .guarded(let command, let timeout):
                return startGuarded(command, timeout: timeout)
            case .resolve(let keep):
                return resolve(keep: keep)
            }
        } catch let error as MCPToolError {
            return MCPToolResult(text: error.message, isError: true)
        } catch {
            return MCPToolResult(text: String(describing: error), isError: true)
        }
    }

    // MARK: - 읽기와 즉시 실행

    private func run(_ commands: [[String]]) -> MCPToolResult {
        var sections: [String] = []
        var failed = false
        for command in commands {
            let (status, output) = runOnce(command)
            sections.append(output.trimmingCharacters(in: .whitespacesAndNewlines))
            if status != 0 { failed = true }
        }
        return MCPToolResult(text: sections.filter { !$0.isEmpty }.joined(separator: "\n\n"), isError: failed)
    }

    private func runOnce(_ arguments: [String]) -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        process.standardInput = FileHandle.nullDevice
        do { try process.run() } catch { return (1, "tbdctl 실행 실패: \(error.localizedDescription)") }
        // 제한 시간을 넘기면 종료시킴.
        let watchdog = DispatchWorkItem { if process.isRunning { process.terminate() } }
        DispatchQueue.global().asyncAfter(deadline: .now() + Self.commandTimeout, execute: watchdog)
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        watchdog.cancel()
        return (process.terminationStatus, String(decoding: data, as: UTF8.self))
    }

    // MARK: - 자동 복귀 변경

    private func startGuarded(_ command: [String], timeout: Int) -> MCPToolResult {
        if let pending {
            if pending.process.isRunning {
                return MCPToolResult(text: "A change is already pending: \(pending.summary). Call display_change_resolve first.", isError: true)
            }
            // 제한 시간이 지나 스스로 복귀한 이전 변경은 정리.
            self.pending = nil
        }
        let process = Process()
        process.executableURL = executable
        process.arguments = command
        let output = Pipe(), input = Pipe()
        process.standardOutput = output
        process.standardError = output
        process.standardInput = input
        do { try process.run() } catch { return MCPToolResult(text: "tbdctl 실행 실패: \(error.localizedDescription)", isError: true) }

        // 확인 대기 안내문이 나오거나 프로세스가 끝날 때까지 출력 수집.
        var text = ""
        let reader = output.fileHandleForReading
        while !text.contains(Self.promptMarker) {
            let chunk = reader.availableData
            if chunk.isEmpty { break }
            text += String(decoding: chunk, as: UTF8.self)
        }
        let shown = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.contains(Self.promptMarker) else {
            // 적용 전에 끝남: 이미 같은 설정이거나 오류.
            process.waitUntilExit()
            return MCPToolResult(text: shown, isError: process.terminationStatus != 0)
        }
        pending = PendingChange(process: process, input: input.fileHandleForWriting, output: reader, summary: command.dropLast(2).joined(separator: " "))
        return MCPToolResult(text: shown + "\n\nPending: reverts automatically in \(timeout) seconds. Ask the user whether the display looks right, then call display_change_resolve with keep=true or keep=false.")
    }

    private func resolve(keep: Bool) -> MCPToolResult {
        guard let pending else { return MCPToolResult(text: "No pending change.", isError: true) }
        self.pending = nil
        let alreadyEnded = !pending.process.isRunning
        // 빈 줄은 유지, revert는 즉시 복귀. (`waitForReturn`)
        try? pending.input.write(contentsOf: Data((keep ? "\n" : "revert\n").utf8))
        try? pending.input.close()
        let rest = String(decoding: pending.output.readDataToEndOfFile(), as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        pending.process.waitUntilExit()
        if alreadyEnded {
            return MCPToolResult(text: (rest.isEmpty ? "" : rest + "\n\n") + "The timeout had already passed and the change was reverted automatically. Apply it again if it should be kept.", isError: keep)
        }
        return MCPToolResult(text: rest, isError: pending.process.terminationStatus != 0)
    }
}

/// 확인을 기다리는 변경 1건.
struct PendingChange {
    let process: Process
    let input: FileHandle
    let output: FileHandle
    let summary: String
}
