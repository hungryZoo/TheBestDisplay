import Foundation

/// 진단 입력: 한 시점의 시스템 디스플레이 상태 전체. 진단 엔진과 보고서의 유일한 입력. (SRS-DGN-001, SRS 1.3절)
public struct DiagnosticSnapshot: Codable, Hashable, Sendable {
    public var capturedAt: Date
    public var system: SystemInfo
    public var displays: [DisplayDiagnostics]
    public var inventory: PortInventory
    public var paths: [ConnectionPath]
    /// 디스플레이 정보가 붙은 프레임버퍼 노드. 온라인 등록 전 단계의 판별에 사용.
    public var attachedFramebuffers: [AttachedFramebuffer]

    public init(capturedAt: Date, system: SystemInfo, displays: [DisplayDiagnostics], inventory: PortInventory, paths: [ConnectionPath], attachedFramebuffers: [AttachedFramebuffer]) {
        self.capturedAt = capturedAt
        self.system = system
        self.displays = displays
        self.inventory = inventory
        self.paths = paths
        self.attachedFramebuffers = attachedFramebuffers
    }

    public var externalDisplayCount: Int { displays.filter { !$0.summary.identity.isBuiltin }.count }
}

public struct SystemInfo: Codable, Hashable, Sendable {
    /// 예: "Apple M5"
    public var chipName: String
    /// 예: "Mac17,2"
    public var modelIdentifier: String
    public var osVersion: String
    /// 덮개 닫힘 상태. 덮개가 없는 기기는 nil.
    public var lidClosed: Bool?
    public var hasBuiltinDisplay: Bool

    public init(chipName: String, modelIdentifier: String, osVersion: String, lidClosed: Bool?, hasBuiltinDisplay: Bool) {
        self.chipName = chipName
        self.modelIdentifier = modelIdentifier
        self.osVersion = osVersion
        self.lidClosed = lidClosed
        self.hasBuiltinDisplay = hasBuiltinDisplay
    }

    /// 내장 디스플레이가 있는 Mac의 칩별 외장 디스플레이 동시 연결 한도 (Apple 공개 사양 기준 추정). 판단 근거가 없으면 nil.
    /// 기본형 M1, M2, M3은 1대, 기본형 M4와 M5는 2대, Pro는 2대, Max는 4대.
    public var estimatedExternalDisplayLimit: Int? {
        guard hasBuiltinDisplay else { return nil }
        let name = chipName.replacingOccurrences(of: "Apple ", with: "")
        let parts = name.split(separator: " ")
        guard let family = parts.first, family.hasPrefix("M"), let generation = Int(family.dropFirst()) else { return nil }
        switch parts.dropFirst().first.map(String.init) {
        case "Max"?: return 4
        case "Pro"?: return 2
        case "Ultra"?: return nil
        case nil: return generation >= 4 ? 2 : 1
        default: return nil
        }
    }
}

public struct AttachedFramebuffer: Codable, Hashable, Sendable {
    public var isExternal: Bool
    public var productName: String?
    public var productID: UInt32?
    public var serialNumber: UInt32?

    public init(isExternal: Bool, productName: String?, productID: UInt32?, serialNumber: UInt32?) {
        self.isExternal = isExternal
        self.productName = productName
        self.productID = productID
        self.serialNumber = serialNumber
    }
}

/// 디스플레이 1대의 진단 자료.
public struct DisplayDiagnostics: Codable, Hashable, Sendable, Identifiable {
    public var summary: DisplaySummary
    public var edid: EDID?
    /// EDID 원본의 16진 문자열 (공백 없음).
    public var edidHex: String?
    public var currentMode: DisplayMode?
    public var modeCount: Int
    public var signal: SignalInfo?
    public var dsc: DSCAssessment?
    public var hdr: HDRStatus?
    public var link: LinkReport?
    public var dpcd: DPCDInfo?
    public var linkTraining: LinkTrainingData?

    public var id: UInt32 { summary.id }

    public init(summary: DisplaySummary, edid: EDID? = nil, edidHex: String? = nil, currentMode: DisplayMode? = nil, modeCount: Int = 0, signal: SignalInfo? = nil, dsc: DSCAssessment? = nil, hdr: HDRStatus? = nil, link: LinkReport? = nil, dpcd: DPCDInfo? = nil, linkTraining: LinkTrainingData? = nil) {
        self.summary = summary
        self.edid = edid
        self.edidHex = edidHex
        self.currentMode = currentMode
        self.modeCount = modeCount
        self.signal = signal
        self.dsc = dsc
        self.hdr = hdr
        self.link = link
        self.dpcd = dpcd
        self.linkTraining = linkTraining
    }
}

public extension SignalInfo {
    /// 보고서용 축약: 현재 타이밍 외의 타이밍에서 색 모드 목록 제거.
    func slimmed() -> SignalInfo {
        var copy = self
        copy.timings = timings.map { timing in
            guard timing.id != currentTimingID else { return timing }
            var t = timing
            t.colorModes = []
            return t
        }
        return copy
    }
}

public extension DiagnosticSnapshot {
    /// 일련번호와 기기 고유 식별자를 가린 사본. (PRD-DGN-005)
    /// 대상: 디스플레이 일련번호, UUID, EDID의 일련번호 바이트와 일련번호 서술자, 전송 상태의 일련번호와 EDID.
    func redacted() -> DiagnosticSnapshot {
        var copy = self
        copy.displays = displays.map { d in
            var d = d
            d.summary.identity.serialNumber = 0
            d.summary.identity.uuid = nil
            d.edid?.serialNumber = 0
            d.edid?.serialString = nil
            d.edidHex = d.edidHex.map(Self.redactEDIDHex)
            let redactedState = d.link?.state.map(Self.redact)
            d.link?.state = redactedState
            return d
        }
        copy.inventory.dpStates = inventory.dpStates.map(Self.redact)
        copy.paths = paths.map { p in
            var p = p
            p.dp = p.dp.map(Self.redact)
            return p
        }
        copy.attachedFramebuffers = attachedFramebuffers.map { f in
            var f = f
            f.serialNumber = nil
            return f
        }
        return copy
    }

    private static func redact(_ state: DPTransportState) -> DPTransportState {
        var s = state
        s.serialNumber = nil
        if let edid = s.edid, edid.count >= 16 {
            var bytes = [UInt8](edid)
            for i in 12..<16 { bytes[i] = 0 }
            s.edid = Data(bytes)
        }
        return s
    }

    /// EDID 16진 문자열에서 일련번호 바이트(12-15)를 0으로.
    static func redactEDIDHex(_ hex: String) -> String {
        guard hex.count >= 32 else { return hex }
        var chars = Array(hex)
        for i in 24..<32 { chars[i] = "0" }
        return String(chars)
    }
}
