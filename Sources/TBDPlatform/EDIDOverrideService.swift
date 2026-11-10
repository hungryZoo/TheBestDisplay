import CoreGraphics
import Foundation
import IOKit
import TBDCore

/// 가상 EDID 적용과 해제. 디스플레이의 저장 장치는 바꾸지 않고 시스템이 인식하는 EDID만 교체. (SRS-EDO-002)
///
/// - 시그니처 근거: IOKit 역어셈블 (`IOConnectCallMethod` 선택자 0x17, 스칼라 입력 1개 = 모드, 구조체 입력 = EDID 바이트)와
///   공개 소스(Make-M1-Great-Again의 avedid.swift)의 같은 선언. 모드 1은 적용, 0은 해제.
/// - 적용 상태는 재시동 시 소멸. 화면이 나오지 않으면 재시동으로 원본 EDID 복귀.
public enum EDIDOverrideService {
    typealias SetVirtualEDIDModeFn = @convention(c) (CFTypeRef, Int32, CFData?) -> Int32
    typealias DetectDisplaysFn = @convention(c) () -> Int32

    public enum OverrideError: Error, Equatable, LocalizedError {
        case unavailable
        case builtinNotSupported
        case serviceNotFound
        case ioError(Int32)

        public var errorDescription: String? {
            switch self {
            case .unavailable: "가상 EDID 설정 함수를 찾을 수 없음 (IOAVServiceSetVirtualEDIDMode)"
            case .builtinNotSupported: "내장 디스플레이는 EDID 오버라이드 대상이 아님"
            case .serviceNotFound: "디스플레이에 대응하는 AV 서비스를 찾을 수 없음"
            case .ioError(let code):
                String(format: "가상 EDID 설정 실패 (IOReturn 0x%08X)%@", UInt32(bitPattern: code), UInt32(bitPattern: code) == 0xE00002C1 ? ": 권한 부족" : "")
            }
        }
    }

    /// 디스플레이에 대응하는 외장 AV 서비스. EDID의 제조사, 제품 코드, 일련번호로 대조.
    /// 연결되지 않은 포트의 서비스에 EDID가 걸리지 않도록 EDID가 읽히는 서비스만 대상.
    public static func service(for display: DisplaySummary, among displays: [DisplaySummary]) -> AVService? {
        guard !display.identity.isBuiltin else { return nil }
        let id = display.identity
        let candidates = AVService.all().filter(\.isExternal).compactMap { service -> (AVService, EDID)? in
            guard let data = service.copyEDID() else { return nil }
            return (service, EDIDParser.parse(data))
        }
        let sameProduct = candidates.filter { $0.1.vendorNumber == id.vendorID && UInt32($0.1.productCode) == id.productID }
        if let exact = sameProduct.first(where: { $0.1.serialNumber == id.serialNumber }) { return exact.0 }
        let externalCount = displays.filter { !$0.identity.isBuiltin }.count
        if sameProduct.count == 1 { return sameProduct[0].0 }
        // 외장 디스플레이와 EDID가 읽히는 서비스가 각각 1개면 그 서비스로 대응 (가상 EDID 적용으로 식별 정보가 달라진 경우 포함).
        if candidates.count == 1, externalCount == 1 { return candidates[0].0 }
        return nil
    }

    /// 가상 EDID 적용. 적용한 서비스의 레지스트리 항목 ID 반환.
    @discardableResult
    public static func apply(_ edid: Data, to display: DisplaySummary, among displays: [DisplaySummary]) throws -> UInt64 {
        guard !display.identity.isBuiltin else { throw OverrideError.builtinNotSupported }
        let issues = EDIDEditor.validate(edid)
        guard issues.isEmpty else { throw EDIDEditError.invalid(issues) }
        guard let set = PrivateSymbols.shared.function("IOAVServiceSetVirtualEDIDMode", in: .ioKit, as: SetVirtualEDIDModeFn.self) else { throw OverrideError.unavailable }
        guard let service = service(for: display, among: displays) else { throw OverrideError.serviceNotFound }
        let result = set(service.ref, 1, edid as CFData)
        guard result == 0 else { throw OverrideError.ioError(result) }
        redetect()
        return service.registryEntryID
    }

    /// 가상 EDID 해제. `registryEntryID`가 nil이거나 해당 서비스가 없으면 외장 서비스 전체 대상.
    /// 가상 EDID가 없는 서비스의 해제 호출은 변화 없음 (avedid.swift의 같은 사용).
    public static func reset(registryEntryID: UInt64?) throws {
        guard let set = PrivateSymbols.shared.function("IOAVServiceSetVirtualEDIDMode", in: .ioKit, as: SetVirtualEDIDModeFn.self) else { throw OverrideError.unavailable }
        let external = AVService.all().filter(\.isExternal)
        let matched = external.filter { $0.registryEntryID == registryEntryID }
        let targets = matched.isEmpty ? external : matched
        guard !targets.isEmpty else { throw OverrideError.serviceNotFound }
        var failure: Int32 = 0
        for service in targets {
            let result = set(service.ref, 0, nil)
            if result != 0 { failure = result }
        }
        redetect()
        if failure != 0, !matched.isEmpty { throw OverrideError.ioError(failure) }
    }

    /// 디스플레이 재감지 요청. 시스템 설정의 디스플레이 감지와 같은 동작. (PRD-EDO-004)
    @discardableResult
    public static func redetect() -> Bool {
        guard let detect = PrivateSymbols.shared.function("SLSDetectDisplays", in: .skyLight, as: DetectDisplaysFn.self) else { return false }
        return detect() == 0
    }
}
