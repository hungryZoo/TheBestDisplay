import Foundation
import IOKit

/// IORegistry 조회 보조 함수. 읽기 전용.
public enum IORegistry {
    /// 클래스 이름과 일치하는 서비스 목록. 호출자가 `IOObjectRelease` 책임.
    public static func services(matching className: String) -> [io_service_t] {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching(className), &iterator) == KERN_SUCCESS else { return [] }
        defer { IOObjectRelease(iterator) }
        var result: [io_service_t] = []
        while case let service = IOIteratorNext(iterator), service != 0 {
            result.append(service)
        }
        return result
    }

    /// 서비스마다 본문을 실행하고 서비스 해제.
    /// 지정한 속성이 있는 서비스 전체. 클래스 이름이 기기마다 다른 노드를 찾을 때 사용.
    public static func services(havingProperty key: String) -> [io_service_t] {
        var iterator: io_iterator_t = 0
        let matching = ["IOPropertyExistsMatch": key] as CFDictionary
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else { return [] }
        defer { IOObjectRelease(iterator) }
        var result: [io_service_t] = []
        while case let service = IOIteratorNext(iterator), service != 0 {
            result.append(service)
        }
        return result
    }

    public static func forEachService<T>(matching className: String, _ body: (io_service_t) -> T?) -> [T] {
        let list = services(matching: className)
        defer { list.forEach { IOObjectRelease($0) } }
        return list.compactMap(body)
    }

    public static func property(_ service: io_service_t, _ key: String) -> Any? {
        IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
    }

    public static func properties(_ service: io_service_t) -> [String: Any] {
        var unmanaged: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &unmanaged, kCFAllocatorDefault, 0) == KERN_SUCCESS else { return [:] }
        return (unmanaged?.takeRetainedValue() as? [String: Any]) ?? [:]
    }

    public static func name(_ service: io_service_t) -> String {
        var buffer = [CChar](repeating: 0, count: 128)
        guard IORegistryEntryGetName(service, &buffer) == KERN_SUCCESS else { return "" }
        return String(cString: buffer)
    }

    public static func entryID(_ service: io_service_t) -> UInt64 {
        var id: UInt64 = 0
        IORegistryEntryGetRegistryEntryID(service, &id)
        return id
    }
}
