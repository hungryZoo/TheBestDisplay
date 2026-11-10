import Foundation

/// ICC 프로파일의 태그 단위 읽기와 다시 쓰기. 행렬 방식 디스플레이 프로파일의 색 좌표 태그 편집에 사용. (SRS-CLR-007)
///
/// 구조: 머리 128바이트, 태그 수(4), 태그 표(서명 4, 오프셋 4, 크기 4), 태그 자료. 여러 태그가 같은 자료를 가리킬 수 있음.
public struct ICCProfile: Equatable, Sendable {
    public struct Tag: Equatable, Sendable {
        public var signature: String
        /// `blocks`의 색인. 같은 자료를 공유하는 태그는 같은 색인.
        public var block: Int
    }

    public struct XYZ: Equatable, Sendable {
        public var x: Double
        public var y: Double
        public var z: Double

        public init(x: Double, y: Double, z: Double) {
            self.x = x
            self.y = y
            self.z = z
        }

        static func + (a: XYZ, b: XYZ) -> XYZ { XYZ(x: a.x + b.x, y: a.y + b.y, z: a.z + b.z) }
        static func * (a: XYZ, k: Double) -> XYZ { XYZ(x: a.x * k, y: a.y * k, z: a.z * k) }
    }

    public enum ParseError: Error, LocalizedError, Equatable {
        case tooShort
        case badSignature
        case badTagTable
        case missingTag(String)
        case wrongTagType(String)

        public var errorDescription: String? {
            switch self {
            case .tooShort: "ICC 프로파일 길이가 머리 크기보다 짧음"
            case .badSignature: "ICC 프로파일 서명(acsp) 없음"
            case .badTagTable: "ICC 태그 표가 파일 범위를 벗어남"
            case .missingTag(let tag): "ICC 태그 없음: \(tag)"
            case .wrongTagType(let tag): "ICC 태그 형식이 예상과 다름: \(tag)"
            }
        }
    }

    public var header: [UInt8]
    public var tags: [Tag]
    public var blocks: [[UInt8]]

    static func u32(_ bytes: [UInt8], _ offset: Int) -> Int {
        Int(bytes[offset]) << 24 | Int(bytes[offset + 1]) << 16 | Int(bytes[offset + 2]) << 8 | Int(bytes[offset + 3])
    }

    static func be32(_ value: UInt32) -> [UInt8] {
        [UInt8(value >> 24), UInt8((value >> 16) & 0xFF), UInt8((value >> 8) & 0xFF), UInt8(value & 0xFF)]
    }

    static func signature(_ bytes: ArraySlice<UInt8>) -> String { String(decoding: bytes, as: Unicode.ASCII.self) }

    public init(data: Data) throws {
        let bytes = [UInt8](data)
        guard bytes.count >= 132 else { throw ParseError.tooShort }
        guard Self.signature(bytes[36..<40]) == "acsp" else { throw ParseError.badSignature }
        let count = Self.u32(bytes, 128)
        guard count <= 1000, 132 + count * 12 <= bytes.count else { throw ParseError.badTagTable }
        var tags: [Tag] = []
        var blocks: [[UInt8]] = []
        var known: [String: Int] = [:]
        for index in 0..<count {
            let entry = 132 + index * 12
            let offset = Self.u32(bytes, entry + 4), size = Self.u32(bytes, entry + 8)
            guard offset >= 132 + count * 12, size >= 0, offset + size <= bytes.count else { throw ParseError.badTagTable }
            let key = "\(offset):\(size)"
            let block: Int
            if let existing = known[key] {
                block = existing
            } else {
                blocks.append(Array(bytes[offset..<offset + size]))
                block = blocks.count - 1
                known[key] = block
            }
            tags.append(Tag(signature: Self.signature(bytes[entry..<entry + 4]), block: block))
        }
        self.header = Array(bytes[0..<128])
        self.tags = tags
        self.blocks = blocks
    }

    /// 프로파일 종류 (머리 12-15). 디스플레이 프로파일은 "mntr".
    public var profileClass: String { Self.signature(header[12..<16]) }
    /// 장치 색 공간 (머리 16-19). 예: "RGB ".
    public var colorSpace: String { Self.signature(header[16..<20]) }

    public func block(for signature: String) -> [UInt8]? {
        tags.first { $0.signature == signature }.map { blocks[$0.block] }
    }

    /// 태그 자료 교체. 같은 자료를 공유하던 다른 태그에는 영향을 주지 않도록 새 자료로 분리. 태그가 없으면 추가.
    public mutating func setBlock(_ bytes: [UInt8], for signature: String) {
        blocks.append(bytes)
        if let index = tags.firstIndex(where: { $0.signature == signature }) {
            tags[index].block = blocks.count - 1
        } else {
            tags.append(Tag(signature: signature, block: blocks.count - 1))
        }
    }

    public mutating func removeTag(_ signature: String) {
        tags.removeAll { $0.signature == signature }
    }

    /// XYZ 형식 태그의 첫 값. 값은 s15Fixed16 (65536으로 나눈 값).
    public func xyz(_ signature: String) throws -> XYZ {
        guard let bytes = block(for: signature) else { throw ParseError.missingTag(signature) }
        guard bytes.count >= 20, Self.signature(bytes[0..<4]) == "XYZ " else { throw ParseError.wrongTagType(signature) }
        func value(_ offset: Int) -> Double { Double(Int32(bitPattern: UInt32(Self.u32(bytes, offset)))) / 65536 }
        return XYZ(x: value(8), y: value(12), z: value(16))
    }

    public mutating func setXYZ(_ value: XYZ, for signature: String) {
        func fixed(_ v: Double) -> [UInt8] { Self.be32(UInt32(bitPattern: Int32((v * 65536).rounded()))) }
        setBlock(Array("XYZ ".utf8) + [0, 0, 0, 0] + fixed(value.x) + fixed(value.y) + fixed(value.z), for: signature)
    }

    /// 프로파일 이름 지정: `desc`(ASCII)와 `dscm`(다국어, 시스템 목록에 표시되는 이름)을 새로 씀.
    public mutating func setDescription(ascii: String, localized: String) {
        let plain = Array(String(ascii.unicodeScalars.filter { $0.isASCII && $0.value >= 0x20 }).utf8) + [0]
        var desc = Array("desc".utf8) + [0, 0, 0, 0] + Self.be32(UInt32(plain.count)) + plain
        // 유니코드 언어 부호와 글자 수(0), 스크립트 부호(2)와 글자 수(1), 스크립트 문자열 영역(67).
        desc += [UInt8](repeating: 0, count: 4 + 4 + 2 + 1 + 67)
        setBlock(desc, for: "desc")
        var text: [UInt8] = []
        for unit in localized.utf16 { text += [UInt8(unit >> 8), UInt8(unit & 0xFF)] }
        let mluc = Array("mluc".utf8) + [0, 0, 0, 0] + Self.be32(1) + Self.be32(12) + Array("enUS".utf8) + Self.be32(UInt32(text.count)) + Self.be32(28) + text
        setBlock(mluc, for: "dscm")
    }

    /// 파일 형식으로 직렬화: 쓰이지 않는 자료는 제외하고 4바이트 경계로 맞춤. 머리의 크기를 갱신하고 프로파일 ID(84-99)를 비움.
    public func serialized() -> Data {
        var order: [Int] = []
        for tag in tags where !order.contains(tag.block) { order.append(tag.block) }
        var offsets: [Int: Int] = [:]
        var body: [UInt8] = []
        let start = 132 + tags.count * 12
        for block in order {
            offsets[block] = start + body.count
            body += blocks[block]
            while body.count % 4 != 0 { body.append(0) }
        }
        var table = Self.be32(UInt32(tags.count))
        for tag in tags {
            table += Array(tag.signature.utf8.prefix(4)) + Self.be32(UInt32(offsets[tag.block] ?? 0)) + Self.be32(UInt32(blocks[tag.block].count))
        }
        var head = header
        head.replaceSubrange(0..<4, with: Self.be32(UInt32(start + body.count)))
        head.replaceSubrange(84..<100, with: [UInt8](repeating: 0, count: 16))
        return Data(head + table + body)
    }
}
