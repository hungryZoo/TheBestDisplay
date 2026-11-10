import Foundation

/// 16진 표시. 줄당 16바이트, 앞에 오프셋.
public enum HexDump {
    public static func format(_ data: Data) -> String {
        let bytes = [UInt8](data)
        return stride(from: 0, to: bytes.count, by: 16).map { offset in
            let row = bytes[offset..<min(offset + 16, bytes.count)]
            return String(format: "%04x  ", offset) + row.map { String(format: "%02x", $0) }.joined(separator: " ")
        }.joined(separator: "\n")
    }
}
