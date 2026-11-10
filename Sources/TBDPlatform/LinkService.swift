import CoreGraphics
import Foundation
import IOKit
import TBDCore

/// 링크 상태, DPCD, 링크 훈련 데이터 조회. 읽기 전용. (SRS-LNK-001, SRS-LNK-003, SRS-LNK-004)
public enum LinkService {
    typealias CreateFn = @convention(c) (CFAllocator?, io_service_t) -> Unmanaged<CFTypeRef>?
    // 시그니처 근거: spikes 문서 4절(디스어셈블)과 L2, L3(실측).
    typealias ReadDPCDFn = @convention(c) (CFTypeRef, UInt32, UnsafeMutableRawPointer, UInt32) -> Int32
    typealias TrainingFn = @convention(c) (CFTypeRef, UnsafeMutableRawPointer) -> Int32
    typealias FRLFn = @convention(c) (CFTypeRef, UnsafeMutableRawPointer) -> Int32

    /// 전 포트의 DisplayPort 전송 상태 (비활성 포함).
    public static func transportStates() -> [DPTransportState] {
        IORegistry.forEachService(matching: "IOPortTransportStateDisplayPort") { service in
            DPTransportState.decode(IORegistry.properties(service))
        }
    }

    /// 디스플레이에 대응하는 전송 상태. 활성 상태 중 식별 정보가 맞는 것, 활성 외장 상태가 1개뿐이면 그 상태.
    public static func transportState(for display: DisplaySummary, among states: [DPTransportState]? = nil) -> DPTransportState? {
        guard !display.identity.isBuiltin else { return nil }
        let active = (states ?? transportStates()).filter(\.isActive)
        return active.first { $0.matches(display.identity) } ?? (active.count == 1 ? active.first : nil)
    }

    /// DP 장치 핸들. 위치("External", "Embedded")로 선택. 외장이 여러 개면 대응 불가로 nil.
    static func dpDevice(external: Bool, symbols: PrivateSymbols) -> CFTypeRef? {
        guard let create = symbols.function("IODPDeviceCreateWithService", in: .ioKit, as: CreateFn.self) else { return nil }
        let wanted = external ? "External" : "Embedded"
        let devices: [CFTypeRef] = IORegistry.forEachService(matching: "DCPDPDeviceProxy") { service in
            guard (IORegistry.property(service, "Location") as? String) == wanted else { return nil }
            return create(kCFAllocatorDefault, service)?.takeRetainedValue()
        }
        return devices.count == 1 ? devices[0] : nil
    }

    /// DPCD 읽기와 해석. 터널링 경로 등 읽기 실패 구간은 건너뜀. 수신기 능력을 읽지 못하면 nil.
    public static func dpcd(for display: DisplaySummary, symbols: PrivateSymbols = .shared) -> DPCDInfo? {
        guard let read = symbols.function("IODPDeviceReadDPCD", in: .ioKit, as: ReadDPCDFn.self),
              let device = dpDevice(external: !display.identity.isBuiltin, symbols: symbols)
        else { return nil }
        func bytes(_ address: UInt32, _ length: Int) -> [UInt8]? {
            var buffer = [UInt8](repeating: 0, count: length)
            return read(device, address, &buffer, UInt32(length)) == 0 ? buffer : nil
        }
        guard let caps = bytes(0x000, 16) else { return nil }
        return DPCDDecoder.decode(receiverCaps: caps, dscCaps: bytes(0x060, 16), linkConfig: bytes(0x100, 8), dscEnable: bytes(0x160, 1), status: bytes(0x200, 8), extendedCaps: bytes(0x2200, 16), hdcpBcaps: bytes(0x68028, 1), hdcpRxCaps: bytes(0x6921D, 3))
    }

    public static func linkTraining(for display: DisplaySummary, symbols: PrivateSymbols = .shared) -> LinkTrainingData? {
        guard let get = symbols.function("IODPDeviceGetLinkTrainingData", in: .ioKit, as: TrainingFn.self),
              let device = dpDevice(external: !display.identity.isBuiltin, symbols: symbols)
        else { return nil }
        var buffer = [UInt8](repeating: 0, count: LinkTrainingData.byteCount)
        guard get(device, &buffer) == 0 else { return nil }
        return LinkTrainingData.decode(buffer)
    }

    /// HDMI FRL 링크 데이터 원시 8바이트. 해석 근거 미확보로 원시 값만 제공. (SRS-LNK-003, HDMI 직결 구성 미검증)
    public static func frlLinkDataRaw(for display: DisplaySummary, symbols: PrivateSymbols = .shared) -> [UInt8]? {
        guard let get = symbols.function("IOAVServiceGetFRLLinkData", in: .ioKit, as: FRLFn.self),
              let service = SignalService.avService(for: display, symbols: symbols)
        else { return nil }
        var buffer = [UInt8](repeating: 0, count: 8)
        return get(service.ref, &buffer) == 0 ? buffer : nil
    }

    /// 전원이 켜진 DP 송신기의 FEC 상태. 터널링 경로처럼 해당 송신기를 특정할 수 없으면 nil.
    public static func fecEnabled() -> Bool? {
        let powered: [Bool] = IORegistry.forEachService(matching: "AppleDPTXController") { service in
            guard (IORegistry.property(service, "Power") as? Bool) == true else { return nil }
            return IORegistry.property(service, "FECEnabled") as? Bool
        }
        return powered.count == 1 ? powered[0] : nil
    }

    /// 디스플레이의 링크와 대역폭 보고.
    public static func report(for display: DisplaySummary, signal: SignalInfo?, dsc: DSCAssessment?, states: [DPTransportState]? = nil) -> LinkReport {
        var state = transportState(for: display, among: states)
        // 내장 패널: 전송 상태 노드가 없으므로 링크 훈련 데이터로 속도와 레인 구성.
        var extraNotes: [String] = []
        if state == nil, let training = linkTraining(for: display), let rate = training.laneRateGbps {
            state = DPTransportState(
                transportDescription: display.identity.isBuiltin ? "내장 패널" : "DP 송신기",
                isActive: true, laneRateGbps: rate, linkRateDescription: training.isStandardRate ? DPTransportState.rateName(rate) : String(format: "%.2f Gbps (비표준 속도)", rate),
                laneCount: training.laneCount, maxLaneCount: training.laneCount, isTunneled: false,
                hpdState: 1, hpdDescription: "", sinkCount: 1, parentPortType: display.identity.isBuiltin ? "내장" : "", parentPortNumber: 0
            )
            extraNotes.append("전송 상태 노드가 없어 링크 훈련 데이터(속도 부호 0x\(String(training.rateCode, radix: 16)))로 속도와 레인 수 표시")
        }
        var report = LinkAnalyzer.report(display: display, signal: signal, state: state, dscActive: dsc?.isActive, fecEnabled: fecEnabled())
        report.notes += extraNotes
        return report
    }
}
