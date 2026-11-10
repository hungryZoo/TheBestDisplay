import Foundation

/// EDID 해석 결과. (SRS-INF-002)
public struct EDID: Codable, Hashable, Sendable {
    public var byteCount: Int
    /// 해석 중 발견한 문제 (체크섬 오류, 길이 부족 등). 문제가 있어도 해석 가능한 부분은 채움.
    public var issues: [String] = []

    // 기본 블록
    public var manufacturerID: String = ""
    public var productCode: UInt16 = 0
    public var serialNumber: UInt32 = 0
    public var manufactureWeek: Int = 0
    public var manufactureYear: Int = 0
    public var version: String = ""
    public var isDigital: Bool = false
    /// 디지털 입력의 색상당 비트 수. 미정의 시 nil.
    public var bitsPerColor: Int?
    /// 디지털 인터페이스 종류 (DVI, HDMI-a, HDMI-b, MDDI, DisplayPort). 미정의 시 nil.
    public var digitalInterface: String?
    public var screenWidthCM: Int = 0
    public var screenHeightCM: Int = 0
    public var gamma: Double?
    public var chromaticity: Chromaticity?
    public var establishedTimings: [String] = []
    public var standardTimings: [StandardTiming] = []
    /// 기본 블록과 확장 블록의 상세 타이밍 전체.
    public var detailedTimings: [DetailedTiming] = []
    public var productName: String?
    public var serialString: String?
    public var rangeLimits: RangeLimits?
    public var declaredExtensionCount: Int = 0

    // 확장 블록
    public var cta: CTAExtension?
    public var displayID: DisplayIDExtension?
    /// 해석하지 않은 확장 블록의 태그.
    public var unknownExtensionTags: [UInt8] = []

    public init(byteCount: Int) { self.byteCount = byteCount }

    public struct Chromaticity: Codable, Hashable, Sendable {
        public var redX: Double, redY: Double
        public var greenX: Double, greenY: Double
        public var blueX: Double, blueY: Double
        public var whiteX: Double, whiteY: Double
    }

    public struct StandardTiming: Codable, Hashable, Sendable {
        public var width: Int
        public var height: Int
        public var refreshRate: Int
    }

    public struct DetailedTiming: Codable, Hashable, Sendable {
        public var pixelClockHz: Double
        public var hActive: Int, hBlank: Int, hFrontPorch: Int, hSyncWidth: Int
        public var vActive: Int, vBlank: Int, vFrontPorch: Int, vSyncWidth: Int
        public var interlaced: Bool
        /// 출처: base, cta, displayid
        public var source: String

        public var hTotal: Int { hActive + hBlank }
        public var vTotal: Int { vActive + vBlank }
        public var refreshRate: Double {
            let total = Double(hTotal * vTotal)
            guard total > 0 else { return 0 }
            return pixelClockHz / total * (interlaced ? 2 : 1)
        }
    }

    public struct RangeLimits: Codable, Hashable, Sendable {
        public var minVerticalHz: Int
        public var maxVerticalHz: Int
        public var minHorizontalKHz: Int
        public var maxHorizontalKHz: Int
        /// 0이면 미지정.
        public var maxPixelClockMHz: Int
    }

    public struct CTAExtension: Codable, Hashable, Sendable {
        public var revision: Int = 0
        public var supportsUnderscan = false
        public var supportsBasicAudio = false
        public var supportsYCbCr444 = false
        public var supportsYCbCr422 = false
        public var videoCodes: [VideoCode] = []
        /// YCbCr 4:2:0 전용 VIC (YCbCr 4:2:0 Video Data Block).
        public var ycbcr420OnlyVICs: [Int] = []
        /// 다른 인코딩과 함께 4:2:0도 지원하는 VIC (Capability Map).
        public var ycbcr420CapableVICs: [Int] = []
        public var audioFormats: [String] = []
        public var colorimetry: [String] = []
        public var hdr: HDRStaticMetadata?
        public var hdmi: HDMIVendorBlock?
        public var hdmiForum: HDMIForumBlock?
        public var videoCapability: VideoCapability?
        /// 해석한 데이터 블록의 이름 목록 (표시용).
        public var dataBlocks: [String] = []
    }

    public struct VideoCode: Codable, Hashable, Sendable {
        public var vic: Int
        public var isNative: Bool
        public var width: Int
        public var height: Int
        public var refreshRate: Int
        public var interlaced: Bool

        public var description: String {
            width > 0 ? "\(width)x\(height)\(interlaced ? "i" : "p") \(refreshRate) Hz" : "미등록 VIC"
        }
    }

    public struct HDRStaticMetadata: Codable, Hashable, Sendable {
        public var supportsSDRGamma = false
        public var supportsHDRGamma = false
        public var supportsPQ = false
        public var supportsHLG = false
        public var supportsStaticMetadataType1 = false
        /// cd/m². 미보고 시 nil.
        public var maxLuminance: Double?
        public var maxFrameAverageLuminance: Double?
        public var minLuminance: Double?

        public var eotfNames: [String] {
            var names: [String] = []
            if supportsSDRGamma { names.append("SDR") }
            if supportsHDRGamma { names.append("HDR 감마") }
            if supportsPQ { names.append("PQ (HDR10)") }
            if supportsHLG { names.append("HLG") }
            return names
        }
    }

    public struct HDMIVendorBlock: Codable, Hashable, Sendable {
        public var physicalAddress: String = ""
        public var supportsDeepColor30 = false
        public var supportsDeepColor36 = false
        public var supportsDeepColor48 = false
        public var supportsDeepColorYCbCr444 = false
        /// MHz. 미보고 시 nil.
        public var maxTMDSClockMHz: Int?
    }

    public struct HDMIForumBlock: Codable, Hashable, Sendable {
        public var version: Int = 0
        /// MHz. 0이면 340 MHz 이하.
        public var maxTMDSCharacterRateMHz: Int = 0
        public var supportsSCDC = false
        public var supportsScramblingBelow340 = false
        /// 0 미지원, 1 9 Gbps, 2 18, 3 24, 4 32, 5 40, 6 48.
        public var maxFRLRate: Int = 0
        public var deepColor420Bits: [Int] = []
        public var supportsALLM = false
        public var supportsFVA = false
        public var supportsQMS = false
        public var supportsCinemaVRR = false
        public var vrrMinHz: Int?
        public var vrrMaxHz: Int?
        public var supportsDSC12a = false
        public var supportsDSCNative420 = false
        public var dscBitsPerComponent: [Int] = []
        public var dscMaxFRLRate: Int = 0
        public var dscMaxSlices: Int = 0

        public static func frlGbps(_ rate: Int) -> Int {
            [0, 9, 18, 24, 32, 40, 48][safe: rate] ?? 0
        }

        public var maxFRLGbps: Int { Self.frlGbps(maxFRLRate) }
    }

    public struct VideoCapability: Codable, Hashable, Sendable {
        public var selectableRGBQuantization: Bool
        public var selectableYCCQuantization: Bool
    }

    public struct DisplayIDExtension: Codable, Hashable, Sendable {
        public var version: String = ""
        public var productType: Int = 0
        public var dataBlocks: [String] = []
        public var adaptiveSyncRanges: [AdaptiveSyncRange] = []
    }

    public struct AdaptiveSyncRange: Codable, Hashable, Sendable {
        public var minHz: Int
        public var maxHz: Int
    }
}

public extension EDID {
    /// IORegistry `EDID UUID`와 같은 형식의 대응 키. (SRS 3.2절)
    /// EDID 바이트 8-23을 UUID 형식으로 표기하고 일련번호 바이트 12-15를 0으로 채움.
    static func matchKey(from bytes: [UInt8]) -> String? {
        guard bytes.count >= 24 else { return nil }
        var b = Array(bytes[8..<24])
        for i in 4..<8 { b[i] = 0 }
        let hex = b.map { String(format: "%02X", $0) }
        return [hex[0..<4], hex[4..<6], hex[6..<8], hex[8..<10], hex[10..<16]].map { $0.joined() }.joined(separator: "-")
    }

    /// CoreGraphics 제조사 번호 형식 (바이트 8-9 빅엔디언).
    var vendorNumber: UInt32 {
        let chars = Array(manufacturerID.unicodeScalars)
        guard chars.count == 3 else { return 0 }
        return chars.reduce(UInt32(0)) { ($0 << 5) | (($1.value - 64) & 0x1F) }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
