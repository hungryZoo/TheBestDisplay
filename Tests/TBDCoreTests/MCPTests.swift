import Foundation
import Testing
@testable import TBDCore

private func object(_ line: String?) throws -> [String: Any] {
    let text = try #require(line)
    // 응답은 한 줄.
    #expect(!text.contains("\n"))
    return try #require(try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
}

/// TC-AGT-001: MCP 메시지 처리.
@Suite("TC-AGT-001 MCP 메시지 처리")
struct MCPSessionTests {
    static func noTool(_: String, _: [String: Any]) -> MCPToolResult? { nil }

    @Test func 초기화와_판_협상() throws {
        var session = MCPSession(serverVersion: "9.9.9")
        let reply = try object(session.handle(line: #"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{}}}"#, callTool: Self.noTool))
        let result = try #require(reply["result"] as? [String: Any])
        // 지원하는 판은 요청한 판 그대로.
        #expect(result["protocolVersion"] as? String == "2025-03-26")
        #expect((result["serverInfo"] as? [String: Any])?["name"] as? String == "thebestdisplay")
        #expect((result["serverInfo"] as? [String: Any])?["version"] as? String == "9.9.9")
        #expect((result["capabilities"] as? [String: Any])?["tools"] != nil)
        #expect((result["instructions"] as? String)?.contains("display_diagnose") == true)
        #expect(reply["id"] as? Int == 1)

        // 모르는 판을 요청하면 서버의 최신 판.
        let other = try object(session.handle(line: #"{"jsonrpc":"2.0","id":"a","method":"initialize","params":{"protocolVersion":"2099-01-01"}}"#, callTool: Self.noTool))
        #expect((other["result"] as? [String: Any])?["protocolVersion"] as? String == MCPSession.supportedVersions[0])
        // 문자열 id는 그대로 돌려줌.
        #expect(other["id"] as? String == "a")
    }

    @Test func 알림과_빈_줄은_응답_없음() {
        var session = MCPSession()
        #expect(session.handle(line: "", callTool: Self.noTool) == nil)
        #expect(session.handle(line: "   ", callTool: Self.noTool) == nil)
        #expect(!session.isInitialized)
        #expect(session.handle(line: #"{"jsonrpc":"2.0","method":"notifications/initialized"}"#, callTool: Self.noTool) == nil)
        #expect(session.isInitialized)
        #expect(session.handle(line: #"{"jsonrpc":"2.0","method":"notifications/cancelled","params":{"requestId":3}}"#, callTool: Self.noTool) == nil)
    }

    @Test func 도구_목록() throws {
        var session = MCPSession()
        let reply = try object(session.handle(line: #"{"jsonrpc":"2.0","id":2,"method":"tools/list"}"#, callTool: Self.noTool))
        let tools = try #require((reply["result"] as? [String: Any])?["tools"] as? [[String: Any]])
        #expect(tools.compactMap { $0["name"] as? String } == ["display_diagnose", "display_query", "display_change", "display_change_resolve", "display_recover"])
        for tool in tools {
            #expect((tool["description"] as? String)?.isEmpty == false)
            #expect((tool["inputSchema"] as? [String: Any])?["type"] as? String == "object")
        }
        // 읽기 도구 표시.
        #expect(tools.filter { ($0["annotations"] as? [String: Any])?["readOnlyHint"] as? Bool == true }.count == 2)
        // 세션마다 실리는 정의의 크기 상한.
        #expect(try JSONSerialization.data(withJSONObject: tools).count < 6000)
    }

    @Test func 도구_호출과_오류() throws {
        var session = MCPSession()
        var received: (String, [String: Any])?
        let reply = try object(session.handle(line: #"{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"display_query","arguments":{"topic":"signal","display":"LG TV"}}}"#) { name, arguments in
            received = (name, arguments)
            return MCPToolResult(text: "첫 줄\n둘째 줄", isError: false)
        })
        #expect(received?.0 == "display_query")
        #expect(received?.1["display"] as? String == "LG TV")
        let result = try #require(reply["result"] as? [String: Any])
        #expect(result["isError"] as? Bool == false)
        #expect(((result["content"] as? [[String: Any]])?.first)?["text"] as? String == "첫 줄\n둘째 줄")

        // 도구가 실패하면 결과 안의 오류 표시.
        let failed = try object(session.handle(line: #"{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"display_query"}}"#) { _, _ in MCPToolResult(text: "실패", isError: true) })
        #expect((failed["result"] as? [String: Any])?["isError"] as? Bool == true)

        func errorCode(_ line: String) throws -> Int? {
            ((try object(session.handle(line: line, callTool: Self.noTool)))["error"] as? [String: Any])?["code"] as? Int
        }
        #expect(try errorCode(#"{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"없는도구"}}"#) == -32602)
        #expect(try errorCode(#"{"jsonrpc":"2.0","id":6,"method":"tools/call","params":{}}"#) == -32602)
        #expect(try errorCode(#"{"jsonrpc":"2.0","id":7,"method":"resources/list"}"#) == -32601)
        #expect(try errorCode("JSON 아님") == -32700)
        #expect(try errorCode(#"[{"jsonrpc":"2.0","id":8,"method":"ping"}]"#) == -32600)
        #expect(try object(session.handle(line: #"{"jsonrpc":"2.0","id":9,"method":"ping"}"#, callTool: Self.noTool))["result"] != nil)
    }
}

/// TC-AGT-002: MCP 도구 인자의 명령 변환.
@Suite("TC-AGT-002 MCP 도구 인자의 명령 변환")
struct MCPToolCatalogTests {
    typealias Plan = MCPToolCatalog.Plan

    static func message(_ tool: String, _ arguments: [String: Any]) -> String? {
        do {
            _ = try MCPToolCatalog.plan(tool: tool, arguments: arguments)
            return nil
        } catch let error as MCPToolError {
            return error.message
        } catch {
            return "\(error)"
        }
    }

    @Test func 읽기_도구() throws {
        #expect(try MCPToolCatalog.plan(tool: "display_diagnose", arguments: [:]) == .run([["list"], ["diagnose"]]))
        #expect(try MCPToolCatalog.plan(tool: "display_query", arguments: ["topic": "signal", "display": " LG TV "]) == .run([["signal", "LG TV"]]))
        // 디스플레이가 필요 없는 주제는 디스플레이 인자를 쓰지 않음.
        #expect(try MCPToolCatalog.plan(tool: "display_query", arguments: ["topic": "ports", "display": "LG TV"]) == .run([["ports"]]))
        #expect(try MCPToolCatalog.plan(tool: "display_query", arguments: ["topic": "capabilities"]) == .run([["capabilities"]]))
        #expect(Self.message("display_query", ["topic": "modes"])?.contains("display") == true)
        #expect(Self.message("display_query", ["topic": "report", "display": "main"])?.contains("Unknown topic") == true)
        #expect(Self.message("display_query", [:])?.contains("Missing argument: topic") == true)
        #expect(try MCPToolCatalog.plan(tool: "없는도구", arguments: [:]) == nil)
    }

    @Test func 변경_도구() throws {
        #expect(try MCPToolCatalog.plan(tool: "display_change", arguments: ["action": "set_mode", "display": "Legion", "value": "1920x1080@60:hidpi"])
            == .guarded(["set-mode", "Legion", "1920x1080@60:hidpi", "--timeout", "60"], timeout: 60))
        #expect(try MCPToolCatalog.plan(tool: "display_change", arguments: ["action": "set_color", "display": "Legion", "value": "rgb:8:full:sdr", "timeout_seconds": 20])
            == .guarded(["set-color", "Legion", "rgb:8:full:sdr", "--timeout", "20"], timeout: 20))
        #expect(try MCPToolCatalog.plan(tool: "display_change", arguments: ["action": "set_hdr", "display": "external", "value": "ON"])
            == .guarded(["hdr", "external", "on", "--timeout", "60"], timeout: 60))
        #expect(try MCPToolCatalog.plan(tool: "display_change", arguments: ["action": "set_rotation", "display": "Legion", "value": "270"])
            == .guarded(["rotate", "Legion", "270", "--timeout", "60"], timeout: 60))
        // 연결 해제는 값이 필요 없음.
        #expect(try MCPToolCatalog.plan(tool: "display_change", arguments: ["action": "disconnect", "display": "Legion", "value": "무시"])
            == .guarded(["disconnect", "Legion", "--timeout", "60"], timeout: 60))
        #expect(try MCPToolCatalog.plan(tool: "display_change_resolve", arguments: ["keep": false]) == .resolve(keep: false))
        #expect(Self.message("display_change_resolve", [:])?.contains("keep") == true)
    }

    @Test func 변경_도구의_거부() {
        // 번호 지정은 받지 않음: 재연결로 ID가 바뀜 (T75 실측).
        for selector in ["id:3", "ID:3", "3"] {
            #expect(Self.message("display_change", ["action": "set_hdr", "display": selector, "value": "on"])?.contains("display name") == true)
        }
        #expect(Self.message("display_change", ["action": "set_mode", "display": "Legion", "value": "큰화면"])?.contains("Invalid mode") == true)
        #expect(Self.message("display_change", ["action": "set_color", "display": "Legion", "value": "rgb:99"])?.contains("Invalid color mode") == true)
        #expect(Self.message("display_change", ["action": "set_hdr", "display": "Legion", "value": "auto"])?.contains("on or off") == true)
        #expect(Self.message("display_change", ["action": "set_rotation", "display": "Legion", "value": "45"])?.contains("0, 90, 180 or 270") == true)
        #expect(Self.message("display_change", ["action": "set_mode", "display": "Legion"])?.contains("value") == true)
        // 옵션처럼 보이는 값은 받지 않음.
        #expect(Self.message("display_change", ["action": "set_mode", "display": "Legion", "value": "--yes"])?.contains("value") == true)
        #expect(Self.message("display_change", ["action": "disconnect", "display": "--yes"])?.contains("Invalid display") == true)
        #expect(Self.message("display_change", ["action": "set_hdr", "display": "Legion", "value": "on", "timeout_seconds": 5])?.contains("between 10 and 120") == true)
        #expect(Self.message("display_change", ["action": "set_hdr", "display": "Legion", "value": "on", "timeout_seconds": true])?.contains("number") == true)
        #expect(Self.message("display_change", ["action": "underscan", "display": "Legion"])?.contains("Unknown action") == true)
    }

    @Test func 복구_도구와_확인_입력() throws {
        // 재연결은 해제된 디스플레이의 ID 지정 허용.
        #expect(try MCPToolCatalog.plan(tool: "display_recover", arguments: ["action": "reconnect", "display": "id:2"]) == .run([["reconnect", "id:2"]]))
        #expect(try MCPToolCatalog.plan(tool: "display_recover", arguments: ["action": "reconnect_all"]) == .run([["reconnect"]]))
        #expect(try MCPToolCatalog.plan(tool: "display_recover", arguments: ["action": "reinit", "display": "LG TV"]) == .run([["reinit", "LG TV"]]))
        #expect(try MCPToolCatalog.plan(tool: "display_recover", arguments: ["action": "redetect"]) == .run([["redetect"]]))
        #expect(try MCPToolCatalog.plan(tool: "display_recover", arguments: ["action": "revert_pending"]) == .run([["revert-pending"]]))
        #expect(Self.message("display_recover", ["action": "reinit", "display": "id:2"])?.contains("display name") == true)
        #expect(Self.message("display_recover", ["action": "reinit"])?.contains("display") == true)

        // 확인 대기 중의 한 줄: revert만 즉시 복귀, 그 밖은 유지.
        #expect(GuardedInput.keeps(""))
        #expect(GuardedInput.keeps("y"))
        #expect(!GuardedInput.keeps("revert"))
        #expect(!GuardedInput.keeps(" REVERT \r"))
    }
}
