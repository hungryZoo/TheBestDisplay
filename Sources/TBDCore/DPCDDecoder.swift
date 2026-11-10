import Foundation

/// DPCD(DisplayPort Configuration Data) 레지스터 해석. (SRS-LNK-004)
public struct DPCDInfo: Codable, Hashable, Sendable {
    /// 예: "1.4"
    public var revision: String?
    /// 싱크 최대 레인당 속도 (Gbps).
    public var maxLaneRateGbps: Double?
    public var maxLaneCount: Int?
    public var supportsEnhancedFraming: Bool?
    public var supportsTPS3: Bool?
    public var supportsDownspread: Bool?
    public var supports8b10b: Bool?
    public var supports128b132b: Bool?
    public var supportsDSC: Bool?
    public var dscRevision: String?
    /// 현재 설정된 레인당 속도 (Gbps). 속도 표 방식(eDP)이면 nil.
    public var currentLaneRateGbps: Double?
    public var currentLaneCount: Int?
    public var sinkCount: Int?
    /// 레인별 상태 (클록 복구, 채널 등화, 심볼 잠금).
    public var laneStatus: [LaneStatus]
    public var interlaneAlignDone: Bool?
    public var dscEnabled: Bool?

    public init(laneStatus: [LaneStatus] = []) { self.laneStatus = laneStatus }

    public struct LaneStatus: Codable, Hashable, Sendable {
        public var lane: Int
        public var clockRecoveryDone: Bool
        public var channelEqualizationDone: Bool
        public var symbolLocked: Bool

        public var isGood: Bool { clockRecoveryDone && channelEqualizationDone && symbolLocked }
    }
}

public enum DPCDDecoder {
    /// 링크 속도 부호(0.27 Gbps 단위)를 Gbps로. 예: 0x1E = 8.1
    public static func laneRateGbps(code: UInt8) -> Double? {
        code == 0 ? nil : Double(code) * 0.27
    }

    /// 주소별로 읽은 바이트열을 해석. 읽지 못한 구간은 nil로 전달.
    /// - Parameters:
    ///   - receiverCaps: 000h부터 16바이트
    ///   - dscCaps: 060h부터
    ///   - linkConfig: 100h부터 8바이트
    ///   - dscEnable: 160h 1바이트
    ///   - status: 200h부터 8바이트
    ///   - extendedCaps: 2200h부터 16바이트 (있으면 수신기 능력보다 우선)
    public static func decode(receiverCaps: [UInt8]?, dscCaps: [UInt8]?, linkConfig: [UInt8]?, dscEnable: [UInt8]?, status: [UInt8]?, extendedCaps: [UInt8]?) -> DPCDInfo {
        var info = DPCDInfo(laneStatus: [])
        // 확장 능력 필드가 유효(판 번호 0 아님)하면 우선 사용.
        let caps = (extendedCaps?.first ?? 0) != 0 ? extendedCaps : receiverCaps
        if let caps, caps.count >= 4, caps[0] != 0 {
            info.revision = "\(caps[0] >> 4).\(caps[0] & 0xF)"
            info.maxLaneRateGbps = laneRateGbps(code: caps[1])
            info.maxLaneCount = Int(caps[2] & 0x1F)
            info.supportsEnhancedFraming = caps[2] & 0x80 != 0
            info.supportsTPS3 = caps[2] & 0x40 != 0
            info.supportsDownspread = caps[3] & 0x01 != 0
            if caps.count > 6 {
                info.supports8b10b = caps[6] & 0x01 != 0
                info.supports128b132b = caps[6] & 0x02 != 0
            }
        }
        if let dscCaps, dscCaps.count >= 2 {
            info.supportsDSC = dscCaps[0] & 0x01 != 0
            if info.supportsDSC == true {
                info.dscRevision = "\(dscCaps[1] & 0xF).\(dscCaps[1] >> 4)"
            }
        }
        if let linkConfig, linkConfig.count >= 2 {
            // 표준 속도 부호만 해석. eDP의 속도 표 방식(부호 0)은 미해석.
            let standard: Set<UInt8> = [0x06, 0x0A, 0x14, 0x1E]
            if standard.contains(linkConfig[0]) { info.currentLaneRateGbps = laneRateGbps(code: linkConfig[0]) }
            let lanes = Int(linkConfig[1] & 0x1F)
            if lanes > 0 { info.currentLaneCount = lanes }
        }
        if let dscEnable, let first = dscEnable.first {
            info.dscEnabled = first & 0x01 != 0
        }
        if let status, status.count >= 5 {
            info.sinkCount = Int(status[0] & 0x3F)
            let count = info.currentLaneCount ?? info.maxLaneCount ?? 0
            for lane in 0..<min(count, 4) {
                let byte = status[2 + lane / 2]
                let nibble = lane % 2 == 0 ? byte & 0x0F : byte >> 4
                info.laneStatus.append(.init(lane: lane, clockRecoveryDone: nibble & 0x1 != 0, channelEqualizationDone: nibble & 0x2 != 0, symbolLocked: nibble & 0x4 != 0))
            }
            info.interlaneAlignDone = status[4] & 0x01 != 0
        }
        return info
    }
}

/// DP 송신기가 보고한 링크 훈련 결과. `IODPDeviceGetLinkTrainingData`의 0x98바이트 구조체에서 실측으로 확인한 필드만 해석.
public struct LinkTrainingData: Codable, Hashable, Sendable {
    public static let byteCount = 0x98
    public var laneCount: Int
    /// 레인당 속도 (Gbps) = 속도 부호 x 0.27. 부호 0이면 nil.
    public var laneRateGbps: Double?
    public var rateCode: Int
    /// 표준 속도(RBR, HBR, HBR2, HBR3) 여부. 내장 패널은 비표준 속도를 쓸 수 있음.
    public var isStandardRate: Bool

    /// 오프셋 0x08 레인 수, 0x0C 링크 속도 부호 (spikes 문서 L3).
    public static func decode(_ bytes: [UInt8]) -> LinkTrainingData? {
        guard bytes.count >= byteCount else { return nil }
        let lanes = Int(bytes[0x08]), code = bytes[0x0C]
        guard (1...4).contains(lanes) else { return nil }
        let standard: Set<UInt8> = [0x06, 0x0A, 0x14, 0x1E]
        return LinkTrainingData(laneCount: lanes, laneRateGbps: DPCDDecoder.laneRateGbps(code: code), rateCode: Int(code), isStandardRate: standard.contains(code))
    }
}
