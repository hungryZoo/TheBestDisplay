import Foundation

/// tbdctl 종료 코드. (PRD-CLI-003)
public enum ExitCode: Int32, Sendable {
    case success = 0
    case failure = 1
    case usage = 2
    case unsupported = 3
}

/// 명령 1개의 인자 규격.
public struct CommandSpec: Sendable {
    public var name: String
    public var summary: String
    /// 위치 인자 이름. 표시용이며 개수 검사에 사용.
    public var positionals: [String]
    /// 생략 가능한 위치 인자 수 (뒤에서부터).
    public var optionalPositionals: Int
    /// 값을 받는 옵션. 예: "--edid-out"
    public var valueOptions: Set<String>
    /// 값을 받지 않는 플래그. 예: "--json"
    public var flags: Set<String>

    public init(name: String, summary: String, positionals: [String] = [], optionalPositionals: Int = 0, valueOptions: Set<String> = [], flags: Set<String> = []) {
        self.name = name
        self.summary = summary
        self.positionals = positionals
        self.optionalPositionals = optionalPositionals
        self.valueOptions = valueOptions
        self.flags = flags
    }

    public var usageLine: String {
        let required = positionals.count - optionalPositionals
        let pos = positionals.enumerated().map { $0.offset < required ? "<\($0.element)>" : "[\($0.element)]" }
        let opts = valueOptions.sorted().map { "[\($0) <값>]" } + flags.sorted().map { "[\($0)]" }
        return (["tbdctl", name] + pos + opts).joined(separator: " ")
    }
}

/// 해석된 명령.
public struct ParsedCommand: Equatable, Sendable {
    public var name: String
    public var positionals: [String]
    public var options: [String: String]
    public var flags: Set<String>

    public func has(_ flag: String) -> Bool { flags.contains(flag) }
}

public enum CommandLineError: Error, Equatable, Sendable {
    case noCommand
    case unknownCommand(String)
    case unknownOption(command: String, option: String)
    case missingOptionValue(command: String, option: String)
    case missingArgument(command: String, argument: String)
    case tooManyArguments(command: String)

    public var message: String {
        switch self {
        case .noCommand: "명령 없음"
        case .unknownCommand(let name): "알 수 없는 명령: \(name)"
        case .unknownOption(_, let option): "알 수 없는 옵션: \(option)"
        case .missingOptionValue(_, let option): "옵션 값 누락: \(option)"
        case .missingArgument(_, let argument): "인자 누락: <\(argument)>"
        case .tooManyArguments: "인자 초과"
        }
    }

    /// 사용법 오류는 전부 종료 코드 2.
    public var exitCode: ExitCode { .usage }
}

/// 외부 의존성 없는 하위 명령 해석기. (SRS-CLI-001)
public struct CommandLineParser: Sendable {
    public var specs: [CommandSpec]
    /// 모든 명령에 공통인 플래그.
    public var globalFlags: Set<String>

    public init(specs: [CommandSpec], globalFlags: Set<String> = ["--json"]) {
        self.specs = specs
        self.globalFlags = globalFlags
    }

    /// 프로그램 이름을 제외한 인자 배열을 해석.
    public func parse(_ arguments: [String]) throws -> ParsedCommand {
        guard let name = arguments.first else { throw CommandLineError.noCommand }
        guard let spec = specs.first(where: { $0.name == name }) else { throw CommandLineError.unknownCommand(name) }

        var positionals: [String] = []
        var options: [String: String] = [:]
        var flags: Set<String> = []
        var index = 1
        var optionsEnded = false
        while index < arguments.count {
            let arg = arguments[index]
            index += 1
            if !optionsEnded, arg == "--" {
                optionsEnded = true
            } else if !optionsEnded, arg.hasPrefix("--") {
                if spec.flags.contains(arg) || globalFlags.contains(arg) {
                    flags.insert(arg)
                } else if spec.valueOptions.contains(arg) {
                    guard index < arguments.count else { throw CommandLineError.missingOptionValue(command: name, option: arg) }
                    options[arg] = arguments[index]
                    index += 1
                } else {
                    throw CommandLineError.unknownOption(command: name, option: arg)
                }
            } else {
                positionals.append(arg)
            }
        }

        let required = spec.positionals.count - spec.optionalPositionals
        if positionals.count < required {
            throw CommandLineError.missingArgument(command: name, argument: spec.positionals[positionals.count])
        }
        if positionals.count > spec.positionals.count {
            throw CommandLineError.tooManyArguments(command: name)
        }
        return ParsedCommand(name: name, positionals: positionals, options: options, flags: flags)
    }

    public var usage: String {
        var lines = ["사용법: tbdctl <명령> [인자] [--json]", "", "명령:"]
        let width = (specs.map(\.name.count).max() ?? 0) + 2
        for spec in specs {
            lines.append("  " + spec.name.padding(toLength: width, withPad: " ", startingAt: 0) + spec.summary)
        }
        lines += ["", "종료 코드: 0 성공, 1 실행 실패, 2 사용법 오류, 3 미지원 기능 또는 대상 없음"]
        return lines.joined(separator: "\n")
    }
}

/// 명령행의 디스플레이 지정자 해석. (PRD-CLI-001)
/// 허용 형식: 1부터 시작하는 순번, 디스플레이 ID(`id:<숫자>`), `main`, `builtin`, `external`, 이름 일부.
public enum DisplaySelector {
    public enum SelectionError: Error, Equatable, Sendable {
        case notFound(String)
        case ambiguous(String, matches: [String])

        public var message: String {
            switch self {
            case .notFound(let selector): "디스플레이 없음: \(selector)"
            case .ambiguous(let selector, let matches): "디스플레이 지정이 여러 대에 해당: \(selector) (\(matches.joined(separator: ", ")))"
            }
        }

        /// 대상 없음은 종료 코드 3.
        public var exitCode: ExitCode { .unsupported }
    }

    public static func resolve(_ selector: String, in displays: [DisplaySummary]) throws -> DisplaySummary {
        let lower = selector.lowercased()
        switch lower {
        case "main":
            if let d = displays.first(where: \.isMain) { return d }
            throw SelectionError.notFound(selector)
        case "builtin":
            if let d = displays.first(where: \.identity.isBuiltin) { return d }
            throw SelectionError.notFound(selector)
        case "external":
            let externals = displays.filter { !$0.identity.isBuiltin }
            if externals.count == 1 { return externals[0] }
            if externals.isEmpty { throw SelectionError.notFound(selector) }
            throw SelectionError.ambiguous(selector, matches: externals.map(\.identity.name))
        default:
            break
        }
        if lower.hasPrefix("id:"), let id = UInt32(lower.dropFirst(3)) {
            if let d = displays.first(where: { $0.identity.displayID == id }) { return d }
            throw SelectionError.notFound(selector)
        }
        if let index = Int(selector) {
            guard index >= 1, index <= displays.count else { throw SelectionError.notFound(selector) }
            return displays[index - 1]
        }
        let matches = displays.filter { $0.identity.name.lowercased().contains(lower) }
        if matches.count == 1 { return matches[0] }
        if matches.isEmpty { throw SelectionError.notFound(selector) }
        throw SelectionError.ambiguous(selector, matches: matches.map(\.identity.name))
    }
}
