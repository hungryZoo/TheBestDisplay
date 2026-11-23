import Foundation

/// MCP 서버의 메시지 처리: 표준 입출력 전송의 JSON-RPC 2.0, 한 줄에 메시지 1개. (SRS-AGT-001)
///
/// 지원 범위: `initialize`, `ping`, `tools/list`, `tools/call`과 알림. 리소스와 프롬프트는 제공하지 않음.
public struct MCPSession {
    /// 지원하는 프로토콜 판. 앞쪽이 최신.
    public static let supportedVersions = ["2025-06-18", "2025-03-26", "2024-11-05"]

    public var serverVersion: String
    public private(set) var isInitialized = false

    public init(serverVersion: String = AppVersion.current) {
        self.serverVersion = serverVersion
    }

    /// 입력 한 줄을 처리해 응답 한 줄을 반환. 응답이 없는 메시지(알림, 빈 줄)는 nil.
    /// 도구 실행은 `callTool`에 맡김: 인자는 도구 이름과 인자 사전, 알 수 없는 도구면 nil 반환.
    public mutating func handle(line: String, callTool: (String, [String: Any]) -> MCPToolResult?) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let data = trimmed.data(using: .utf8), let parsed = try? JSONSerialization.jsonObject(with: data) else {
            return Self.encode(Self.failure(id: NSNull(), code: -32700, message: "Parse error"))
        }
        guard let message = parsed as? [String: Any], let method = message["method"] as? String else {
            // 묶음 요청과 응답 형태의 메시지는 받지 않음.
            return Self.encode(Self.failure(id: (parsed as? [String: Any])?["id"] ?? NSNull(), code: -32600, message: "Invalid request"))
        }
        // id가 없으면 알림: 응답하지 않음.
        guard let id = message["id"], !(id is NSNull) else {
            if method == "notifications/initialized" { isInitialized = true }
            return nil
        }
        let params = message["params"] as? [String: Any] ?? [:]

        switch method {
        case "initialize":
            let requested = params["protocolVersion"] as? String
            let version = requested.flatMap { Self.supportedVersions.contains($0) ? $0 : nil } ?? Self.supportedVersions[0]
            return Self.encode(Self.success(id: id, result: [
                "protocolVersion": version,
                "capabilities": ["tools": [String: Any]()],
                "serverInfo": ["name": MCPToolCatalog.serverName, "version": serverVersion],
                "instructions": MCPToolCatalog.instructions,
            ]))

        case "ping":
            return Self.encode(Self.success(id: id, result: [:]))

        case "tools/list":
            return Self.encode(Self.success(id: id, result: ["tools": MCPToolCatalog.tools()]))

        case "tools/call":
            guard let name = params["name"] as? String else {
                return Self.encode(Self.failure(id: id, code: -32602, message: "Missing tool name"))
            }
            let arguments = params["arguments"] as? [String: Any] ?? [:]
            guard let result = callTool(name, arguments) else {
                return Self.encode(Self.failure(id: id, code: -32602, message: "Unknown tool: \(name)"))
            }
            return Self.encode(Self.success(id: id, result: [
                "content": [["type": "text", "text": result.text]],
                "isError": result.isError,
            ]))

        default:
            return Self.encode(Self.failure(id: id, code: -32601, message: "Method not found: \(method)"))
        }
    }

    static func success(id: Any, result: [String: Any]) -> [String: Any] {
        ["jsonrpc": "2.0", "id": id, "result": result]
    }

    static func failure(id: Any, code: Int, message: String) -> [String: Any] {
        ["jsonrpc": "2.0", "id": id, "error": ["code": code, "message": message]]
    }

    /// 한 줄 JSON. 줄바꿈은 문자열 안에서 이스케이프되므로 메시지 경계와 겹치지 않음.
    static func encode(_ object: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes]),
              let text = String(data: data, encoding: .utf8)
        else { return #"{"jsonrpc":"2.0","id":null,"error":{"code":-32603,"message":"Internal error"}}"# }
        return text
    }
}
