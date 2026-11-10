import Foundation

/// EDID 편집 항목. 가상 EDID로 적용하여 시스템이 인식하는 싱크 능력을 바꿈. (PRD-EDO-002)
public enum EDIDPatch: Hashable, Sendable, Codable {
    /// HDMI Forum 블록의 DSC 선언 제거.
    case removeDSC
    /// HDR 정적 메타데이터, 동적 메타데이터, Dolby Vision, HDR10+ 블록 제거.
    case removeHDR
    /// YCbCr 4:4:4, 4:2:2, 4:2:0 선언 제거 (RGB 전용).
    case removeYCbCr
    /// YCbCr 4:2:0 비디오 블록, 능력 맵, 4:2:0 딥 컬러 선언 제거.
    case removeYCbCr420
    /// HDMI Forum 블록의 VRR 범위와 QMS, Cinema VRR 선언 제거.
    case removeVRR
    /// HDMI FRL 최대 속도 단계(0-6) 상한.
    case limitFRLRate(Int)
    /// HDMI TMDS 최대 문자 속도(MHz) 상한.
    case limitTMDSRate(Int)

    public var title: String {
        switch self {
        case .removeDSC: "DSC 선언 제거 (HDMI)"
        case .removeHDR: "HDR 선언 제거"
        case .removeYCbCr: "YCbCr 선언 제거 (RGB 전용)"
        case .removeYCbCr420: "YCbCr 4:2:0 선언 제거"
        case .removeVRR: "VRR 선언 제거 (HDMI)"
        case .limitFRLRate(let rate): "FRL 최대 속도 단계 \(rate) 이하로 제한"
        case .limitTMDSRate(let mhz): "TMDS 최대 속도 \(mhz) MHz 이하로 제한"
        }
    }

    /// 명령행 표기: `remove-dsc`, `remove-hdr`, `remove-ycbcr`, `remove-420`, `remove-vrr`, `limit-frl:<0-6>`, `limit-tmds:<MHz>`.
    public static func parse(_ text: String) -> EDIDPatch? {
        let lower = text.lowercased()
        switch lower {
        case "remove-dsc": return .removeDSC
        case "remove-hdr": return .removeHDR
        case "remove-ycbcr", "rgb-only": return .removeYCbCr
        case "remove-420", "remove-ycbcr420": return .removeYCbCr420
        case "remove-vrr": return .removeVRR
        default: break
        }
        let parts = lower.split(separator: ":").map(String.init)
        guard parts.count == 2, let value = Int(parts[1]) else { return nil }
        switch parts[0] {
        case "limit-frl": return (0...6).contains(value) ? .limitFRLRate(value) : nil
        case "limit-tmds": return (25...600).contains(value) ? .limitTMDSRate(value) : nil
        default: return nil
        }
    }

    /// 쉼표로 이은 목록 해석. 하나라도 해석하지 못하면 nil.
    public static func parseList(_ text: String) -> [EDIDPatch]? {
        let items = text.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let parsed = items.compactMap(parse)
        return parsed.count == items.count && !parsed.isEmpty ? parsed : nil
    }

    /// 매개변수가 없는 편집 항목. 화면의 선택 목록에 사용.
    public static let simpleCases: [EDIDPatch] = [.removeDSC, .removeHDR, .removeYCbCr, .removeYCbCr420, .removeVRR]
}

/// 편집 한 건의 결과.
public struct EDIDPatchResult: Hashable, Sendable, Codable {
    public var title: String
    /// 실제로 바뀐 내용. 비어 있으면 대상 선언이 없어 변경 없음.
    public var changes: [String]

    public var changed: Bool { !changes.isEmpty }
}

public enum EDIDEditError: Error, Equatable, LocalizedError {
    case invalid([String])
    /// 편집 결과가 블록 크기를 넘음.
    case overflow(String)

    public var errorDescription: String? {
        switch self {
        case .invalid(let issues): "EDID 검증 실패: " + issues.joined(separator: ", ")
        case .overflow(let detail): "EDID 블록 공간 부족: \(detail)"
        }
    }
}

/// EDID 검증과 편집. 순수 함수. (SRS-EDO-001)
public enum EDIDEditor {
    static let header: [UInt8] = [0x00, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x00]

    /// 구조 검증. 문제가 없으면 빈 배열.
    public static func validate(_ data: Data) -> [String] {
        let bytes = [UInt8](data)
        var issues: [String] = []
        guard bytes.count >= 128 else { return ["길이 \(bytes.count)바이트 (최소 128바이트)"] }
        if bytes.count % 128 != 0 { issues.append("길이 \(bytes.count)바이트가 128의 배수가 아님") }
        if Array(bytes[0..<8]) != header { issues.append("머리 8바이트 불일치") }
        let declared = Int(bytes[126]) + 1
        let actual = bytes.count / 128
        if declared != actual { issues.append("확장 블록 수 선언 \(declared - 1)개, 실제 \(actual - 1)개") }
        for index in 0..<actual {
            let block = Array(bytes[index * 128..<(index + 1) * 128])
            if !EDIDParser.checksumValid(block) { issues.append("블록 \(index) 체크섬 오류") }
        }
        return issues
    }

    /// 128바이트 블록의 체크섬 바이트 재계산.
    static func withChecksum(_ block: [UInt8]) -> [UInt8] {
        var block = block
        let sum = block[0..<127].reduce(0) { ($0 + Int($1)) & 0xFF }
        block[127] = UInt8((256 - sum) & 0xFF)
        return block
    }

    /// 편집 적용. 입력은 검증을 통과해야 하며 결과도 모든 블록의 체크섬을 다시 계산.
    public static func apply(_ patches: [EDIDPatch], to data: Data) throws -> (data: Data, results: [EDIDPatchResult]) {
        let issues = validate(data)
        guard issues.isEmpty else { throw EDIDEditError.invalid(issues) }
        let bytes = [UInt8](data)
        var blocks = stride(from: 0, to: bytes.count, by: 128).map { Array(bytes[$0..<$0 + 128]) }
        var results: [EDIDPatchResult] = []
        for patch in patches {
            var changes: [String] = []
            try apply(patch, to: &blocks, changes: &changes)
            results.append(EDIDPatchResult(title: patch.title, changes: changes))
        }
        let output = blocks.flatMap(withChecksum)
        return (Data(output), results)
    }

    // MARK: - CTA 확장 블록 모델

    /// CTA-861 확장 블록의 분해 표현. 데이터 블록을 넣고 빼면 상세 타이밍 시작 오프셋을 다시 계산.
    struct CTABlock {
        var header: [UInt8]
        /// 머리 바이트를 포함한 데이터 블록.
        var dataBlocks: [[UInt8]]
        /// 18바이트 서술자.
        var descriptors: [[UInt8]]

        init?(_ b: [UInt8]) {
            guard b.count == 128, b[0] == 0x02 else { return nil }
            header = Array(b[0..<4])
            dataBlocks = []
            descriptors = []
            let dtdOffset = Int(b[2])
            guard dtdOffset >= 4, dtdOffset <= 127 else { return }
            var position = 4
            while header[1] >= 3, position < dtdOffset {
                let length = Int(b[position] & 0x1F)
                guard position + 1 + length <= dtdOffset else { return nil }
                dataBlocks.append(Array(b[position...position + length]))
                position += 1 + length
            }
            for offset in stride(from: dtdOffset, through: 127 - 18, by: 18) {
                let d = Array(b[offset..<offset + 18])
                if d[0] == 0, d[1] == 0 { break }
                descriptors.append(d)
            }
        }

        static func tag(_ block: [UInt8]) -> Int { Int(block[0] >> 5) }
        static func extendedTag(_ block: [UInt8]) -> Int? { tag(block) == 7 && block.count > 1 ? Int(block[1]) : nil }

        static func isVendor(_ block: [UInt8], oui: [UInt8]) -> Bool {
            tag(block) == 3 && block.count >= 4 && Array(block[1...3]) == oui
        }

        /// HDMI Forum VSDB 또는 SCDB. 두 블록 모두 판 번호가 블록 오프셋 4에 위치.
        static func isHDMIForum(_ block: [UInt8]) -> Bool {
            isVendor(block, oui: [0xD8, 0x5D, 0xC4]) || extendedTag(block) == 0x79
        }

        static func isHDMI(_ block: [UInt8]) -> Bool { isVendor(block, oui: [0x03, 0x0C, 0x00]) }

        /// 여유 공간 (바이트).
        var freeBytes: Int { 127 - 4 - dataBlocks.reduce(0) { $0 + $1.count } - descriptors.count * 18 }

        func serialized() throws -> [UInt8] {
            guard freeBytes >= 0 else { throw EDIDEditError.overflow("CTA 확장 블록 \(-freeBytes)바이트 초과") }
            var out = header
            let dataLength = dataBlocks.reduce(0) { $0 + $1.count }
            // 데이터 블록과 서술자가 모두 없으면 오프셋 0, 아니면 데이터 블록 끝.
            out[2] = dataBlocks.isEmpty && descriptors.isEmpty ? 0 : UInt8(4 + dataLength)
            out += dataBlocks.flatMap { $0 }
            out += descriptors.flatMap { $0 }
            out += [UInt8](repeating: 0, count: 128 - out.count)
            return out
        }
    }

    // MARK: - 편집 구현

    static func apply(_ patch: EDIDPatch, to blocks: inout [[UInt8]], changes: inout [String]) throws {
        if patch == .removeYCbCr {
            // 기본 블록: EDID 1.4 디지털 입력의 기능 바이트(24) 비트 4-3이 YCbCr 지원.
            if blocks[0][19] >= 4, blocks[0][20] & 0x80 != 0, blocks[0][24] & 0x18 != 0 {
                blocks[0][24] &= ~0x18
                changes.append("기본 블록의 YCbCr 4:4:4, 4:2:2 선언 제거")
            }
        }
        for index in blocks.indices.dropFirst() where blocks[index][0] == 0x02 {
            guard var cta = CTABlock(blocks[index]) else { continue }
            switch patch {
            case .removeDSC:
                mutateHDMIForum(&cta, changes: &changes, label: "HDMI Forum 블록의 DSC 선언 제거") { block in
                    for i in 11...13 where i < block.count { block[i] = 0 }
                }
            case .removeHDR:
                let before = cta.dataBlocks.count
                cta.dataBlocks.removeAll { block in
                    guard let ext = CTABlock.extendedTag(block) else { return false }
                    if ext == 6 || ext == 7 { return true }
                    // 제조사 비디오 블록: Dolby Vision(00-D0-46), HDR10+(90-84-8B).
                    if ext == 1, block.count >= 5 {
                        let oui = Array(block[2...4])
                        return oui == [0x46, 0xD0, 0x00] || oui == [0x8B, 0x84, 0x90]
                    }
                    return false
                }
                if cta.dataBlocks.count != before { changes.append("HDR 관련 데이터 블록 \(before - cta.dataBlocks.count)개 제거") }
            case .removeYCbCr, .removeYCbCr420:
                if patch == .removeYCbCr {
                    if cta.header[1] >= 2, cta.header[3] & 0x30 != 0 {
                        cta.header[3] &= ~0x30
                        changes.append("CTA 확장의 YCbCr 4:4:4, 4:2:2 선언 제거")
                    }
                    for i in cta.dataBlocks.indices where CTABlock.isHDMI(cta.dataBlocks[i]) && cta.dataBlocks[i].count > 6 && cta.dataBlocks[i][6] & 0x08 != 0 {
                        cta.dataBlocks[i][6] &= ~0x08
                        changes.append("HDMI 블록의 YCbCr 4:4:4 딥 컬러 선언 제거")
                    }
                }
                let before = cta.dataBlocks.count
                cta.dataBlocks.removeAll { [14, 15].contains(CTABlock.extendedTag($0) ?? -1) }
                if cta.dataBlocks.count != before { changes.append("YCbCr 4:2:0 데이터 블록 \(before - cta.dataBlocks.count)개 제거") }
                mutateHDMIForum(&cta, changes: &changes, label: "HDMI Forum 블록의 4:2:0 딥 컬러 선언 제거") { block in
                    if block.count > 7 { block[7] &= ~0x07 }
                }
            case .removeVRR:
                mutateHDMIForum(&cta, changes: &changes, label: "HDMI Forum 블록의 VRR 선언 제거") { block in
                    if block.count > 8 { block[8] &= ~0x78 }
                    for i in 9...10 where i < block.count { block[i] = 0 }
                }
            case .limitFRLRate(let limit):
                mutateHDMIForum(&cta, changes: &changes, label: "FRL 최대 속도 단계를 \(limit) 이하로 제한") { block in
                    if block.count > 7, Int(block[7] >> 4) > limit { block[7] = UInt8(limit) << 4 | block[7] & 0x0F }
                    if block.count > 12, Int(block[12] >> 4) > limit { block[12] = UInt8(limit) << 4 | block[12] & 0x0F }
                }
            case .limitTMDSRate(let mhz):
                mutateHDMIForum(&cta, changes: &changes, label: "HDMI Forum 블록의 TMDS 최대 속도를 \(mhz) MHz 이하로 제한") { block in
                    if block.count > 5, Int(block[5]) * 5 > mhz { block[5] = UInt8(mhz / 5) }
                }
                for i in cta.dataBlocks.indices where CTABlock.isHDMI(cta.dataBlocks[i]) && cta.dataBlocks[i].count > 7 {
                    let limit = min(mhz, 340)
                    if Int(cta.dataBlocks[i][7]) * 5 > limit {
                        cta.dataBlocks[i][7] = UInt8(limit / 5)
                        changes.append("HDMI 블록의 TMDS 최대 클록을 \(limit) MHz 이하로 제한")
                    }
                }
            }
            blocks[index] = try cta.serialized()
        }
    }

    static func mutateHDMIForum(_ cta: inout CTABlock, changes: inout [String], label: String, _ body: (inout [UInt8]) -> Void) {
        for i in cta.dataBlocks.indices where CTABlock.isHDMIForum(cta.dataBlocks[i]) {
            let before = cta.dataBlocks[i]
            body(&cta.dataBlocks[i])
            if cta.dataBlocks[i] != before { changes.append(label) }
        }
    }
}

public extension SinkCapabilities {
    /// 편집 전후 비교에 쓰는 요약 행. (PRD-EDO-002)
    var comparisonRows: [(label: String, value: String)] {
        func yesNo(_ value: Bool) -> String { value ? "지원" : "미지원" }
        var ycbcr: [String] = []
        if supportsYCbCr444 { ycbcr.append("4:4:4") }
        if supportsYCbCr422 { ycbcr.append("4:2:2") }
        if supportsYCbCr420 { ycbcr.append("4:2:0") }
        return [
            ("선호 타이밍", preferredWidth.map { "\($0) x \(preferredHeight ?? 0), \(DisplaySummary.formatHz(preferredRefreshRate ?? 0)) Hz" } ?? "미보고"),
            ("최대 주사율", maxRefreshRate.map { "\($0) Hz" } ?? "미보고"),
            ("YCbCr", ycbcr.isEmpty ? "미지원 (RGB 전용)" : ycbcr.joined(separator: ", ")),
            ("HDR", hdrFormats.isEmpty ? "미지원" : hdrFormats.joined(separator: ", ")),
            ("DSC (EDID 선언)", supportsDSC.map(yesNo) ?? "미보고"),
            ("VRR", vrrMinHz.map { "\($0)-\(vrrMaxHz ?? 0) Hz" } ?? "미보고"),
            ("TMDS 최대", maxTMDSMHz.map { "\($0) MHz" } ?? "미보고"),
            ("FRL 최대", maxFRLGbps.map { "\($0) Gbps" } ?? "미보고"),
        ]
    }
}
