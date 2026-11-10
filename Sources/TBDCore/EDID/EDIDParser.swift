import Foundation

/// EDID 바이트열 해석기. 손상 입력에서도 충돌 없이 부분 결과와 문제 목록 반환. (SRS-INF-002)
public enum EDIDParser {
    static let header: [UInt8] = [0x00, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x00]

    public static func parse(_ data: Data) -> EDID { parse([UInt8](data)) }

    public static func parse(_ bytes: [UInt8]) -> EDID {
        var edid = EDID(byteCount: bytes.count)
        guard bytes.count >= 128 else {
            edid.issues.append("길이 부족: \(bytes.count)바이트 (최소 128바이트)")
            return edid
        }
        if bytes.count % 128 != 0 {
            edid.issues.append("길이가 128의 배수가 아님: \(bytes.count)바이트")
        }
        let base = Array(bytes[0..<128])
        if Array(base[0..<8]) != header {
            edid.issues.append("머리 바이트 불일치")
        }
        if !checksumValid(base) {
            edid.issues.append("기본 블록 체크섬 오류")
        }
        parseBase(base, into: &edid)

        let available = bytes.count / 128 - 1
        if edid.declaredExtensionCount > available {
            edid.issues.append("확장 블록 수 불일치: 선언 \(edid.declaredExtensionCount)개, 수신 \(available)개")
        }
        for index in 0..<min(available, max(edid.declaredExtensionCount, available)) {
            let start = (index + 1) * 128
            let block = Array(bytes[start..<start + 128])
            if block.allSatisfy({ $0 == 0 }) { continue }
            if !checksumValid(block) {
                edid.issues.append("확장 블록 \(index + 1) 체크섬 오류")
            }
            switch block[0] {
            case 0x02: parseCTA(block, into: &edid)
            case 0x70: parseDisplayID(block, into: &edid)
            default: edid.unknownExtensionTags.append(block[0])
            }
        }
        return edid
    }

    static func checksumValid(_ block: [UInt8]) -> Bool {
        block.reduce(0) { $0 &+ $1 } == 0
    }

    // MARK: - 기본 블록

    static func parseBase(_ b: [UInt8], into edid: inout EDID) {
        let m = UInt16(b[8]) << 8 | UInt16(b[9])
        let letters = [(m >> 10) & 0x1F, (m >> 5) & 0x1F, m & 0x1F]
        if letters.allSatisfy({ (1...26).contains($0) }) {
            edid.manufacturerID = String(letters.map { Character(UnicodeScalar(UInt8($0) + 64)) })
        }
        edid.productCode = UInt16(b[10]) | UInt16(b[11]) << 8
        edid.serialNumber = UInt32(b[12]) | UInt32(b[13]) << 8 | UInt32(b[14]) << 16 | UInt32(b[15]) << 24
        edid.manufactureWeek = Int(b[16])
        edid.manufactureYear = Int(b[17]) + 1990
        edid.version = "\(b[18]).\(b[19])"

        edid.isDigital = b[20] & 0x80 != 0
        if edid.isDigital, b[19] >= 4 {
            edid.bitsPerColor = [nil, 6, 8, 10, 12, 14, 16, nil][Int((b[20] >> 4) & 0x7)]
            edid.digitalInterface = [nil, "DVI", "HDMI-a", "HDMI-b", "MDDI", "DisplayPort"][safe: Int(b[20] & 0xF)] ?? nil
        }
        edid.screenWidthCM = Int(b[21])
        edid.screenHeightCM = Int(b[22])
        if b[23] != 0xFF { edid.gamma = (Double(b[23]) + 100) / 100 }

        func chroma(_ high: UInt8, _ lowByte: UInt8, _ shift: UInt8) -> Double {
            Double(Int(high) << 2 | Int((lowByte >> shift) & 0x3)) / 1024
        }
        edid.chromaticity = EDID.Chromaticity(
            redX: chroma(b[27], b[25], 6), redY: chroma(b[28], b[25], 4),
            greenX: chroma(b[29], b[25], 2), greenY: chroma(b[30], b[25], 0),
            blueX: chroma(b[31], b[26], 6), blueY: chroma(b[32], b[26], 4),
            whiteX: chroma(b[33], b[26], 2), whiteY: chroma(b[34], b[26], 0)
        )

        let established: [(Int, UInt8, String)] = [
            (35, 0x80, "720x400 70 Hz"), (35, 0x40, "720x400 88 Hz"), (35, 0x20, "640x480 60 Hz"), (35, 0x10, "640x480 67 Hz"),
            (35, 0x08, "640x480 72 Hz"), (35, 0x04, "640x480 75 Hz"), (35, 0x02, "800x600 56 Hz"), (35, 0x01, "800x600 60 Hz"),
            (36, 0x80, "800x600 72 Hz"), (36, 0x40, "800x600 75 Hz"), (36, 0x20, "832x624 75 Hz"), (36, 0x10, "1024x768i 87 Hz"),
            (36, 0x08, "1024x768 60 Hz"), (36, 0x04, "1024x768 70 Hz"), (36, 0x02, "1024x768 75 Hz"), (36, 0x01, "1280x1024 75 Hz"),
            (37, 0x80, "1152x870 75 Hz"),
        ]
        edid.establishedTimings = established.filter { b[$0.0] & $0.1 != 0 }.map(\.2)

        for i in stride(from: 38, to: 54, by: 2) where !(b[i] == 0x01 && b[i + 1] == 0x01) && b[i] != 0 {
            let width = (Int(b[i]) + 31) * 8
            let ratio = b[i + 1] >> 6
            let height: Int
            switch ratio {
            case 0: height = b[19] >= 3 ? width * 10 / 16 : width
            case 1: height = width * 3 / 4
            case 2: height = width * 4 / 5
            default: height = width * 9 / 16
            }
            edid.standardTimings.append(.init(width: width, height: height, refreshRate: Int(b[i + 1] & 0x3F) + 60))
        }

        for offset in stride(from: 54, to: 126, by: 18) {
            parseDescriptor(Array(b[offset..<offset + 18]), source: "base", into: &edid)
        }
        edid.declaredExtensionCount = Int(b[126])
    }

    /// 18바이트 서술자: 상세 타이밍 또는 표시 서술자.
    static func parseDescriptor(_ d: [UInt8], source: String, into edid: inout EDID) {
        if d[0] != 0 || d[1] != 0 {
            if let timing = detailedTiming(d, source: source) { edid.detailedTimings.append(timing) }
            return
        }
        guard source == "base" else { return }
        switch d[3] {
        case 0xFC: edid.productName = descriptorText(d)
        case 0xFF: edid.serialString = descriptorText(d)
        case 0xFD:
            var minV = Int(d[5]), maxV = Int(d[6]), minH = Int(d[7]), maxH = Int(d[8])
            // EDID 1.4: 바이트 4의 오프셋 플래그로 255 초과 표현.
            if d[4] & 0x02 != 0 { maxV += 255 }
            if d[4] & 0x03 == 0x03 { minV += 255 }
            if d[4] & 0x08 != 0 { maxH += 255 }
            if d[4] & 0x0C == 0x0C { minH += 255 }
            edid.rangeLimits = .init(minVerticalHz: minV, maxVerticalHz: maxV, minHorizontalKHz: minH, maxHorizontalKHz: maxH, maxPixelClockMHz: d[9] == 0xFF ? 0 : Int(d[9]) * 10)
        default: break
        }
    }

    static func descriptorText(_ d: [UInt8]) -> String {
        let raw = d[5..<18].prefix { $0 != 0x0A }
        return String(decoding: raw, as: UTF8.self).trimmingCharacters(in: .whitespaces)
    }

    static func detailedTiming(_ d: [UInt8], source: String) -> EDID.DetailedTiming? {
        let clock = Double(Int(d[0]) | Int(d[1]) << 8) * 10_000
        let hActive = Int(d[2]) | Int(d[4] & 0xF0) << 4
        let hBlank = Int(d[3]) | Int(d[4] & 0x0F) << 8
        let vActive = Int(d[5]) | Int(d[7] & 0xF0) << 4
        let vBlank = Int(d[6]) | Int(d[7] & 0x0F) << 8
        guard clock > 0, hActive > 0, vActive > 0 else { return nil }
        return .init(
            pixelClockHz: clock,
            hActive: hActive, hBlank: hBlank,
            hFrontPorch: Int(d[8]) | Int(d[11] & 0xC0) << 2,
            hSyncWidth: Int(d[9]) | Int(d[11] & 0x30) << 4,
            vActive: vActive, vBlank: vBlank,
            vFrontPorch: Int(d[10] >> 4) | Int(d[11] & 0x0C) << 2,
            vSyncWidth: Int(d[10] & 0x0F) | Int(d[11] & 0x03) << 4,
            interlaced: d[17] & 0x80 != 0,
            source: source
        )
    }

    // MARK: - CTA-861 확장

    static func parseCTA(_ b: [UInt8], into edid: inout EDID) {
        var cta = edid.cta ?? EDID.CTAExtension()
        cta.revision = Int(b[1])
        let dtdOffset = Int(b[2])
        if cta.revision >= 2 {
            cta.supportsUnderscan = b[3] & 0x80 != 0
            cta.supportsBasicAudio = b[3] & 0x40 != 0
            cta.supportsYCbCr444 = b[3] & 0x20 != 0
            cta.supportsYCbCr422 = b[3] & 0x10 != 0
        }
        // 데이터 블록 영역: 바이트 4부터 dtdOffset 직전까지. dtdOffset이 0이면 상세 타이밍과 데이터 블록 모두 없음.
        let dataEnd = dtdOffset == 0 ? 4 : min(max(dtdOffset, 4), 127)
        var svdOrder: [Int] = []
        var capabilityMap: [UInt8]?
        var position = 4
        while cta.revision >= 3, position < dataEnd {
            let tag = Int(b[position] >> 5)
            let length = Int(b[position] & 0x1F)
            let start = position + 1
            guard start + length <= dataEnd else {
                edid.issues.append("CTA 데이터 블록 길이 초과 (오프셋 \(position))")
                break
            }
            let payload = Array(b[start..<start + length])
            position = start + length
            switch tag {
            case 1:
                cta.dataBlocks.append("오디오")
                cta.audioFormats += audioFormats(payload)
            case 2:
                cta.dataBlocks.append("비디오")
                for byte in payload {
                    let code = videoCode(svd: byte)
                    cta.videoCodes.append(code)
                    svdOrder.append(code.vic)
                }
            case 3:
                parseVendorBlock(payload, into: &cta)
            case 4:
                cta.dataBlocks.append("스피커 배치")
            case 7:
                guard let extendedTag = payload.first else { break }
                let body = Array(payload.dropFirst())
                switch extendedTag {
                case 0:
                    cta.dataBlocks.append("비디오 능력")
                    if let flags = body.first {
                        cta.videoCapability = .init(selectableRGBQuantization: flags & 0x40 != 0, selectableYCCQuantization: flags & 0x80 != 0)
                    }
                case 5:
                    cta.dataBlocks.append("색 공간")
                    cta.colorimetry = colorimetry(body)
                case 6:
                    cta.dataBlocks.append("HDR 정적 메타데이터")
                    cta.hdr = hdrStatic(body)
                case 14:
                    cta.dataBlocks.append("YCbCr 4:2:0 비디오")
                    cta.ycbcr420OnlyVICs += body.map { videoCode(svd: $0).vic }
                case 15:
                    cta.dataBlocks.append("YCbCr 4:2:0 능력 맵")
                    capabilityMap = body
                case 0x79:
                    cta.dataBlocks.append("HDMI Forum SCDB")
                    // SCDB: 예약 2바이트 뒤로 HF-VSDB의 판 번호 이후와 같은 배치.
                    if body.count >= 2 { cta.hdmiForum = hdmiForum(Array(body.dropFirst(2))) }
                default:
                    cta.dataBlocks.append("확장 태그 \(extendedTag)")
                }
            default:
                cta.dataBlocks.append("태그 \(tag)")
            }
        }
        if let map = capabilityMap {
            // 맵이 비어 있으면 전 SVD가 4:2:0 지원. 아니면 비트 순서대로 SVD에 대응.
            if map.isEmpty {
                cta.ycbcr420CapableVICs = svdOrder
            } else {
                for (index, vic) in svdOrder.enumerated() where index / 8 < map.count && map[index / 8] & (1 << UInt8(index % 8)) != 0 {
                    cta.ycbcr420CapableVICs.append(vic)
                }
            }
        }
        if dtdOffset >= 4 {
            for offset in stride(from: dtdOffset, through: 127 - 18, by: 18) {
                let d = Array(b[offset..<offset + 18])
                if d[0] == 0, d[1] == 0 { break }
                parseDescriptor(d, source: "cta", into: &edid)
            }
        }
        edid.cta = cta
    }

    static func videoCode(svd: UInt8) -> EDID.VideoCode {
        // 1-64는 비트 7이 네이티브 표시. 129-192는 네이티브인 1-64. 193 이상은 그대로 VIC.
        let vic: Int
        let native: Bool
        if (129...192).contains(svd) {
            vic = Int(svd & 0x7F)
            native = true
        } else {
            vic = Int(svd)
            native = false
        }
        let format = VICTable.format(vic)
        return .init(vic: vic, isNative: native, width: format?.width ?? 0, height: format?.height ?? 0, refreshRate: format?.refreshRate ?? 0, interlaced: format?.interlaced ?? false)
    }

    static func audioFormats(_ payload: [UInt8]) -> [String] {
        let names = [1: "LPCM", 2: "AC-3", 3: "MPEG-1", 4: "MP3", 5: "MPEG-2", 6: "AAC LC", 7: "DTS", 8: "ATRAC", 9: "DSD", 10: "E-AC-3", 11: "DTS-HD", 12: "MLP (TrueHD)", 13: "DST", 14: "WMA Pro"]
        return stride(from: 0, to: payload.count - 2, by: 3).map { i in
            let code = Int((payload[i] >> 3) & 0xF)
            return "\(names[code] ?? "형식 \(code)") \(Int(payload[i] & 0x7) + 1)채널"
        }
    }

    static func colorimetry(_ body: [UInt8]) -> [String] {
        guard let first = body.first else { return [] }
        let names = ["xvYCC601", "xvYCC709", "sYCC601", "opYCC601", "opRGB", "BT.2020 cYCC", "BT.2020 YCC", "BT.2020 RGB"]
        var result = names.enumerated().filter { first & (1 << UInt8($0.offset)) != 0 }.map(\.element)
        if body.count > 1, body[1] & 0x80 != 0 { result.append("DCI-P3") }
        return result
    }

    static func hdrStatic(_ body: [UInt8]) -> EDID.HDRStaticMetadata {
        var hdr = EDID.HDRStaticMetadata()
        guard body.count >= 2 else { return hdr }
        hdr.supportsSDRGamma = body[0] & 0x01 != 0
        hdr.supportsHDRGamma = body[0] & 0x02 != 0
        hdr.supportsPQ = body[0] & 0x04 != 0
        hdr.supportsHLG = body[0] & 0x08 != 0
        hdr.supportsStaticMetadataType1 = body[1] & 0x01 != 0
        // 휘도 부호값: 최대 = 50 x 2^(CV/32), 최소 = 최대 x (CV/255)^2 / 100
        if body.count > 2, body[2] != 0 { hdr.maxLuminance = 50 * pow(2, Double(body[2]) / 32) }
        if body.count > 3, body[3] != 0 { hdr.maxFrameAverageLuminance = 50 * pow(2, Double(body[3]) / 32) }
        if body.count > 4, let max = hdr.maxLuminance { hdr.minLuminance = max * pow(Double(body[4]) / 255, 2) / 100 }
        return hdr
    }

    static func parseVendorBlock(_ payload: [UInt8], into cta: inout EDID.CTAExtension) {
        guard payload.count >= 3 else { return }
        let oui = UInt32(payload[0]) | UInt32(payload[1]) << 8 | UInt32(payload[2]) << 16
        switch oui {
        case 0x000C03:
            cta.dataBlocks.append("HDMI VSDB")
            var hdmi = EDID.HDMIVendorBlock()
            if payload.count >= 5 {
                hdmi.physicalAddress = "\(payload[3] >> 4).\(payload[3] & 0xF).\(payload[4] >> 4).\(payload[4] & 0xF)"
            }
            if payload.count >= 6 {
                hdmi.supportsDeepColor48 = payload[5] & 0x40 != 0
                hdmi.supportsDeepColor36 = payload[5] & 0x20 != 0
                hdmi.supportsDeepColor30 = payload[5] & 0x10 != 0
                hdmi.supportsDeepColorYCbCr444 = payload[5] & 0x08 != 0
            }
            if payload.count >= 7, payload[6] != 0 { hdmi.maxTMDSClockMHz = Int(payload[6]) * 5 }
            cta.hdmi = hdmi
        case 0xC45DD8:
            cta.dataBlocks.append("HDMI Forum VSDB")
            cta.hdmiForum = hdmiForum(Array(payload.dropFirst(3)))
        default:
            cta.dataBlocks.append(String(format: "제조사 블록 %06X", oui))
        }
    }

    /// HF-VSDB의 OUI 다음 바이트(판 번호)부터의 배치.
    static func hdmiForum(_ x: [UInt8]) -> EDID.HDMIForumBlock {
        var hf = EDID.HDMIForumBlock()
        guard x.count >= 4 else { return hf }
        hf.version = Int(x[0])
        hf.maxTMDSCharacterRateMHz = Int(x[1]) * 5
        hf.supportsSCDC = x[2] & 0x80 != 0
        hf.supportsScramblingBelow340 = x[2] & 0x08 != 0
        hf.maxFRLRate = Int(x[3] >> 4)
        hf.deepColor420Bits = [(UInt8(0x01), 10), (0x02, 12), (0x04, 16)].filter { x[3] & $0.0 != 0 }.map(\.1)
        guard x.count >= 5 else { return hf }
        hf.supportsQMS = x[4] & 0x40 != 0
        hf.supportsCinemaVRR = x[4] & 0x10 != 0
        hf.supportsFVA = x[4] & 0x04 != 0
        hf.supportsALLM = x[4] & 0x02 != 0
        guard x.count >= 7 else { return hf }
        let vrrMin = Int(x[5] & 0x3F)
        let vrrMax = Int(x[5] & 0xC0) << 2 | Int(x[6])
        if vrrMin > 0 { hf.vrrMinHz = vrrMin }
        if vrrMax > 0 { hf.vrrMaxHz = vrrMax }
        guard x.count >= 9 else { return hf }
        hf.supportsDSC12a = x[7] & 0x80 != 0
        hf.supportsDSCNative420 = x[7] & 0x40 != 0
        hf.dscBitsPerComponent = [(UInt8(0x01), 10), (0x02, 12), (0x04, 16)].filter { x[7] & $0.0 != 0 }.map(\.1)
        hf.dscMaxSlices = [0, 1, 2, 4, 8, 8, 12, 16][safe: Int(x[8] & 0x0F)] ?? 0
        hf.dscMaxFRLRate = Int(x[8] >> 4)
        return hf
    }

    // MARK: - DisplayID 확장

    static func parseDisplayID(_ b: [UInt8], into edid: inout EDID) {
        var did = edid.displayID ?? EDID.DisplayIDExtension()
        did.version = "\(b[1] >> 4).\(b[1] & 0xF)"
        let sectionLength = Int(b[2])
        did.productType = Int(b[3])
        let isV2 = b[1] >= 0x20
        // 구역: 머리 5바이트(태그 포함) 뒤 sectionLength바이트.
        let end = min(5 + sectionLength, 126)
        var position = 5
        while position + 3 <= end {
            let tag = b[position]
            let length = Int(b[position + 2])
            if tag == 0, length == 0 { break }
            let start = position + 3
            guard start + length <= end else {
                edid.issues.append("DisplayID 데이터 블록 길이 초과 (오프셋 \(position))")
                break
            }
            let payload = Array(b[start..<start + length])
            position = start + length
            switch (isV2, tag) {
            case (false, 0x03), (true, 0x22):
                // Type I(1.x)과 Type VII(2.x) 상세 타이밍: 20바이트 단위, 같은 배치. 픽셀 클록 단위는 10 kHz(1.x)와 1 kHz(2.x).
                did.dataBlocks.append(isV2 ? "Type VII 상세 타이밍" : "Type I 상세 타이밍")
                for offset in stride(from: 0, through: payload.count - 20, by: 20) {
                    if let t = displayIDTiming(Array(payload[offset..<offset + 20]), clockUnitHz: isV2 ? 1_000 : 10_000) {
                        edid.detailedTimings.append(t)
                    }
                }
            case (true, 0x2B):
                did.dataBlocks.append("Adaptive-Sync")
                // 서술자 크기: 블록 판 번호 바이트의 비트 4-6 + 6.
                let size = Int((b[position - length - 2] >> 4) & 0x7) + 6
                for offset in stride(from: 0, through: payload.count - size, by: size) where size >= 6 {
                    let d = Array(payload[offset..<offset + size])
                    let maxHz = Int(d[3]) | Int(d[4] & 0x3) << 8
                    did.adaptiveSyncRanges.append(.init(minHz: Int(d[2]), maxHz: maxHz))
                }
            case (true, 0x21): did.dataBlocks.append("디스플레이 매개변수")
            case (true, 0x26): did.dataBlocks.append("디스플레이 인터페이스 기능")
            case (true, 0x20), (false, 0x00): did.dataBlocks.append("제품 식별")
            case (false, 0x01): did.dataBlocks.append("디스플레이 매개변수")
            case (false, 0x09): did.dataBlocks.append("주사율 범위")
            case (false, 0x12), (true, 0x28):
                did.dataBlocks.append("타일 배치")
                did.tiledTopology = tiledTopology(payload)
            case (_, 0x81): did.dataBlocks.append("CTA 데이터 블록")
            case (_, 0x7E), (_, 0x7F): did.dataBlocks.append("제조사 블록")
            default: did.dataBlocks.append(String(format: "태그 0x%02X", tag))
            }
        }
        edid.displayID = did
    }

    /// 타일 배치 블록 본문: 능력 1바이트, 배치 3바이트, 타일 크기 4바이트, 베젤 5바이트, 묶음 식별자.
    /// 배치 바이트: [0] 상위 4비트 가로 타일 수 - 1, 하위 4비트 세로 타일 수 - 1. [1] 상위 가로 위치, 하위 세로 위치.
    /// [2] 비트 7-6 가로 타일 수 상위, 5-4 세로 타일 수 상위, 3-2 가로 위치 상위, 1-0 세로 위치 상위.
    static func tiledTopology(_ p: [UInt8]) -> EDID.TiledTopology? {
        guard p.count >= 8 else { return nil }
        let topo = Array(p[1...3]), size = Array(p[4...7])
        let hTiles = Int(topo[0] >> 4) | Int((topo[2] >> 6) & 0x3) << 4
        let vTiles = Int(topo[0] & 0xF) | Int((topo[2] >> 4) & 0x3) << 4
        let hLocation = Int(topo[1] >> 4) | Int((topo[2] >> 2) & 0x3) << 4
        let vLocation = Int(topo[1] & 0xF) | Int(topo[2] & 0x3) << 4
        let idBytes = p.count > 13 ? Array(p[13...]) : []
        return EDID.TiledTopology(
            horizontalTiles: hTiles + 1, verticalTiles: vTiles + 1,
            horizontalLocation: hLocation, verticalLocation: vLocation,
            tileWidth: (Int(size[0]) | Int(size[1]) << 8) + 1, tileHeight: (Int(size[2]) | Int(size[3]) << 8) + 1,
            singleEnclosure: p[0] & 0x80 != 0,
            topologyID: idBytes.map { String(format: "%02X", $0) }.joined()
        )
    }

    static func displayIDTiming(_ d: [UInt8], clockUnitHz: Double) -> EDID.DetailedTiming? {
        func field(_ i: Int) -> Int { Int(d[i]) | Int(d[i + 1] & 0x7F) << 8 }
        let clock = Double((Int(d[0]) | Int(d[1]) << 8 | Int(d[2]) << 16) + 1) * clockUnitHz
        let hActive = (Int(d[4]) | Int(d[5]) << 8) + 1
        let vActive = (Int(d[12]) | Int(d[13]) << 8) + 1
        guard hActive > 1, vActive > 1 else { return nil }
        return .init(
            pixelClockHz: clock,
            hActive: hActive, hBlank: (Int(d[6]) | Int(d[7]) << 8) + 1,
            hFrontPorch: field(8) + 1, hSyncWidth: field(10) + 1,
            vActive: vActive, vBlank: (Int(d[14]) | Int(d[15]) << 8) + 1,
            vFrontPorch: field(16) + 1, vSyncWidth: field(18) + 1,
            interlaced: d[3] & 0x10 != 0,
            source: "displayid"
        )
    }
}

/// CTA-861 VIC 형식 표.
public enum VICTable {
    public struct Format: Sendable {
        public var width: Int
        public var height: Int
        public var refreshRate: Int
        public var interlaced: Bool
    }

    public static func format(_ vic: Int) -> Format? {
        func f(_ w: Int, _ h: Int, _ r: Int, _ i: Bool = false) -> Format { Format(width: w, height: h, refreshRate: r, interlaced: i) }
        func pick(_ rates: [Int], from first: Int, _ w: Int, _ h: Int) -> Format? {
            rates[safe: vic - first].map { f(w, h, $0) }
        }
        switch vic {
        case 1: return f(640, 480, 60)
        case 2, 3: return f(720, 480, 60)
        case 4: return f(1280, 720, 60)
        case 5: return f(1920, 1080, 60, true)
        case 6, 7: return f(1440, 480, 60, true)
        case 8, 9: return f(1440, 240, 60)
        case 10, 11: return f(2880, 480, 60, true)
        case 12, 13: return f(2880, 240, 60)
        case 14, 15: return f(1440, 480, 60)
        case 16: return f(1920, 1080, 60)
        case 17, 18: return f(720, 576, 50)
        case 19: return f(1280, 720, 50)
        case 20: return f(1920, 1080, 50, true)
        case 21, 22: return f(1440, 576, 50, true)
        case 23, 24: return f(1440, 288, 50)
        case 25, 26: return f(2880, 576, 50, true)
        case 27, 28: return f(2880, 288, 50)
        case 29, 30: return f(1440, 576, 50)
        case 31: return f(1920, 1080, 50)
        case 32: return f(1920, 1080, 24)
        case 33: return f(1920, 1080, 25)
        case 34: return f(1920, 1080, 30)
        case 35, 36: return f(2880, 480, 60)
        case 37, 38: return f(2880, 576, 50)
        case 39: return f(1920, 1080, 50, true)
        case 40: return f(1920, 1080, 100, true)
        case 41: return f(1280, 720, 100)
        case 42, 43: return f(720, 576, 100)
        case 44, 45: return f(1440, 576, 100, true)
        case 46: return f(1920, 1080, 120, true)
        case 47: return f(1280, 720, 120)
        case 48, 49: return f(720, 480, 120)
        case 50, 51: return f(1440, 480, 120, true)
        case 52, 53: return f(720, 576, 200)
        case 54, 55: return f(1440, 576, 200, true)
        case 56, 57: return f(720, 480, 240)
        case 58, 59: return f(1440, 480, 240, true)
        case 60: return f(1280, 720, 24)
        case 61: return f(1280, 720, 25)
        case 62: return f(1280, 720, 30)
        case 63: return f(1920, 1080, 120)
        case 64: return f(1920, 1080, 100)
        case 65...71: return pick([24, 25, 30, 50, 60, 100, 120], from: 65, 1280, 720)
        case 72...78: return pick([24, 25, 30, 50, 60, 100, 120], from: 72, 1920, 1080)
        case 79...85: return pick([24, 25, 30, 50, 60, 100, 120], from: 79, 1680, 720)
        case 86...92: return pick([24, 25, 30, 50, 60, 100, 120], from: 86, 2560, 1080)
        case 93...97: return pick([24, 25, 30, 50, 60], from: 93, 3840, 2160)
        case 98...102: return pick([24, 25, 30, 50, 60], from: 98, 4096, 2160)
        case 103...107: return pick([24, 25, 30, 50, 60], from: 103, 3840, 2160)
        case 108, 109: return f(1280, 720, 48)
        case 110: return f(1680, 720, 48)
        case 111, 112: return f(1920, 1080, 48)
        case 113: return f(2560, 1080, 48)
        case 114, 116: return f(3840, 2160, 48)
        case 115: return f(4096, 2160, 48)
        case 117, 119: return f(3840, 2160, 100)
        case 118, 120: return f(3840, 2160, 120)
        case 121...127: return pick([24, 25, 30, 48, 50, 60, 100], from: 121, 5120, 2160)
        case 193: return f(5120, 2160, 120)
        case 194...201: return pick([24, 25, 30, 48, 50, 60, 100, 120], from: 194, 7680, 4320)
        case 202...209: return pick([24, 25, 30, 48, 50, 60, 100, 120], from: 202, 7680, 4320)
        case 210...217: return pick([24, 25, 30, 48, 50, 60, 100, 120], from: 210, 10240, 4320)
        case 218: return f(4096, 2160, 100)
        case 219: return f(4096, 2160, 120)
        default: return nil
        }
    }
}
