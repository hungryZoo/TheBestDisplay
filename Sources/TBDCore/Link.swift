import Foundation

/// 포트의 DisplayPort 전송 상태 1건. `IOPortTransportStateDisplayPort` 노드 속성에서 구성. (SRS-LNK-001)
public struct DPTransportState: Codable, Hashable, Sendable {
    /// 경로 문자열. 예: "Port-USB-C@4/CIO/DisplayPort@0"
    public var transportDescription: String
    public var isActive: Bool
    /// 레인당 신호 속도 (Gbps). 링크 없음이면 nil.
    public var laneRateGbps: Double?
    /// 예: "8.1 Gbps (HBR3)", "No Link"
    public var linkRateDescription: String
    public var laneCount: Int
    public var maxLaneCount: Int
    public var isTunneled: Bool
    /// 0 미감지, 그 외 감지 (실측: High 상태는 2).
    public var hpdState: Int
    public var hpdDescription: String
    public var sinkCount: Int
    public var parentPortType: String
    public var parentPortNumber: Int
    public var productName: String?
    public var manufacturerName: String?
    public var productID: UInt32?
    public var serialNumber: UInt32?
    public var edid: Data?
    /// 하류 포트 종류. 예: "DP", "HDMI". 변환기 경유 판별에 사용.
    public var downstreamPortType: String?
    public var driverStatus: String?

    public init(transportDescription: String, isActive: Bool, laneRateGbps: Double?, linkRateDescription: String, laneCount: Int, maxLaneCount: Int, isTunneled: Bool, hpdState: Int, hpdDescription: String, sinkCount: Int, parentPortType: String, parentPortNumber: Int, productName: String? = nil, manufacturerName: String? = nil, productID: UInt32? = nil, serialNumber: UInt32? = nil, edid: Data? = nil, downstreamPortType: String? = nil, driverStatus: String? = nil) {
        self.transportDescription = transportDescription
        self.isActive = isActive
        self.laneRateGbps = laneRateGbps
        self.linkRateDescription = linkRateDescription
        self.laneCount = laneCount
        self.maxLaneCount = maxLaneCount
        self.isTunneled = isTunneled
        self.hpdState = hpdState
        self.hpdDescription = hpdDescription
        self.sinkCount = sinkCount
        self.parentPortType = parentPortType
        self.parentPortNumber = parentPortNumber
        self.productName = productName
        self.manufacturerName = manufacturerName
        self.productID = productID
        self.serialNumber = serialNumber
        self.edid = edid
        self.downstreamPortType = downstreamPortType
        self.driverStatus = driverStatus
    }

    public var hpdAsserted: Bool { hpdState != 0 && hpdDescription.lowercased() != "low" && hpdDescription.lowercased() != "unknown" }
    public var hasLink: Bool { laneCount > 0 && (laneRateGbps ?? 0) > 0 }

    /// 링크 속도 이름. 예: "HBR3"
    public var rateName: String? {
        laneRateGbps.map(Self.rateName)
    }

    public static func rateName(_ gbps: Double) -> String {
        let table: [(Double, String)] = [(1.62, "RBR"), (2.7, "HBR"), (5.4, "HBR2"), (8.1, "HBR3"), (10, "UHBR10"), (13.5, "UHBR13.5"), (20, "UHBR20")]
        return table.first { abs($0.0 - gbps) < 0.05 }?.1 ?? String(format: "%.2f Gbps", gbps)
    }

    public static func decode(_ node: [String: Any]) -> DPTransportState? {
        guard let description = node["TransportDescription"] as? String else { return nil }
        func int(_ key: String) -> Int { (node[key] as? NSNumber)?.intValue ?? 0 }
        func bool(_ key: String) -> Bool { (node[key] as? NSNumber)?.boolValue ?? false }
        let metadata = node["Metadata"] as? [String: Any] ?? [:]
        var rate: Double?
        if let nominal = (node["NominalSignalingFrequenciesHz"] as? [NSNumber])?.first?.doubleValue, nominal > 0 {
            rate = nominal / 1e9
        } else if let text = node["LinkRateDescription"] as? String, let value = Double(text.split(separator: " ").first ?? ""), value > 0 {
            rate = value
        }
        return DPTransportState(
            transportDescription: description,
            isActive: bool("Active"),
            laneRateGbps: rate,
            linkRateDescription: node["LinkRateDescription"] as? String ?? "",
            laneCount: int("LaneCount"),
            maxLaneCount: int("MaxLaneCount"),
            isTunneled: bool("Tunneled"),
            hpdState: int("HPD_State"),
            hpdDescription: node["HPD_StateDescription"] as? String ?? "",
            sinkCount: int("SinkCount"),
            parentPortType: node["ParentPortTypeDescription"] as? String ?? "",
            parentPortNumber: int("ParentPortNumber"),
            productName: node["ProductName"] as? String,
            manufacturerName: node["ManufacturerName"] as? String,
            productID: (node["ProductID"] as? NSNumber)?.uint32Value,
            serialNumber: (node["SerialNumber"] as? NSNumber)?.uint32Value,
            edid: (node["EDID"] as? Data) ?? (metadata["EDID"] as? Data),
            downstreamPortType: metadata["DFP Type Description"] as? String,
            driverStatus: node["DriverStatusDescription"] as? String
        )
    }

    /// 디스플레이 식별 정보와 대응 여부: 제품 코드와 일련번호, 없으면 EDID 머리.
    public func matches(_ identity: DisplayIdentity) -> Bool {
        if let productID, productID == identity.productID {
            if serialNumber == nil || serialNumber == identity.serialNumber { return true }
        }
        if let edid, edid.count >= 128 {
            let parsed = EDIDParser.parse(edid)
            return parsed.vendorNumber == identity.vendorID && UInt32(parsed.productCode) == identity.productID
        }
        return false
    }
}

/// 대역폭 계산. (SRS-LNK-002, SRS 3.3절)
public enum BandwidthCalculator {
    /// 필요 대역폭 (Gbps) = 픽셀 클록 x 픽셀당 비트 수.
    public static func requiredGbps(pixelClockHz: Double, bitsPerPixel: Double) -> Double {
        pixelClockHz * bitsPerPixel / 1e9
    }

    public static func requiredGbps(pixelClockHz: Double, encoding: PixelEncoding, bitsPerComponent: Int) -> Double {
        requiredGbps(pixelClockHz: pixelClockHz, bitsPerPixel: Double(bitsPerComponent) * encoding.componentsPerPixel)
    }

    /// DP 채널 부호화 효율. 레인당 10 Gbps 이상(UHBR)은 128b/132b, 그 미만은 8b/10b.
    public static func dpEncodingEfficiency(laneRateGbps: Double) -> Double {
        laneRateGbps >= 10 ? 128.0 / 132.0 : 0.8
    }

    public static func dpEncodingName(laneRateGbps: Double) -> String {
        laneRateGbps >= 10 ? "128b/132b" : "8b/10b"
    }

    /// DP 유효 대역폭 (Gbps) = 레인당 속도 x 레인 수 x 부호화 효율.
    public static func dpAvailableGbps(laneRateGbps: Double, laneCount: Int) -> Double {
        laneRateGbps * Double(laneCount) * dpEncodingEfficiency(laneRateGbps: laneRateGbps)
    }

    /// HDMI TMDS 유효 대역폭 (Gbps) = 문자 속도 x 3채널 x 8/10.
    public static func tmdsAvailableGbps(characterRateMHz: Double) -> Double {
        characterRateMHz * 1e6 * 3 * 10 * 0.8 / 1e9
    }

    /// HDMI FRL 유효 대역폭 (Gbps) = 총 속도 x 16/18.
    public static func frlAvailableGbps(totalGbps: Double) -> Double {
        totalGbps * 16 / 18
    }

    /// HDMI TMDS 문자 속도 (MHz). RGB와 4:4:4는 픽셀 클록 x bpc/8, 4:2:2는 픽셀 클록(12 bpc 컨테이너 고정), 4:2:0은 픽셀 클록 x bpc/16.
    public static func tmdsCharacterRateMHz(pixelClockHz: Double, encoding: PixelEncoding, bitsPerComponent: Int) -> Double {
        let mhz = pixelClockHz / 1e6
        switch encoding.componentsPerPixel {
        case 1.5: return mhz * Double(bitsPerComponent) / 16
        case 2: return mhz
        default: return mhz * Double(bitsPerComponent) / 8
        }
    }
}

/// 디스플레이 1대의 링크와 대역폭 요약. (PRD-LNK-001-004)
public struct LinkReport: Codable, Hashable, Sendable {
    public var displayID: UInt32
    /// "DisplayPort", "HDMI", "내장 패널 (eDP)"
    public var transportName: String
    public var state: DPTransportState?
    /// 링크 원시 대역폭 (Gbps) = 레인당 속도 x 레인 수.
    public var rawGbps: Double?
    public var availableGbps: Double?
    public var encodingName: String?
    /// 현재 모드 필요 대역폭 (Gbps). 압축 전 기준.
    public var requiredGbps: Double?
    public var dscActive: Bool?
    public var fecEnabled: Bool?
    /// 현재 타이밍에서 색 모드별 필요 대역폭과 수용 여부.
    public var colorModeBudgets: [ColorModeBudget]
    public var notes: [String]

    public var utilization: Double? {
        guard let requiredGbps, let availableGbps, availableGbps > 0 else { return nil }
        return requiredGbps / availableGbps
    }

    public init(displayID: UInt32, transportName: String, state: DPTransportState?, rawGbps: Double?, availableGbps: Double?, encodingName: String?, requiredGbps: Double?, dscActive: Bool?, fecEnabled: Bool?, colorModeBudgets: [ColorModeBudget], notes: [String]) {
        self.displayID = displayID
        self.transportName = transportName
        self.state = state
        self.rawGbps = rawGbps
        self.availableGbps = availableGbps
        self.encodingName = encodingName
        self.requiredGbps = requiredGbps
        self.dscActive = dscActive
        self.fecEnabled = fecEnabled
        self.colorModeBudgets = colorModeBudgets
        self.notes = notes
    }
}

/// 색 모드 1개의 필요 대역폭과 링크 수용 여부. 선택 불가 사유의 수치 근거. (PRD-DGN-002)
public struct ColorModeBudget: Codable, Hashable, Sendable, Identifiable {
    public enum Verdict: String, Codable, Sendable {
        /// 현재 타이밍에서 선택 가능.
        case offered
        /// 선택 불가: 무압축 필요 대역폭이 링크 유효 대역폭 초과.
        case exceedsBandwidth
        /// 선택 불가: 대역폭은 충분하나 시스템이 현재 타이밍에서 제공하지 않음.
        case notOffered
    }

    public var descriptor: ColorDescriptor
    public var colorElementID: Int?
    public var requiredGbps: Double
    public var verdict: Verdict
    public var needsDSC: Bool

    public var id: String { "\(descriptor.pixelEncoding.rawValue)-\(descriptor.bitsPerComponent)-\(descriptor.dynamicRange.rawValue)-\(descriptor.eotf.rawValue)" }
}

public enum LinkAnalyzer {
    /// 링크 상태와 신호 정보로 대역폭 보고 구성.
    public static func report(display: DisplaySummary, signal: SignalInfo?, state: DPTransportState?, dscActive: Bool?, fecEnabled: Bool?) -> LinkReport {
        var notes: [String] = []
        let transportName: String
        if display.identity.isBuiltin {
            transportName = "내장 패널 (eDP)"
        } else if signal?.transport == "HDMI" || state?.downstreamPortType == "HDMI" {
            transportName = state == nil ? "HDMI" : "HDMI (DisplayPort 변환 경유)"
        } else {
            transportName = "DisplayPort"
        }

        var raw: Double?, available: Double?, encoding: String?
        if let state, state.hasLink, let rate = state.laneRateGbps {
            raw = rate * Double(state.laneCount)
            available = BandwidthCalculator.dpAvailableGbps(laneRateGbps: rate, laneCount: state.laneCount)
            encoding = BandwidthCalculator.dpEncodingName(laneRateGbps: rate)
            if state.laneCount < state.maxLaneCount {
                notes.append("레인 \(state.laneCount)개 사용 중 (최대 \(state.maxLaneCount)개). 나머지 레인은 USB 데이터 등 다른 전송에 할당되었을 가능성")
            }
            if state.isTunneled {
                notes.append("Thunderbolt 또는 USB4 터널을 지나는 DisplayPort. 표시 속도는 터널 안의 DP 링크 기준")
            }
        }

        // 필요 대역폭: 실제 송출값 우선, 없으면 현재 타이밍과 색 모드.
        var required: Double?
        if let link = signal?.linkData {
            required = BandwidthCalculator.requiredGbps(pixelClockHz: link.pixelClockHz, bitsPerPixel: link.bitsPerPixel)
        } else if let timing = signal?.currentTiming, let color = signal?.currentColor {
            required = BandwidthCalculator.requiredGbps(pixelClockHz: timing.pixelClockHz, bitsPerPixel: color.bitsPerPixel)
        }
        if dscActive == true {
            notes.append("DSC 압축 사용 중. 필요 대역폭은 압축 전 값이며 실제 전송량은 더 작음")
        }

        return LinkReport(
            displayID: display.id, transportName: transportName, state: state,
            rawGbps: raw, availableGbps: available, encodingName: encoding,
            requiredGbps: required, dscActive: dscActive, fecEnabled: fecEnabled,
            colorModeBudgets: signal.map { budgets(signal: $0, availableGbps: available) } ?? [],
            notes: notes
        )
    }

    /// 현재 타이밍에서 싱크가 선언한 색 형식 전체의 필요 대역폭과 수용 여부.
    /// 색 공간만 다른 형식은 한 줄로 묶음.
    public static func budgets(signal: SignalInfo, availableGbps: Double?) -> [ColorModeBudget] {
        guard let timing = signal.currentTiming else { return [] }
        let offered = signal.selectableColorModes
        var seen = Set<String>()
        var result: [ColorModeBudget] = []
        func add(_ element: ColorElement, offeredElement: ColorElement?) {
            var descriptor = element.descriptor
            descriptor.colorimetry = nil
            let key = "\(descriptor.pixelEncoding.rawValue)-\(descriptor.bitsPerComponent)-\(descriptor.dynamicRange.rawValue)-\(descriptor.eotf.rawValue)"
            guard seen.insert(key).inserted else { return }
            let required = BandwidthCalculator.requiredGbps(pixelClockHz: timing.pixelClockHz, bitsPerPixel: element.bitsPerPixel)
            let verdict: ColorModeBudget.Verdict
            if offeredElement != nil {
                verdict = .offered
            } else if let availableGbps, required > availableGbps {
                verdict = .exceedsBandwidth
            } else {
                verdict = .notOffered
            }
            result.append(ColorModeBudget(descriptor: descriptor, colorElementID: offeredElement?.id, requiredGbps: required, verdict: verdict, needsDSC: offeredElement.map { timing.requiresDSC($0.id) } ?? false))
        }
        for element in offered { add(element, offeredElement: element) }
        for element in signal.sinkColorElements where !element.isVirtual {
            let match = offered.first { $0.descriptor == element.descriptor }
            add(element, offeredElement: match)
        }
        return result.sorted { a, b in
            (a.descriptor.eotf.rawValue, a.descriptor.pixelEncoding.isRGB ? 0 : 1, -a.requiredGbps, a.descriptor.dynamicRange.rawValue) < (b.descriptor.eotf.rawValue, b.descriptor.pixelEncoding.isRGB ? 0 : 1, -b.requiredGbps, b.descriptor.dynamicRange.rawValue)
        }
    }
}
