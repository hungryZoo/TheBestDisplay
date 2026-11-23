import Foundation

/// MCP 도구 호출의 결과. (SRS-AGT-001)
public struct MCPToolResult: Equatable, Sendable {
    public var text: String
    public var isError: Bool

    public init(text: String, isError: Bool = false) {
        self.text = text
        self.isError = isError
    }
}

/// 도구 인자 오류. 문구는 에이전트가 읽으므로 영어.
public struct MCPToolError: Error, Equatable, Sendable {
    public var message: String
    public init(_ message: String) { self.message = message }
}

/// MCP 도구 목록과 `tbdctl` 인자 변환. (PRD-AGT-001, SRS-AGT-001)
///
/// 서버는 `tbdctl`을 그대로 호출하는 얇은 구조. 도구는 5개로 한정해 세션마다 실리는 정의의 크기를 줄임.
/// 도구 이름, 설명, 서버 안내문은 에이전트가 읽는 글이라 영어로 작성. 명령 출력은 `tbdctl`의 한국어 그대로.
public enum MCPToolCatalog {
    public static let serverName = "thebestdisplay"

    /// 초기화 응답의 안내문. 세션마다 문맥에 실리므로 짧게 유지.
    public static let instructions = """
    Controls and diagnoses displays on this Mac through TheBestDisplay (tbdctl). \
    Start with display_diagnose. Use display names, not ids (ids change on reconnect). \
    display_change applies a setting and reverts it automatically unless display_change_resolve keeps it: \
    you cannot see the screen, so ask the user whether the picture is right before keeping a change. \
    Command output is in Korean.
    """

    public static let defaultTimeout = 60
    public static let timeoutRange = 10...120

    /// 변경 도구의 동작과 값 형식.
    static let changeActions = ["set_mode", "set_color", "set_hdr", "set_rotation", "disconnect"]
    static let queryTopics = ["info", "modes", "signal", "link", "hdr", "brightness", "ports", "arrangement", "capabilities"]
    static let topicsWithoutDisplay: Set<String> = ["ports", "arrangement", "capabilities"]
    static let recoverActions = ["reconnect", "reconnect_all", "reinit", "redetect", "revert_pending"]

    /// 도구 정의 (MCP `tools/list`의 `tools` 배열).
    public static func tools() -> [[String: Any]] {
        func string(_ description: String, enumeration: [String]? = nil) -> [String: Any] {
            var schema: [String: Any] = ["type": "string", "description": description]
            if let enumeration { schema["enum"] = enumeration }
            return schema
        }
        func tool(_ name: String, _ description: String, properties: [String: Any] = [:], required: [String] = [], readOnly: Bool) -> [String: Any] {
            var schema: [String: Any] = ["type": "object", "properties": properties]
            if !required.isEmpty { schema["required"] = required }
            return ["name": name, "description": description, "inputSchema": schema, "annotations": ["readOnlyHint": readOnly]]
        }
        let display = string("Display name or part of it (e.g. \"LG TV\"), or main, builtin, external.")
        return [
            tool("display_diagnose",
                 "Start here for any monitor problem on this Mac: no picture, wrong colors, flicker, wrong resolution or refresh rate, display not detected. Returns the display list with current modes, a per-port check (physical connection, HPD, EDID, link, framebuffer, online) and findings with remedies. Read-only.",
                 readOnly: true),
            tool("display_query",
                 "Read-only details on one topic. info: product and EDID. modes: every resolution and refresh rate. signal: pixel encoding, bit depth, range, and the color modes that can be selected. link: link rate, lanes, bandwidth. hdr, brightness: current state. ports: cables, docks, connection paths. arrangement: positions, rotation, mirroring. capabilities: features this macOS allows. ports, arrangement and capabilities take no display.",
                 properties: ["topic": string("What to read.", enumeration: queryTopics), "display": display],
                 required: ["topic"], readOnly: true),
            tool("display_change",
                 "Apply one display setting with automatic revert. The change takes effect at once and reverts by itself after timeout_seconds unless display_change_resolve is called with keep=true. After applying, ask the user whether the display looks right, then resolve. One pending change at a time. value: set_mode \"<width>x<height>[@<hz>][:hidpi|:lodpi]\" or \"mode:<number>\" (see topic modes); set_color \"<rgb|ycbcr444|ycbcr422|ycbcr420>[:<bpc>][:<full|limited>][:<sdr|pq|hlg>]\" (see topic signal; on macOS 27 only formats tagged 시스템 제공); set_hdr \"on\" or \"off\"; set_rotation \"0\", \"90\", \"180\" or \"270\"; disconnect takes no value and removes the display from the system without unplugging the cable (undo with display_recover reconnect).",
                 properties: [
                    "action": string("Setting to change.", enumeration: changeActions),
                    "display": display,
                    "value": string("New value in the format given for the action."),
                    "timeout_seconds": ["type": "integer", "description": "Seconds before automatic revert. 10-120, default 60.", "minimum": timeoutRange.lowerBound, "maximum": timeoutRange.upperBound],
                 ],
                 required: ["action", "display"], readOnly: false),
            tool("display_change_resolve",
                 "Finish the pending display_change: keep=true keeps the new setting, keep=false reverts it now.",
                 properties: ["keep": ["type": "boolean", "description": "true to keep, false to revert."]],
                 required: ["keep"], readOnly: false),
            tool("display_recover",
                 "Recovery actions, applied at once. reconnect: bring back a display removed with disconnect (display = its name or id from the 연결 해제됨 line of display_diagnose). reconnect_all: every disconnected display. reinit: disconnect then reconnect one display so the system configures it again; its screen goes dark for a few seconds. redetect: ask the system to rescan displays. revert_pending: undo a change that was left unconfirmed.",
                 properties: ["action": string("Recovery action.", enumeration: recoverActions), "display": string("Display name, or for reconnect the id of a disconnected display. Needed for reconnect and reinit.")],
                 required: ["action"], readOnly: false),
        ]
    }

    /// 도구 호출의 실행 계획.
    public enum Plan: Equatable, Sendable {
        /// `tbdctl` 명령을 차례로 실행하고 출력을 이어 붙임.
        case run([[String]])
        /// 자동 복귀 변경: 명령을 실행해 적용하고 확인을 기다림.
        case guarded([String], timeout: Int)
        /// 대기 중인 변경의 확정 또는 복귀.
        case resolve(keep: Bool)
    }

    /// 도구 이름과 인자를 실행 계획으로 변환. 알 수 없는 도구는 nil.
    public static func plan(tool: String, arguments: [String: Any]) throws -> Plan? {
        func text(_ key: String) -> String? {
            (arguments[key] as? String).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.flatMap { $0.isEmpty ? nil : $0 }
        }
        func require(_ key: String, among allowed: [String]) throws -> String {
            guard let value = text(key) else { throw MCPToolError("Missing argument: \(key). One of: \(allowed.joined(separator: ", ")).") }
            guard allowed.contains(value) else { throw MCPToolError("Unknown \(key): \(value). One of: \(allowed.joined(separator: ", ")).") }
            return value
        }
        func requireDisplay(allowID: Bool = false) throws -> String {
            guard let value = text("display") else { throw MCPToolError("Missing argument: display. Use a name from display_diagnose.") }
            if !allowID, isNumericSelector(value) {
                throw MCPToolError("Use the display name, not an id or index: ids change when displays reconnect. Names are in display_diagnose.")
            }
            // 옵션으로 해석될 값은 받지 않음.
            guard !value.hasPrefix("-") else { throw MCPToolError("Invalid display: \(value).") }
            return value
        }

        switch tool {
        case "display_diagnose":
            return .run([["list"], ["diagnose"]])

        case "display_query":
            let topic = try require("topic", among: queryTopics)
            if topicsWithoutDisplay.contains(topic) { return .run([[topic]]) }
            return .run([[topic, try requireDisplay()]])

        case "display_change":
            let action = try require("action", among: changeActions)
            let display = try requireDisplay()
            let timeout = try timeoutSeconds(arguments["timeout_seconds"])
            var command: [String]
            if action == "disconnect" {
                command = ["disconnect", display]
            } else {
                guard let value = text("value"), !value.hasPrefix("-") else { throw MCPToolError("Missing or invalid argument: value (required for \(action)).") }
                switch action {
                case "set_mode":
                    guard ModeSpec.parse(value) != nil else { throw MCPToolError("Invalid mode: \(value). Use <width>x<height>[@<hz>][:hidpi|:lodpi] or mode:<number>.") }
                    command = ["set-mode", display, value]
                case "set_color":
                    guard ColorSpec.parse(value) != nil else { throw MCPToolError("Invalid color mode: \(value). Use <rgb|ycbcr444|ycbcr422|ycbcr420>[:<bpc>][:<full|limited>][:<sdr|pq|hlg>] or id:<number>.") }
                    command = ["set-color", display, value]
                case "set_hdr":
                    guard ["on", "off"].contains(value.lowercased()) else { throw MCPToolError("Invalid value for set_hdr: \(value). Use on or off.") }
                    command = ["hdr", display, value.lowercased()]
                default:
                    guard ["0", "90", "180", "270"].contains(value) else { throw MCPToolError("Invalid value for set_rotation: \(value). Use 0, 90, 180 or 270.") }
                    command = ["rotate", display, value]
                }
            }
            command += ["--timeout", String(timeout)]
            return .guarded(command, timeout: timeout)

        case "display_change_resolve":
            guard let keep = arguments["keep"] as? Bool else { throw MCPToolError("Missing argument: keep (true or false).") }
            return .resolve(keep: keep)

        case "display_recover":
            switch try require("action", among: recoverActions) {
            case "reconnect": return .run([["reconnect", try requireDisplay(allowID: true)]])
            case "reconnect_all": return .run([["reconnect"]])
            case "reinit": return .run([["reinit", try requireDisplay()]])
            case "redetect": return .run([["redetect"]])
            default: return .run([["revert-pending"]])
            }

        default:
            return nil
        }
    }

    /// `id:3`, `3` 같은 번호 지정인지.
    static func isNumericSelector(_ value: String) -> Bool {
        let lower = value.lowercased()
        let body = lower.hasPrefix("id:") ? String(lower.dropFirst(3)) : lower
        return !body.isEmpty && body.allSatisfy(\.isNumber)
    }

    static func timeoutSeconds(_ raw: Any?) throws -> Int {
        guard let raw else { return defaultTimeout }
        // JSON 숫자는 정수와 실수 모두 허용. 참과 거짓은 숫자로 보지 않음.
        guard let number = raw as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else {
            throw MCPToolError("timeout_seconds must be a number between \(timeoutRange.lowerBound) and \(timeoutRange.upperBound).")
        }
        let value = number.intValue
        guard timeoutRange.contains(value) else {
            throw MCPToolError("timeout_seconds must be between \(timeoutRange.lowerBound) and \(timeoutRange.upperBound).")
        }
        return value
    }
}

/// 자동 복귀 확인 입력의 해석. (SRS-AGT-002)
public enum GuardedInput {
    /// 확인 대기 중 들어온 한 줄이 유지 의사인지. `revert`는 즉시 복귀, 그 밖의 줄(빈 줄 포함)은 유지.
    public static func keeps(_ line: String) -> Bool {
        line.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() != "revert"
    }
}
