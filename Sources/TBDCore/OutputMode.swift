import Foundation

/// 윈도 서버의 출력 모드 1개 (링크 서술). (SRS-COL-011)
///
/// 16바이트 구조: 비트 심도, 범위, EOTF, 픽셀 인코딩 순서의 32비트 정수 4개 (리틀 엔디언).
/// 필드 순서와 값의 근거: spikes 문서 T73 (SkyLight 디스어셈블, 윈도 서버 설정 파일의 LinkDescription 항목 대조).
/// 픽셀 인코딩과 범위의 번호는 프레임버퍼 색 요소(`PixelEncoding`, `DynamicRange`)와 다름.
public struct LinkDescription: Codable, Hashable, Sendable {
    public var bitDepth: Int
    /// 1은 Full, 0은 Limited.
    public var range: Int
    /// 0은 SDR, 2는 PQ.
    public var eotf: Int
    /// 0 RGB, 1 YCbCr 4:4:4, 2 YCbCr 4:2:2, 3 YCbCr 4:2:0, 4 Dolby Vision, 6 Dolby Vision 저지연.
    public var pixelEncoding: Int

    public static let byteCount = 16

    public init(bitDepth: Int, range: Int, eotf: Int, pixelEncoding: Int) {
        self.bitDepth = bitDepth
        self.range = range
        self.eotf = eotf
        self.pixelEncoding = pixelEncoding
    }

    /// 16바이트 해석. 길이가 모자라면 nil.
    public static func decode(_ bytes: some Collection<UInt8>) -> LinkDescription? {
        let b = Array(bytes)
        guard b.count >= byteCount else { return nil }
        func field(_ index: Int) -> Int {
            let o = index * 4
            return Int(Int32(bitPattern: UInt32(b[o]) | UInt32(b[o + 1]) << 8 | UInt32(b[o + 2]) << 16 | UInt32(b[o + 3]) << 24))
        }
        return LinkDescription(bitDepth: field(0), range: field(1), eotf: field(2), pixelEncoding: field(3))
    }

    /// 연속한 16바이트 묶음 해석.
    public static func decodeList(_ bytes: [UInt8], count: Int) -> [LinkDescription] {
        (0..<max(0, count)).compactMap { index in
            let start = index * byteCount
            guard start + byteCount <= bytes.count else { return nil }
            return decode(bytes[start..<start + byteCount])
        }
    }

    /// 구조체를 값으로 넘길 때의 64비트 레지스터 2개 (arm64 호출 규약): 앞 8바이트와 뒤 8바이트.
    public var registers: (first: UInt64, second: UInt64) {
        func word(_ low: Int, _ high: Int) -> UInt64 {
            UInt64(UInt32(truncatingIfNeeded: low)) | UInt64(UInt32(truncatingIfNeeded: high)) << 32
        }
        return (word(bitDepth, range), word(eotf, pixelEncoding))
    }

    /// 프레임버퍼 색 요소 쪽 픽셀 인코딩. Dolby Vision 계열은 대응 없음.
    public var framebufferEncoding: PixelEncoding? {
        switch pixelEncoding {
        case 0: .rgb444
        case 1: .ycbcr444
        case 2: .ycbcr422
        case 3: .ycbcr420
        default: nil
        }
    }

    /// 색 모드 서술. 색 공간은 출력 모드에 없어 nil. Dolby Vision 계열은 nil.
    public var colorDescriptor: ColorDescriptor? {
        guard let encoding = framebufferEncoding else { return nil }
        return ColorDescriptor(pixelEncoding: encoding, bitsPerComponent: bitDepth, eotf: EOTF(rawValue: eotf), dynamicRange: range == 1 ? .full : .limited)
    }

    /// 색 모드 서술에 대응하는 링크 서술. 터널링 계열 인코딩은 nil.
    public init?(_ descriptor: ColorDescriptor) {
        let encoding: Int
        switch descriptor.pixelEncoding {
        case .rgb444: encoding = 0
        case .ycbcr444: encoding = 1
        case .ycbcr422: encoding = 2
        case .ycbcr420: encoding = 3
        default: return nil
        }
        self.init(bitDepth: descriptor.bitsPerComponent, range: descriptor.dynamicRange == .full ? 1 : 0, eotf: descriptor.eotf.rawValue, pixelEncoding: encoding)
    }

    /// 예: "YCbCr 4:2:2, 10 bpc, Limited, PQ (HDR10)"
    public var label: String {
        let encoding: String
        switch pixelEncoding {
        case 4: encoding = "Dolby Vision"
        case 6: encoding = "Dolby Vision 저지연"
        default: encoding = framebufferEncoding?.name ?? "알 수 없음 (\(pixelEncoding))"
        }
        return "\(encoding), \(bitDepth) bpc, \(range == 1 ? "Full" : "Limited"), \(EOTF(rawValue: eotf).name)"
    }
}

/// 디스플레이 1대의 현재 모드에서 시스템이 제공하는 출력 모드 목록. (PRD-COL-010)
public struct OutputModeList: Codable, Hashable, Sendable {
    public var modes: [LinkDescription]
    public var currentIndex: Int?

    public init(modes: [LinkDescription], currentIndex: Int?) {
        self.modes = modes
        self.currentIndex = currentIndex.flatMap { modes.indices.contains($0) ? $0 : nil }
    }

    public var current: LinkDescription? { currentIndex.map { modes[$0] } }

    /// 색 모드 서술과 일치하는 출력 모드. 색 공간은 비교하지 않음.
    public func mode(matching descriptor: ColorDescriptor) -> LinkDescription? {
        guard let wanted = LinkDescription(descriptor) else { return nil }
        return modes.first { $0 == wanted }
    }

    public func offers(_ element: ColorElement) -> Bool { mode(matching: element.descriptor) != nil }

    /// 제공 목록 요약. 예: "RGB 4:4:4, 8 bpc, Full, SDR / YCbCr 4:4:4, 8 bpc, Limited, SDR"
    public var summary: String { modes.map(\.label).joined(separator: " / ") }
}
