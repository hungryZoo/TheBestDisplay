import CoreGraphics
import Foundation
import IOKit
import TBDCore

/// IOAVService 핸들. `DCPAVServiceProxy` 노드에서 생성.
/// 시그니처 근거: `docs/research/spikes.md` 실험 01(S5)과 공개 소스(MonitorControl, m1ddc)의 같은 선언.
public final class AVService {
    typealias CreateFn = @convention(c) (CFAllocator?, io_service_t) -> Unmanaged<CFTypeRef>?
    typealias CopyEDIDFn = @convention(c) (CFTypeRef, UnsafeMutablePointer<Unmanaged<CFData>?>) -> Int32

    public let ref: CFTypeRef
    /// `Location` 속성: "External" 또는 "Embedded".
    public let location: String
    public let registryEntryID: UInt64

    init(ref: CFTypeRef, location: String, registryEntryID: UInt64) {
        self.ref = ref
        self.location = location
        self.registryEntryID = registryEntryID
    }

    public var isExternal: Bool { location == "External" }

    /// 시스템의 IOAVService 전체.
    public static func all(symbols: PrivateSymbols = .shared) -> [AVService] {
        guard let create = symbols.function("IOAVServiceCreateWithService", in: .ioKit, as: CreateFn.self) else { return [] }
        return IORegistry.forEachService(matching: "DCPAVServiceProxy") { service in
            guard let ref = create(kCFAllocatorDefault, service)?.takeRetainedValue() else { return nil }
            let location = IORegistry.property(service, "Location") as? String ?? ""
            return AVService(ref: ref, location: location, registryEntryID: IORegistry.entryID(service))
        }
    }

    public func copyEDID(symbols: PrivateSymbols = .shared) -> Data? {
        guard let copy = symbols.function("IOAVServiceCopyEDID", in: .ioKit, as: CopyEDIDFn.self) else { return nil }
        var out: Unmanaged<CFData>?
        guard copy(ref, &out) == 0, let data = out?.takeRetainedValue() as Data?, !data.isEmpty else { return nil }
        return data
    }
}

/// EDID 원본과 출처.
public struct EDIDRecord: Codable, Hashable, Sendable {
    public var displayID: UInt32
    /// "IOAVService" 또는 "IORegistry"
    public var source: String
    public var data: Data
    public var parsed: EDID

    public init(displayID: UInt32, source: String, data: Data) {
        self.displayID = displayID
        self.source = source
        self.data = data
        self.parsed = EDIDParser.parse(data)
    }
}

/// 디스플레이별 EDID 원본 획득. (SRS-INF-003)
public enum EDIDSource {
    /// 후보 EDID. 출처 우선순위: IOAVService, IORegistry 전송 상태 노드.
    static func candidates() -> [(source: String, data: Data)] {
        var result: [(String, Data)] = []
        for service in AVService.all() where service.isExternal {
            if let data = service.copyEDID() { result.append(("IOAVService", data)) }
        }
        result += IORegistry.forEachService(matching: "IOPortTransportStateDisplayPort") { service -> (String, Data)? in
            guard let data = IORegistry.property(service, "EDID") as? Data, !data.isEmpty else { return nil }
            return ("IORegistry", data)
        }
        return result
    }

    /// 디스플레이 식별 정보와 EDID 머리의 제조사, 제품 코드, 일련번호를 대조하여 대응.
    /// macOS가 일련번호를 지운 EDID를 줄 수 있으므로 제조사와 제품 코드만 일치하는 후보가 1개 계열이면 차선으로 채택.
    public static func records(for displays: [DisplaySummary]) -> [EDIDRecord] {
        let all = candidates().map { (source: $0.source, data: $0.data, edid: EDIDParser.parse($0.data)) }
        var result: [EDIDRecord] = []
        for display in displays where !display.identity.isBuiltin {
            let id = display.identity
            let sameProduct = all.filter { $0.edid.vendorNumber == id.vendorID && UInt32($0.edid.productCode) == id.productID }
            let exact = sameProduct.filter { $0.edid.serialNumber == id.serialNumber }
            let sameProductCount = displays.filter { $0.identity.vendorID == id.vendorID && $0.identity.productID == id.productID }.count
            let chosen = exact.first ?? (sameProductCount == 1 ? sameProduct.first : nil)
            if let chosen {
                result.append(EDIDRecord(displayID: id.displayID, source: chosen.source, data: chosen.data))
            }
        }
        return result
    }

    public static func record(for display: DisplaySummary, among displays: [DisplaySummary]) -> EDIDRecord? {
        records(for: displays).first { $0.displayID == display.id }
    }
}
