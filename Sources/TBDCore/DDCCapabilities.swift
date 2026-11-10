import Foundation

/// DDC/CI capabilities 문자열 해석. 모니터가 지원하는 VCP 코드와 선택값 목록. (PRD-DDC-004, SRS-DDC-002)
/// 문자열 예: `(prot(monitor)type(lcd)model(XYZ)cmds(01 02 03)vcp(10 12 14(05 08 0B) 60(0F 11 12))mccs_ver(2.1))`
public struct DDCCapabilities: Codable, Hashable, Sendable {
    public var raw: String
    public var model: String?
    public var type: String?
    public var mccsVersion: String?
    public var commands: [UInt8]
    /// 지원 VCP 코드 (문자열에 나온 순서).
    public var vcpCodes: [UInt8]
    /// 코드별 선택값 목록. 연속 값 코드는 항목 없음.
    public var vcpValues: [UInt8: [UInt8]]

    public func supports(_ code: UInt8) -> Bool { vcpCodes.contains(code) }

    // MARK: - 패킷

    /// capabilities 요청: `83 F3 오프셋(2) 체크섬`.
    public static func request(offset: Int) -> [UInt8] {
        DDCPacket.seal([0x83, 0xF3, UInt8((offset >> 8) & 0xFF), UInt8(offset & 0xFF)])
    }

    /// capabilities 응답 조각 해석: `6E (0x80|길이) E3 오프셋(2) 자료... 체크섬`. 길이는 E3부터 자료 끝까지.
    /// 자료가 비어 있으면 문자열의 끝.
    public static func parseFragment(_ bytes: [UInt8]) -> (offset: Int, data: [UInt8])? {
        guard bytes.count >= 6, bytes[1] & 0x80 != 0 else { return nil }
        let length = Int(bytes[1] & 0x7F)
        guard length >= 3, bytes.count >= 2 + length + 1, bytes[2] == 0xE3 else { return nil }
        let checksum = bytes[0..<2 + length].reduce(DDCPacket.replyChecksumSeed) { $0 ^ $1 }
        guard checksum == bytes[2 + length] else { return nil }
        return (Int(bytes[3]) << 8 | Int(bytes[4]), Array(bytes[5..<2 + length]))
    }

    // MARK: - 문자열

    /// 괄호 구조 해석. 최상위 괄호 안의 `이름(내용)` 쌍을 읽음.
    public static func parse(_ text: String) -> DDCCapabilities {
        var caps = DDCCapabilities(raw: text, model: nil, type: nil, mccsVersion: nil, commands: [], vcpCodes: [], vcpValues: [:])
        let chars = Array(text.trimmingCharacters(in: CharacterSet(charactersIn: "\0 \n\r")))
        var groups: [String: String] = [:]
        var index = 0
        // 바깥 괄호 하나를 벗김.
        if chars.first == "(" { index = 1 }
        while index < chars.count {
            var name = ""
            while index < chars.count, chars[index] != "(", chars[index] != ")" {
                name.append(chars[index])
                index += 1
            }
            guard index < chars.count, chars[index] == "(" else { break }
            var depth = 0
            var content = ""
            while index < chars.count {
                let c = chars[index]
                index += 1
                if c == "(" {
                    depth += 1
                    if depth == 1 { continue }
                } else if c == ")" {
                    depth -= 1
                    if depth == 0 { break }
                }
                content.append(c)
            }
            groups[name.trimmingCharacters(in: .whitespaces).lowercased()] = content
        }
        caps.model = groups["model"]
        caps.type = groups["type"]
        caps.mccsVersion = groups["mccs_ver"]
        caps.commands = (groups["cmds"] ?? "").split(separator: " ").compactMap { UInt8($0, radix: 16) }
        // vcp 내용: 코드와 선택적 값 목록. 예: "10 12 14(05 08 0B) 60(0F 11)"
        let vcp = Array(groups["vcp"] ?? "")
        var i = 0
        var token = ""
        func flush() {
            if let code = UInt8(token, radix: 16), !caps.vcpCodes.contains(code) { caps.vcpCodes.append(code) }
            token = ""
        }
        while i < vcp.count {
            let c = vcp[i]
            if c == "(" {
                let code = UInt8(token, radix: 16)
                flush()
                var inner = ""
                i += 1
                while i < vcp.count, vcp[i] != ")" {
                    inner.append(vcp[i])
                    i += 1
                }
                if let code { caps.vcpValues[code] = inner.split(separator: " ").compactMap { UInt8($0, radix: 16) } }
            } else if c == " " {
                flush()
            } else {
                token.append(c)
            }
            i += 1
        }
        flush()
        return caps
    }
}
