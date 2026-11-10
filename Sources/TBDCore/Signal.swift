import Foundation

// 출력 신호 형식 모델. 열거값은 IOKit의 문자열 함수로 확인한 값. (spikes 문서 2.2절)

public struct PixelEncoding: RawRepresentable, Codable, Hashable, Sendable {
    public var rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let rgb444 = PixelEncoding(rawValue: 0)
    public static let ycbcr420 = PixelEncoding(rawValue: 1)
    public static let ycbcr422 = PixelEncoding(rawValue: 2)
    public static let ycbcr444 = PixelEncoding(rawValue: 3)

    public var name: String {
        switch rawValue {
        case 0: "RGB 4:4:4"
        case 1: "YCbCr 4:2:0"
        case 2: "YCbCr 4:2:2"
        case 3: "YCbCr 4:4:4"
        case 4: "Dolby Vision (네이티브)"
        case 5: "Dolby Vision (HDMI 터널링)"
        case 6: "YCbCr 4:2:2 (DP 터널링)"
        case 7: "YCbCr 4:2:2 (HDMI 터널링)"
        case 8: "Dolby Vision LL YCbCr 4:2:2"
        case 9: "Dolby Vision LL YCbCr 4:2:2 (DP 터널링)"
        default: "알 수 없음 (\(rawValue))"
        }
    }

    public var isRGB: Bool { rawValue == 0 }

    /// 색상 성분당 비트 수에 곱해 픽셀당 비트 수를 얻는 계수. (SRS 3.3절)
    /// RGB와 4:4:4는 3, 4:2:2는 2, 4:2:0은 1.5. Dolby Vision 터널링은 RGB 8 bpc 컨테이너 기준으로 3.
    public var componentsPerPixel: Double {
        switch rawValue {
        case 1: 1.5
        case 2, 6, 7, 8, 9: 2
        default: 3
        }
    }

    /// 명령행 지정용 짧은 이름.
    public var shortName: String {
        switch rawValue {
        case 0: "rgb"
        case 1: "ycbcr420"
        case 2: "ycbcr422"
        case 3: "ycbcr444"
        default: "enc\(rawValue)"
        }
    }
}

public struct EOTF: RawRepresentable, Codable, Hashable, Sendable {
    public var rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let sdr = EOTF(rawValue: 0)
    public static let hdrGamma = EOTF(rawValue: 1)
    public static let pq = EOTF(rawValue: 2)
    public static let hlg = EOTF(rawValue: 3)

    public var name: String {
        switch rawValue {
        case 0: "SDR"
        case 1: "HDR 감마"
        case 2: "PQ (HDR10)"
        case 3: "HLG"
        default: "알 수 없음 (\(rawValue))"
        }
    }

    public var isHDR: Bool { rawValue != 0 }

    public var shortName: String {
        switch rawValue {
        case 0: "sdr"
        case 1: "hdrgamma"
        case 2: "pq"
        case 3: "hlg"
        default: "eotf\(rawValue)"
        }
    }
}

public struct DynamicRange: RawRepresentable, Codable, Hashable, Sendable {
    public var rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let full = DynamicRange(rawValue: 0)
    public static let limited = DynamicRange(rawValue: 1)

    public var name: String {
        switch rawValue {
        case 0: "Full"
        case 1: "Limited"
        default: "알 수 없음 (\(rawValue))"
        }
    }

    public var shortName: String { rawValue == 0 ? "full" : rawValue == 1 ? "limited" : "range\(rawValue)" }
}

public enum Colorimetry {
    public static func name(_ value: Int) -> String {
        let names = ["BT.601", "BT.709", "xvYCC601", "xvYCC709", "sYCC601", "AdobeYCC601", "BT.2020 (YcCbcCrc)", "BT.2020 (YCbCr)", "Dolby Vision VSVDB", "BT.2020 (RGB)", "sRGB", "scRGB", "scRGBfixed", "AdobeRGB", "DCI-P3 (D65)", "DCI-P3 (Theater)", "기본 RGB"]
        return names[safe: value] ?? "알 수 없음 (\(value))"
    }
}

/// 색 모드 1개 (프레임버퍼 노드의 색 요소). (PRD-COL-002)
public struct ColorElement: Codable, Hashable, Sendable, Identifiable {
    public var id: Int
    public var pixelEncoding: PixelEncoding
    public var bitsPerComponent: Int
    public var eotf: EOTF
    public var dynamicRange: DynamicRange
    public var colorimetry: Int
    /// 이 색 요소가 DSC 전송을 지원하는지 (싱크 능력).
    public var supportsDSC: Bool
    /// 프레임버퍼 쪽 가상 형식. 실제 링크 형식이 아님.
    public var isVirtual: Bool
    public var score: Int?

    public init(id: Int, pixelEncoding: PixelEncoding, bitsPerComponent: Int, eotf: EOTF, dynamicRange: DynamicRange, colorimetry: Int, supportsDSC: Bool = false, isVirtual: Bool = false, score: Int? = nil) {
        self.id = id
        self.pixelEncoding = pixelEncoding
        self.bitsPerComponent = bitsPerComponent
        self.eotf = eotf
        self.dynamicRange = dynamicRange
        self.colorimetry = colorimetry
        self.supportsDSC = supportsDSC
        self.isVirtual = isVirtual
        self.score = score
    }

    public var bitsPerPixel: Double { Double(bitsPerComponent) * pixelEncoding.componentsPerPixel }

    /// 예: "RGB 4:4:4, 10 bpc, Full, SDR"
    public var label: String {
        "\(pixelEncoding.name), \(bitsPerComponent) bpc, \(dynamicRange.name), \(eotf.name)"
    }

    public var descriptor: ColorDescriptor {
        ColorDescriptor(pixelEncoding: pixelEncoding, bitsPerComponent: bitsPerComponent, eotf: eotf, dynamicRange: dynamicRange, colorimetry: colorimetry)
    }
}

/// 색 요소 ID에 의존하지 않는 색 모드 식별. 재연결 후 ID가 바뀌어도 복귀와 프로파일 복원에 사용.
public struct ColorDescriptor: Codable, Hashable, Sendable {
    public var pixelEncoding: PixelEncoding
    public var bitsPerComponent: Int
    public var eotf: EOTF
    public var dynamicRange: DynamicRange
    /// nil이면 색 공간 무관.
    public var colorimetry: Int?

    public init(pixelEncoding: PixelEncoding, bitsPerComponent: Int, eotf: EOTF, dynamicRange: DynamicRange, colorimetry: Int? = nil) {
        self.pixelEncoding = pixelEncoding
        self.bitsPerComponent = bitsPerComponent
        self.eotf = eotf
        self.dynamicRange = dynamicRange
        self.colorimetry = colorimetry
    }

    /// 목록에서 일치하는 색 요소. 색 공간까지 같은 것을 우선하고, 없으면 나머지 항목이 같은 것 중 점수가 높은 것.
    public func find(in elements: [ColorElement]) -> ColorElement? {
        let base = elements.filter { !$0.isVirtual && $0.pixelEncoding == pixelEncoding && $0.bitsPerComponent == bitsPerComponent && $0.eotf == eotf && $0.dynamicRange == dynamicRange }
        if let colorimetry, let exact = base.first(where: { $0.colorimetry == colorimetry }) { return exact }
        return base.max { ($0.score ?? 0) < ($1.score ?? 0) }
    }

    public var label: String {
        "\(pixelEncoding.name), \(bitsPerComponent) bpc, \(dynamicRange.name), \(eotf.name)"
    }
}

/// 싱크 타이밍 1개 (프레임버퍼 노드의 타이밍 요소). (PRD-COL-005)
public struct TimingElement: Codable, Hashable, Sendable, Identifiable {
    public var id: Int
    public var hActive: Int, hTotal: Int, hFrontPorch: Int, hSyncWidth: Int, hBackPorch: Int
    public var vActive: Int, vTotal: Int, vFrontPorch: Int, vSyncWidth: Int, vBackPorch: Int
    public var refreshRate: Double
    public var isInterlaced: Bool
    public var isPreferred: Bool
    public var isVirtual: Bool
    /// 이 타이밍에서 선택 가능한 색 모드.
    public var colorModes: [ColorElement]
    /// 이 타이밍에서 DSC가 필요한 색 요소 ID.
    public var dscRequiredColorElementIDs: [Int]
    public var unsafeColorElementIDs: [Int]
    public var minVariableRefreshRate: Double
    public var maxVariableRefreshRate: Double

    /// 픽셀 클록 (Hz) = 총 수평 픽셀 x 총 수직 라인 x 주사율. 인터레이스는 필드 기준이므로 절반.
    public var pixelClockHz: Double {
        Double(hTotal) * Double(vTotal) * refreshRate / (isInterlaced ? 2 : 1)
    }

    public var label: String {
        "\(hActive) x \(vActive)\(isInterlaced ? "i" : ""), \(DisplaySummary.formatHz(refreshRate)) Hz"
    }

    public func requiresDSC(_ colorID: Int) -> Bool {
        dscRequiredColorElementIDs.contains(colorID)
    }
}

/// 프레임버퍼 노드 속성 사전을 모델로 변환. (SRS-COL-001)
public enum SignalDecoder {
    static func int(_ value: Any?) -> Int? {
        (value as? NSNumber)?.intValue
    }

    static func bool(_ value: Any?) -> Bool {
        (value as? NSNumber)?.boolValue ?? false
    }

    static func intArray(_ value: Any?) -> [Int] {
        (value as? [Any])?.compactMap { int($0) } ?? []
    }

    public static func colorElement(_ dict: [String: Any]) -> ColorElement? {
        guard let id = int(dict["ID"]), let encoding = int(dict["PixelEncoding"]), let depth = int(dict["Depth"]) else { return nil }
        return ColorElement(
            id: id,
            pixelEncoding: PixelEncoding(rawValue: encoding),
            bitsPerComponent: depth,
            eotf: EOTF(rawValue: int(dict["EOTF"]) ?? 0),
            dynamicRange: DynamicRange(rawValue: int(dict["DynamicRange"]) ?? 0),
            colorimetry: int(dict["Colorimetry"]) ?? -1,
            supportsDSC: bool(dict["SupportsDSC"]),
            isVirtual: bool(dict["IsVirtual"]),
            score: int(dict["Score"])
        )
    }

    public static func colorElements(_ value: Any?) -> [ColorElement] {
        (value as? [[String: Any]])?.compactMap(colorElement) ?? []
    }

    public static func timingElement(_ dict: [String: Any]) -> TimingElement? {
        guard let id = int(dict["ID"]),
              let h = dict["HorizontalAttributes"] as? [String: Any],
              let v = dict["VerticalAttributes"] as? [String: Any],
              let hActive = int(h["Active"]), let vActive = int(v["Active"])
        else { return nil }
        // 수직 동기 주파수: 16.16 고정소수점. 정밀값이 0이면 일반값 사용.
        let precise = int(v["PreciseSyncRate"]) ?? 0
        let rate = Double(precise != 0 ? precise : (int(v["SyncRate"]) ?? 0)) / 65536
        return TimingElement(
            id: id,
            hActive: hActive, hTotal: int(h["Total"]) ?? 0, hFrontPorch: int(h["FrontPorch"]) ?? 0, hSyncWidth: int(h["SyncWidth"]) ?? 0, hBackPorch: int(h["BackPorch"]) ?? 0,
            vActive: vActive, vTotal: int(v["Total"]) ?? 0, vFrontPorch: int(v["FrontPorch"]) ?? 0, vSyncWidth: int(v["SyncWidth"]) ?? 0, vBackPorch: int(v["BackPorch"]) ?? 0,
            refreshRate: rate,
            isInterlaced: bool(dict["IsInterlaced"]),
            isPreferred: bool(dict["IsPreferred"]),
            isVirtual: bool(dict["IsVirtual"]),
            colorModes: colorElements(dict["ColorModes"]),
            dscRequiredColorElementIDs: intArray(dict["DSCRequiredColorElementIDs"]),
            unsafeColorElementIDs: intArray(dict["UnsafeColorElementIDs"]),
            minVariableRefreshRate: Double(int(dict["MinimumVariableRefreshRate"]) ?? 0) / 65536,
            maxVariableRefreshRate: Double(int(dict["MaximumVariableRefreshRate"]) ?? 0) / 65536
        )
    }

    public static func timingElements(_ value: Any?) -> [TimingElement] {
        (value as? [[String: Any]])?.compactMap(timingElement) ?? []
    }
}

/// 실제 송출 중인 비디오 링크 데이터. `IOAVServiceGetLinkData`의 0x110바이트 구조체 해석. (SRS-COL-002, spikes 문서 2.1절)
public struct VideoLinkData: Codable, Hashable, Sendable {
    public static let byteCount = 0x110

    public var bitsPerComponent: Int
    public var pixelEncoding: PixelEncoding
    public var dynamicRange: DynamicRange
    public var colorimetry: Int
    public var eotf: EOTF
    public var hTotal: Int, hActive: Int, hSyncWidth: Int, hBackPorch: Int, hFrontPorch: Int
    public var vTotal: Int, vActive: Int, vSyncWidth: Int, vBackPorch: Int, vFrontPorch: Int
    public var refreshRate: Double
    public var pixelClockHz: Double

    public static func decode(_ bytes: [UInt8]) -> VideoLinkData? {
        guard bytes.count >= byteCount else { return nil }
        func u32(_ offset: Int) -> Int {
            Int(UInt32(bytes[offset]) | UInt32(bytes[offset + 1]) << 8 | UInt32(bytes[offset + 2]) << 16 | UInt32(bytes[offset + 3]) << 24)
        }
        let hActive = u32(0x40), vActive = u32(0x60)
        guard hActive > 0, vActive > 0 else { return nil }
        return VideoLinkData(
            bitsPerComponent: u32(0x18),
            pixelEncoding: PixelEncoding(rawValue: u32(0x1C)),
            dynamicRange: DynamicRange(rawValue: u32(0x20)),
            colorimetry: u32(0x24),
            eotf: EOTF(rawValue: u32(0x28)),
            hTotal: u32(0x3C), hActive: hActive, hSyncWidth: u32(0x44), hBackPorch: u32(0x48), hFrontPorch: u32(0x4C),
            vTotal: u32(0x5C), vActive: vActive, vSyncWidth: u32(0x64), vBackPorch: u32(0x68), vFrontPorch: u32(0x6C),
            refreshRate: Double(u32(0x70)) / 65536,
            pixelClockHz: Double(u32(0x7C))
        )
    }

    public var bitsPerPixel: Double { Double(bitsPerComponent) * pixelEncoding.componentsPerPixel }

    public var colorLabel: String {
        "\(pixelEncoding.name), \(bitsPerComponent) bpc, \(dynamicRange.name), \(eotf.name)"
    }

    public var descriptor: ColorDescriptor {
        ColorDescriptor(pixelEncoding: pixelEncoding, bitsPerComponent: bitsPerComponent, eotf: eotf, dynamicRange: dynamicRange, colorimetry: colorimetry)
    }
}

/// 디스플레이 1대의 신호 상태. (PRD-COL-001-005)
public struct SignalInfo: Codable, Hashable, Sendable {
    public var displayID: UInt32
    public var timings: [TimingElement]
    /// 싱크가 선언한 색 요소 전체 (타이밍과 무관).
    public var sinkColorElements: [ColorElement]
    public var currentTimingID: Int?
    public var currentColorID: Int?
    public var linkData: VideoLinkData?
    /// 프레임버퍼 노드의 전송 방식 표기. 예: "DP"
    public var transport: String?

    public init(displayID: UInt32, timings: [TimingElement], sinkColorElements: [ColorElement], currentTimingID: Int?, currentColorID: Int?, linkData: VideoLinkData?, transport: String?) {
        self.displayID = displayID
        self.timings = timings
        self.sinkColorElements = sinkColorElements
        self.currentTimingID = currentTimingID
        self.currentColorID = currentColorID
        self.linkData = linkData
        self.transport = transport
    }

    public var currentTiming: TimingElement? {
        currentTimingID.flatMap { id in timings.first { $0.id == id } }
    }

    /// 현재 타이밍에서 선택 가능한 색 모드. 가상 형식 제외.
    public var selectableColorModes: [ColorElement] {
        (currentTiming?.colorModes ?? []).filter { !$0.isVirtual }
    }

    public var currentColor: ColorElement? {
        guard let id = currentColorID else { return nil }
        return currentTiming?.colorModes.first { $0.id == id } ?? sinkColorElements.first { $0.id == id }
    }
}

/// 명령행의 색 모드 지정. 형식: `id:<번호>` 또는 `<인코딩>[:<bpc>][:<full|limited>][:<sdr|pq|hlg>]`.
public enum ColorSpec: Equatable, Sendable {
    case id(Int)
    case partial(encoding: PixelEncoding, bitsPerComponent: Int?, dynamicRange: DynamicRange?, eotf: EOTF?)

    public static func parse(_ text: String) -> ColorSpec? {
        let lower = text.lowercased()
        if lower.hasPrefix("id:") { return Int(lower.dropFirst(3)).map { .id($0) } }
        let parts = lower.split(separator: ":").map(String.init)
        guard let first = parts.first else { return nil }
        let encodings: [String: PixelEncoding] = ["rgb": .rgb444, "ycbcr444": .ycbcr444, "ycbcr422": .ycbcr422, "ycbcr420": .ycbcr420, "444": .ycbcr444, "422": .ycbcr422, "420": .ycbcr420]
        guard let encoding = encodings[first] else { return nil }
        var bpc: Int?, range: DynamicRange?, eotf: EOTF?
        for part in parts.dropFirst() {
            switch part {
            case "full": range = .full
            case "limited": range = .limited
            case "sdr": eotf = .sdr
            case "pq", "hdr10", "hdr": eotf = .pq
            case "hlg": eotf = .hlg
            default:
                guard let value = Int(part), [6, 8, 10, 12, 16].contains(value) else { return nil }
                bpc = value
            }
        }
        return .partial(encoding: encoding, bitsPerComponent: bpc, dynamicRange: range, eotf: eotf)
    }

    /// 지정과 일치하는 색 모드. 생략 항목은 현재 값 우선, 그다음 점수가 높은 것.
    public func resolve(in elements: [ColorElement], current: ColorElement?) -> ColorElement? {
        switch self {
        case .id(let id):
            return elements.first { $0.id == id }
        case .partial(let encoding, let bpc, let range, let eotf):
            var candidates = elements.filter { !$0.isVirtual && $0.pixelEncoding == encoding }
            if let bpc { candidates = candidates.filter { $0.bitsPerComponent == bpc } }
            if let range { candidates = candidates.filter { $0.dynamicRange == range } }
            if let eotf { candidates = candidates.filter { $0.eotf == eotf } }
            return candidates.max { a, b in
                func score(_ e: ColorElement) -> (Int, Int, Int, Int) {
                    (
                        eotf == nil && e.eotf == current?.eotf ? 1 : 0,
                        bpc == nil && e.bitsPerComponent == current?.bitsPerComponent ? 1 : 0,
                        range == nil && e.dynamicRange == current?.dynamicRange ? 1 : 0,
                        e.score ?? 0
                    )
                }
                return score(a) < score(b)
            }
        }
    }
}
