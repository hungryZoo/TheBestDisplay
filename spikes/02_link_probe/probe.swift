// Phase 0 실험 02: 링크 데이터와 DPCD 읽기 (읽기 전용)
// 실행: swiftc -O probe.swift -o /tmp/tbd_link && /tmp/tbd_link
// 시그니처는 IOKit 디스어셈블(dyld_info -disassemble)로 확인.

import Foundation
import IOKit

let h = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_NOW)
func sym<T>(_ n: String, _ t: T.Type) -> T? {
    guard let p = dlsym(h, n) else { print("[심볼 없음] \(n)"); return nil }
    return unsafeBitCast(p, to: T.self)
}

func services(_ cls: String) -> [io_service_t] {
    var it: io_iterator_t = 0
    IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching(cls), &it)
    var out: [io_service_t] = []
    while case let s = IOIteratorNext(it), s != 0 { out.append(s) }
    return out
}

func location(_ s: io_service_t) -> String {
    IORegistryEntryCreateCFProperty(s, "Location" as CFString, nil, 0)?.takeRetainedValue() as? String ?? "-"
}

func hex(_ bytes: [UInt8]) -> String { bytes.map { String(format: "%02x", $0) }.joined(separator: " ") }

typealias Create = @convention(c) (CFAllocator?, io_service_t) -> Unmanaged<CFTypeRef>?

// MARK: - L1 IOAVService 비디오 링크 데이터

print("=== L1 IOAVServiceGetLinkData ===")
typealias GetLink = @convention(c) (CFTypeRef, UInt32, UnsafeMutableRawPointer) -> Int32
typealias LinkStr = @convention(c) (CFAllocator?, UnsafeRawPointer, UnsafeRawPointer?, UInt32) -> Unmanaged<CFString>?
typealias FRL = @convention(c) (CFTypeRef, UnsafeMutableRawPointer) -> Int32
if let create = sym("IOAVServiceCreateWithService", Create.self), let getLink = sym("IOAVServiceGetLinkData", GetLink.self) {
    let linkStr = sym("IOAVCreateStringWithVideoLinkData", LinkStr.self)
    let frl = sym("IOAVServiceGetFRLLinkData", FRL.self)
    for s in services("DCPAVServiceProxy") where location(s) == "External" {
        guard let av = create(nil, s)?.takeRetainedValue() else { continue }
        var buf = [UInt8](repeating: 0, count: 0x110)
        let e = getLink(av, 1, &buf)
        print("  err=0x\(String(UInt32(bitPattern: e), radix: 16))")
        if e == 0 {
            for row in stride(from: 0, to: 0x110, by: 16) { print(String(format: "  %03x: ", row) + hex(Array(buf[row..<row + 16]))) }
            for flags in [UInt32(1), 0xFFFF] {
                if let str = linkStr?(nil, buf, nil, flags)?.takeRetainedValue() { print("  문자열(flags=\(flags)): \(str)") }
            }
        }
        var frlBuf = [UInt8](repeating: 0, count: 8)
        if let frl { print("  FRL err=0x\(String(UInt32(bitPattern: frl(av, &frlBuf)), radix: 16)) data=\(hex(frlBuf))") }
    }
}

// MARK: - L2 DPCD 읽기

print("=== L2 IODPDeviceReadDPCD ===")
typealias ReadDPCD = @convention(c) (CFTypeRef, UInt32, UnsafeMutableRawPointer, UInt32) -> Int32
typealias Training = @convention(c) (CFTypeRef, UnsafeMutableRawPointer) -> Int32
if let create = sym("IODPDeviceCreateWithService", Create.self), let read = sym("IODPDeviceReadDPCD", ReadDPCD.self) {
    let training = sym("IODPDeviceGetLinkTrainingData", Training.self)
    for s in services("DCPDPDeviceProxy") {
        let loc = location(s)
        guard let dev = create(nil, s)?.takeRetainedValue() else { print("  location=\(loc) 생성 실패"); continue }
        print("  location=\(loc)")
        for (name, addr, len) in [("수신기 능력 000h", UInt32(0x000), UInt32(16)), ("DSC 지원 060h", 0x060, 16), ("링크 설정 100h", 0x100, 8), ("DSC 활성 160h", 0x160, 1), ("링크 상태 200h", 0x200, 8), ("확장 능력 2200h", 0x2200, 16)] {
            var buf = [UInt8](repeating: 0, count: Int(len))
            let e = read(dev, addr, &buf, len)
            print("    \(name): err=0x\(String(UInt32(bitPattern: e), radix: 16)) \(e == 0 ? hex(buf) : "")")
        }
        if let training {
            var t = [UInt8](repeating: 0, count: 0x98)
            let e = training(dev, &t)
            print("    링크 훈련 데이터: err=0x\(String(UInt32(bitPattern: e), radix: 16)) \(e == 0 ? hex(Array(t[0..<48])) : "")")
        }
    }
}
