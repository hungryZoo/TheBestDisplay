import CoreGraphics
import Foundation
import IOKit
import TBDCore

/// 프레임버퍼 노드와 디지털 출력 모드 접근. (SRS-COL-002, SRS-COL-003)
public enum SignalService {
    // 시그니처 근거: spikes 문서 S4(실측), platform-apis 문서 4.2절(lumen의 같은 선언, Asahi Linux DCP 드라이버의 인자 순서).
    typealias OpenFn = @convention(c) (io_service_t, mach_port_t, UInt32, UnsafeMutablePointer<Unmanaged<CFTypeRef>?>) -> Int32
    typealias GetModeFn = @convention(c) (CFTypeRef, UnsafeMutablePointer<UInt32>, UnsafeMutablePointer<UInt32>) -> Int32
    typealias SetModeFn = @convention(c) (CFTypeRef, UInt32, UInt32) -> Int32
    // 시그니처 근거: spikes 문서 4절(디스어셈블)과 L1(실측). 두 번째 인자 1은 비디오 링크.
    typealias GetLinkDataFn = @convention(c) (CFTypeRef, UInt32, UnsafeMutableRawPointer) -> Int32

    /// 프레임버퍼 노드 클래스. 칩 세대에 따라 다름. (SRS 3.2절)
    static let framebufferClasses = ["IOMobileFramebufferShim", "AppleCLCD2"]

    struct FramebufferNode {
        var service: io_service_t
        var isExternal: Bool
        var properties: [String: Any]
    }

    /// 디스플레이 정보가 붙은 프레임버퍼 노드 목록. 호출자가 서비스 해제.
    static func framebufferNodes() -> [FramebufferNode] {
        framebufferClasses.flatMap { cls in
            IORegistry.services(matching: cls).compactMap { service -> FramebufferNode? in
                // 디스플레이가 붙지 않은 노드는 해상도 속성이 없음.
                guard IORegistry.property(service, "DisplayWidth") != nil else {
                    IOObjectRelease(service)
                    return nil
                }
                let keys = ["external", "DisplayAttributes", "DPTimingModeId", "Transport", "EDID UUID", "DisplayWidth", "DisplayHeight"]
                var properties: [String: Any] = [:]
                for key in keys { properties[key] = IORegistry.property(service, key) }
                return FramebufferNode(service: service, isExternal: (properties["external"] as? Bool) ?? false, properties: properties)
            }
        }
    }

    /// 디스플레이에 대응하는 프레임버퍼 노드 선택. 나머지 노드는 해제.
    /// 내장은 `external`이 없는 노드. 외장은 제품 속성(제조사, 제품 코드, 일련번호) 대조, 외장 노드가 1개뿐이면 그 노드.
    static func framebufferNode(for display: DisplaySummary) -> FramebufferNode? {
        let nodes = framebufferNodes()
        let id = display.identity
        func product(_ node: FramebufferNode) -> [String: Any] {
            ((node.properties["DisplayAttributes"] as? [String: Any])?["ProductAttributes"] as? [String: Any]) ?? [:]
        }
        func number(_ value: Any?) -> UInt32? { (value as? NSNumber)?.uint32Value }

        var chosen: Int?
        if id.isBuiltin {
            chosen = nodes.firstIndex { !$0.isExternal }
        } else {
            let externals = nodes.indices.filter { nodes[$0].isExternal }
            let sameProduct = externals.filter { number(product(nodes[$0])["LegacyManufacturerID"]) == id.vendorID && number(product(nodes[$0])["ProductID"]) == id.productID }
            chosen = sameProduct.first { number(product(nodes[$0])["SerialNumber"]) == id.serialNumber }
                ?? (sameProduct.count == 1 ? sameProduct.first : nil)
                ?? (externals.count == 1 ? externals.first : nil)
        }
        for (index, node) in nodes.enumerated() where index != chosen { IOObjectRelease(node.service) }
        return chosen.map { nodes[$0] }
    }

    static func open(_ service: io_service_t, symbols: PrivateSymbols) -> CFTypeRef? {
        guard let open = symbols.function("IOMobileFramebufferOpen", in: .ioMobileFramebuffer, as: OpenFn.self) else { return nil }
        var out: Unmanaged<CFTypeRef>?
        guard open(service, mach_task_self_, 0, &out) == 0 else { return nil }
        return out?.takeRetainedValue()
    }

    /// 현재 색 ID와 타이밍 ID.
    static func digitalOutMode(_ service: io_service_t, symbols: PrivateSymbols) -> (colorID: Int, timingID: Int)? {
        guard let get = symbols.function("IOMobileFramebufferGetDigitalOutMode", in: .ioMobileFramebuffer, as: GetModeFn.self),
              let framebuffer = open(service, symbols: symbols)
        else { return nil }
        var color: UInt32 = 0, timing: UInt32 = 0
        guard get(framebuffer, &color, &timing) == 0 else { return nil }
        return (Int(color), Int(timing))
    }

    /// 디스플레이의 신호 상태. 프레임버퍼 노드를 찾지 못하면 nil.
    public static func signalInfo(for display: DisplaySummary, symbols: PrivateSymbols = .shared) -> SignalInfo? {
        guard let node = framebufferNode(for: display) else { return nil }
        defer { IOObjectRelease(node.service) }
        let timings = SignalDecoder.timingElements(IORegistry.property(node.service, "TimingElements"))
        let colors = SignalDecoder.colorElements(IORegistry.property(node.service, "ColorElements"))
        let mode = digitalOutMode(node.service, symbols: symbols)
        let registryTiming = (node.properties["DPTimingModeId"] as? NSNumber)?.intValue
        let transport = (node.properties["Transport"] as? [String: Any])?["Downstream"] as? String
        return SignalInfo(
            displayID: display.id,
            timings: timings,
            sinkColorElements: colors,
            currentTimingID: mode?.timingID ?? registryTiming,
            currentColorID: mode?.colorID,
            linkData: linkData(for: display, symbols: symbols),
            transport: transport
        )
    }

    /// 실제 송출 중인 링크 데이터. 내장 패널과 대응 실패 시 nil.
    public static func linkData(for display: DisplaySummary, symbols: PrivateSymbols = .shared) -> VideoLinkData? {
        guard !display.identity.isBuiltin,
              let get = symbols.function("IOAVServiceGetLinkData", in: .ioKit, as: GetLinkDataFn.self),
              let service = avService(for: display, symbols: symbols)
        else { return nil }
        var buffer = [UInt8](repeating: 0, count: VideoLinkData.byteCount)
        guard get(service.ref, 1, &buffer) == 0 else { return nil }
        return VideoLinkData.decode(buffer)
    }

    /// 디스플레이에 대응하는 외장 IOAVService. EDID 머리의 제조사와 제품 코드 대조, 외장 서비스가 1개뿐이면 그 서비스.
    public static func avService(for display: DisplaySummary, symbols: PrivateSymbols = .shared) -> AVService? {
        let externals = AVService.all(symbols: symbols).filter(\.isExternal)
        let id = display.identity
        let matching = externals.filter { service in
            guard let data = service.copyEDID(symbols: symbols) else { return false }
            let edid = EDIDParser.parse(data)
            return edid.vendorNumber == id.vendorID && UInt32(edid.productCode) == id.productID
        }
        return matching.first ?? (externals.count == 1 ? externals.first : nil)
    }

    /// 색 모드 전환. 타이밍 ID는 현재 값을 유지. (SRS-COL-003)
    public static func setColorMode(colorID: Int, timingID: Int, for display: DisplaySummary, symbols: PrivateSymbols = .shared) throws {
        guard let set = symbols.function("IOMobileFramebufferSetDigitalOutMode", in: .ioMobileFramebuffer, as: SetModeFn.self) else {
            throw DisplayChangeError.unavailable("IOMobileFramebufferSetDigitalOutMode 없음")
        }
        guard let node = framebufferNode(for: display) else { throw DisplayChangeError.displayNotFound }
        defer { IOObjectRelease(node.service) }
        guard let framebuffer = open(node.service, symbols: symbols) else {
            throw DisplayChangeError.unavailable("프레임버퍼 열기 실패")
        }
        let result = set(framebuffer, UInt32(colorID), UInt32(timingID))
        guard result == 0 else { throw DisplayChangeError.system(operation: "색 모드 지정", code: result) }
    }

    /// 색 모드 서술과 일치하는 현재 타이밍의 색 모드로 전환. 재연결로 ID가 바뀐 뒤의 복귀에 사용.
    public static func setColorMode(matching descriptor: ColorDescriptor, for display: DisplaySummary) throws {
        guard ModeService.isOnline(display.id), let info = signalInfo(for: display), let timing = info.currentTimingID else {
            throw DisplayChangeError.displayNotFound
        }
        guard let element = descriptor.find(in: info.selectableColorModes) else {
            throw DisplayChangeError.modeNotFound(descriptor.label)
        }
        try setColorMode(colorID: element.id, timingID: timing, for: display)
    }

    /// 서술과 일치하는 타이밍과 색 모드로 전환. 타이밍 직접 선택의 복귀에 사용. (SRS-COL-007)
    public static func setTiming(matching timing: TimingDescriptor, color: ColorDescriptor, for display: DisplaySummary) throws {
        guard ModeService.isOnline(display.id), let info = signalInfo(for: display) else { throw DisplayChangeError.displayNotFound }
        guard let target = timing.find(in: info.timings) else {
            throw DisplayChangeError.modeNotFound("\(timing.hActive) x \(timing.vActive), \(DisplaySummary.formatHz(timing.refreshRate)) Hz")
        }
        let candidates = target.colorModes.filter { !$0.isVirtual }
        guard let element = color.find(in: candidates) ?? candidates.max(by: { ($0.score ?? 0) < ($1.score ?? 0) }) else {
            throw DisplayChangeError.modeNotFound(color.label)
        }
        try setColorMode(colorID: element.id, timingID: target.id, for: display)
    }

    /// DP 송신기의 DSC 지원. 송신기 노드가 없으면 nil.
    public static func sourceSupportsDSC() -> Bool? {
        let values = IORegistry.forEachService(matching: "AppleDPTXController") { IORegistry.property($0, "SupportsDSC") as? Bool }
        return values.isEmpty ? nil : values.contains(true)
    }
}
