import Foundation

/// GitHub 릴리스 본문(Markdown)을 인라인 Markdown 표시용 텍스트로 단순화.
/// 제목은 굵게, 목록 기호는 `•`, 코드 블록 울타리(```)는 제거. 줄바꿈은 유지.
public enum ReleaseNotesFormatter {
    public static func inlineMarkdown(_ body: String) -> String {
        let lines = body
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n")

        var output: [String] = []
        var previousWasBlank = true
        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("```") { continue }

            let converted: String
            if line.isEmpty {
                guard !previousWasBlank else { continue }
                converted = ""
            } else if let heading = headingText(line) {
                converted = "**\(heading)**"
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                let indent = rawLine.prefix { $0 == " " }.count >= 2 ? "    " : ""
                converted = indent + "• " + line.dropFirst(2)
            } else {
                converted = rawLine.trimmingCharacters(in: .whitespaces)
            }
            output.append(converted)
            previousWasBlank = converted.isEmpty
        }
        while output.last?.isEmpty == true {
            output.removeLast()
        }
        return output.joined(separator: "\n")
    }

    private static func headingText(_ line: String) -> String? {
        let hashes = line.prefix { $0 == "#" }
        guard (1...6).contains(hashes.count) else { return nil }
        let rest = line.dropFirst(hashes.count)
        guard rest.first == " " else { return nil }
        let text = rest.trimmingCharacters(in: .whitespaces)
        return text.isEmpty ? nil : text
    }
}
