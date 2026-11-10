import Foundation

/// EDID에서 도출한 싱크 능력 요약. (PRD-INF-004)
public struct SinkCapabilities: Codable, Hashable, Sendable {
    public var hdrFormats: [String]
    /// cd/m². EDID 미보고 시 nil.
    public var maxLuminance: Double?
    public var minLuminance: Double?
    public var colorimetry: [String]
    /// EDID가 선언한 최대 주사율 (상세 타이밍, VIC, 주사율 범위 중 최댓값).
    public var maxRefreshRate: Int?
    public var vrrMinHz: Int?
    public var vrrMaxHz: Int?
    /// VRR 범위의 출처: "HDMI Forum VSDB", "DisplayID Adaptive-Sync", "주사율 범위 서술자"
    public var vrrSource: String?
    public var maxTMDSMHz: Int?
    /// Gbps. FRL 미지원 또는 미보고 시 nil.
    public var maxFRLGbps: Int?
    /// EDID의 DSC 지원 선언. EDID에 근거 블록이 없으면 nil (미보고).
    public var supportsDSC: Bool?
    public var supportsALLM: Bool
    public var deepColorBits: [Int]
    public var supportsYCbCr444: Bool
    public var supportsYCbCr422: Bool
    public var supportsYCbCr420: Bool
    /// 원본 해상도로 간주하는 첫 상세 타이밍.
    public var preferredWidth: Int?
    public var preferredHeight: Int?
    public var preferredRefreshRate: Double?
}

public extension EDID {
    var sinkCapabilities: SinkCapabilities {
        let hf = cta?.hdmiForum
        let hdmi = cta?.hdmi

        var rates: [Int] = detailedTimings.map { Int($0.refreshRate.rounded()) }
        rates += cta?.videoCodes.map(\.refreshRate) ?? []
        if let limits = rangeLimits { rates.append(limits.maxVerticalHz) }

        var vrrMin: Int?, vrrMax: Int?, vrrSource: String?
        if let hf, let minHz = hf.vrrMinHz {
            // VRRmax 0은 해당 해상도의 최대 주사율까지 허용이라는 뜻.
            (vrrMin, vrrMax, vrrSource) = (minHz, hf.vrrMaxHz ?? rates.max(), "HDMI Forum VSDB")
        } else if let range = displayID?.adaptiveSyncRanges.first {
            (vrrMin, vrrMax, vrrSource) = (range.minHz, range.maxHz, "DisplayID Adaptive-Sync")
        }

        var deepColor: [Int] = []
        if hdmi?.supportsDeepColor30 == true { deepColor.append(10) }
        if hdmi?.supportsDeepColor36 == true { deepColor.append(12) }
        if hdmi?.supportsDeepColor48 == true { deepColor.append(16) }
        if deepColor.isEmpty, let bits = bitsPerColor, bits > 8 { deepColor = [bits] }

        let tmds = [hdmi?.maxTMDSClockMHz, hf.map(\.maxTMDSCharacterRateMHz)].compactMap { $0 }.filter { $0 > 0 }.max()
        let preferred = detailedTimings.first

        return SinkCapabilities(
            hdrFormats: cta?.hdr?.eotfNames.filter { $0 != "SDR" } ?? [],
            maxLuminance: cta?.hdr?.maxLuminance,
            minLuminance: cta?.hdr?.minLuminance,
            colorimetry: cta?.colorimetry ?? [],
            maxRefreshRate: rates.max(),
            vrrMinHz: vrrMin,
            vrrMaxHz: vrrMax,
            vrrSource: vrrSource,
            maxTMDSMHz: tmds,
            maxFRLGbps: hf.flatMap { $0.maxFRLRate > 0 ? $0.maxFRLGbps : nil },
            supportsDSC: hf.map(\.supportsDSC12a),
            supportsALLM: hf?.supportsALLM ?? false,
            deepColorBits: deepColor,
            supportsYCbCr444: cta?.supportsYCbCr444 ?? false,
            supportsYCbCr422: cta?.supportsYCbCr422 ?? false,
            supportsYCbCr420: !(cta?.ycbcr420OnlyVICs.isEmpty ?? true) || !(cta?.ycbcr420CapableVICs.isEmpty ?? true),
            preferredWidth: preferred?.hActive,
            preferredHeight: preferred?.vActive,
            preferredRefreshRate: preferred?.refreshRate
        )
    }
}
