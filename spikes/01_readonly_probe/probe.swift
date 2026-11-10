// Phase 0 실험 01: 읽기 전용 비공개 API 동작 확인
// 실행: swiftc -O probe.swift -o /tmp/tbd_probe && /tmp/tbd_probe
// 디스플레이 상태를 변경하는 호출 없음.

import CoreGraphics
import Foundation
import IOKit

// MARK: - dlsym 로더

let frameworks = [
    "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight",
    "/System/Library/PrivateFrameworks/IOMobileFramebuffer.framework/IOMobileFramebuffer",
    "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices",
    "/System/Library/Frameworks/CoreDisplay.framework/CoreDisplay",
    "/System/Library/Frameworks/IOKit.framework/IOKit",
]
let handles = frameworks.map { dlopen($0, RTLD_NOW) }

func sym<T>(_ name: String, as type: T.Type) -> T? {
    for h in handles {
        if let p = dlsym(h, name) { return unsafeBitCast(p, to: T.self) }
    }
    print("  [심볼 없음] \(name)")
    return nil
}

func section(_ title: String) { print("\n=== \(title) ===") }

// MARK: - 디스플레이 목록

var count: UInt32 = 0
CGGetOnlineDisplayList(0, nil, &count)
var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
CGGetOnlineDisplayList(count, &ids, &count)
section("S0 온라인 디스플레이")
for id in ids {
    print("  id=\(id) builtin=\(CGDisplayIsBuiltin(id) != 0) vendor=\(CGDisplayVendorNumber(id)) model=\(CGDisplayModelNumber(id)) unit=\(CGDisplayUnitNumber(id)) main=\(CGDisplayIsMain(id) != 0) rot=\(CGDisplayRotation(id))")
}

// MARK: - S1 SkyLight 모드 열거

struct SLSMode {  // 212바이트 (0xD4)
    var modeNumber: UInt32 = 0
    var flags: UInt32 = 0
    var width: UInt32 = 0
    var height: UInt32 = 0
    var depth: UInt32 = 0
    var pad: (UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32) = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
    var pad2: UInt16 = 0
    var freq: UInt16 = 0
    var pad3: (UInt32, UInt32, UInt32, UInt32) = (0, 0, 0, 0)
    var density: Float = 0
}

section("S1 SLS 모드 열거 (구조체 크기 \(MemoryLayout<SLSMode>.size))")
typealias GetNum = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Int32>) -> Int32
typealias GetDesc = @convention(c) (CGDirectDisplayID, Int32, UnsafeMutableRawPointer, Int32) -> Int32
typealias GetCur = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Int32>) -> Int32
typealias ModeBool = @convention(c) (CGDirectDisplayID, Int32) -> Bool
let getNum = sym("SLSGetNumberOfDisplayModes", as: GetNum.self)
let getDesc = sym("SLSGetDisplayModeDescriptionOfLength", as: GetDesc.self)
let getCur = sym("SLSGetCurrentDisplayMode", as: GetCur.self)
let isVRR = sym("SLSIsDisplayModeVRR", as: ModeBool.self)
let isProMotion = sym("SLSIsDisplayModeProMotion", as: ModeBool.self)
if let getNum, let getDesc, let getCur {
    for id in ids {
        var n: Int32 = 0
        var cur: Int32 = -1
        let e1 = getNum(id, &n)
        let e2 = getCur(id, &cur)
        print("  display \(id): modes=\(n) (err \(e1)) current=\(cur) (err \(e2))")
        var hidpi = 0
        var rates = Set<UInt16>()
        var maxW: UInt32 = 0
        for i in 0..<n {
            var m = SLSMode()
            _ = getDesc(id, i, &m, Int32(MemoryLayout<SLSMode>.size))
            if m.density >= 2 { hidpi += 1 }
            rates.insert(m.freq)
            maxW = max(maxW, m.width)
            if i == cur {
                let vrr = isVRR.map { $0(id, i) }
                let pm = isProMotion.map { $0(id, i) }
                print("    현재 모드: #\(m.modeNumber) \(m.width)x\(m.height) @\(m.freq)Hz depth=\(m.depth) density=\(m.density) flags=0x\(String(m.flags, radix: 16)) vrr=\(String(describing: vrr)) promotion=\(String(describing: pm))")
            }
        }
        print("    HiDPI 모드 \(hidpi)개, 주사율 종류 \(rates.sorted()), 최대 폭 \(maxW)")
        let pub = (CGDisplayCopyAllDisplayModes(id, [kCGDisplayShowDuplicateLowResolutionModes: kCFBooleanTrue] as CFDictionary) as? [CGDisplayMode]) ?? []
        print("    공개 API 모드 수(중복 저해상도 포함): \(pub.count)")
    }
}

// MARK: - S2 HDR 상태

section("S2 HDR 상태")
typealias DispBool = @convention(c) (CGDirectDisplayID) -> Bool
let hdrSupported = sym("SLSDisplaySupportsHDRMode", as: DispBool.self)
let hdrEnabled = sym("SLSDisplayIsHDRModeEnabled", as: DispBool.self)
for id in ids {
    print("  display \(id): supportsHDR=\(String(describing: hdrSupported?(id))) hdrEnabled=\(String(describing: hdrEnabled?(id)))")
}

// MARK: - S3 IORegistry 링크 정보

func services(_ cls: String) -> [io_service_t] {
    var it: io_iterator_t = 0
    guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching(cls), &it) == KERN_SUCCESS else { return [] }
    var out: [io_service_t] = []
    while case let s = IOIteratorNext(it), s != 0 { out.append(s) }
    IOObjectRelease(it)
    return out
}

func prop(_ s: io_service_t, _ key: String) -> Any? {
    IORegistryEntryCreateCFProperty(s, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
}

section("S3 IORegistry DisplayPort 전송 상태")
for s in services("IOPortTransportStateDisplayPort") {
    let keys = ["TransportDescription", "Active", "LinkRateDescription", "LaneCount", "MaxLaneCount", "HPD_StateDescription", "SinkCount", "Tunneled", "ProductName"]
    let line = keys.map { "\($0)=\(prop(s, $0).map { "\($0)" } ?? "-")" }.joined(separator: " ")
    let edid = (prop(s, "EDID") as? Data)?.count ?? 0
    print("  \(line) EDID=\(edid)B")
}

// MARK: - S4 IOMobileFramebuffer 현재 타이밍/색 모드

section("S4 IOMobileFramebuffer 디지털 출력 모드")
typealias MFBOpen = @convention(c) (io_service_t, mach_port_t, UInt32, UnsafeMutablePointer<OpaquePointer?>) -> Int32
typealias MFBGetMode = @convention(c) (OpaquePointer, UnsafeMutablePointer<UInt32>, UnsafeMutablePointer<UInt32>) -> Int32
typealias MFBGetState = @convention(c) (OpaquePointer, UnsafeMutablePointer<UInt32>) -> Int32
let mfbOpen = sym("IOMobileFramebufferOpen", as: MFBOpen.self)
let mfbGetMode = sym("IOMobileFramebufferGetDigitalOutMode", as: MFBGetMode.self)
let mfbGetState = sym("IOMobileFramebufferGetDigitalOutState", as: MFBGetState.self)
if let mfbOpen, let mfbGetMode {
    for s in services("IOMobileFramebufferShim") {
        let ext = (prop(s, "external") as? Bool) ?? false
        let w = prop(s, "DisplayWidth") ?? "-"
        var ref: OpaquePointer?
        let e = mfbOpen(s, mach_task_self_, 0, &ref)
        guard e == 0, let ref else { print("  external=\(ext) width=\(w) open 실패 err=0x\(String(UInt32(bitPattern: e), radix: 16))"); continue }
        var color: UInt32 = 0
        var timing: UInt32 = 0
        let e2 = mfbGetMode(ref, &color, &timing)
        var state: UInt32 = 0
        let e3 = mfbGetState?(ref, &state) ?? -1
        print("  external=\(ext) width=\(w) GetDigitalOutMode err=0x\(String(UInt32(bitPattern: e2), radix: 16)) colorID=\(color) timingID=\(timing) | state err=\(e3) state=\(state) | DPTimingModeId=\(prop(s, "DPTimingModeId") ?? "-")")
    }
}

// MARK: - S5 IOAVService (EDID, DDC 읽기)

section("S5 IOAVService")
typealias AVCreate = @convention(c) (CFAllocator?, io_service_t) -> Unmanaged<CFTypeRef>?
typealias AVCopyEDID = @convention(c) (CFTypeRef, UnsafeMutablePointer<Unmanaged<CFData>?>) -> Int32
typealias AVI2C = @convention(c) (CFTypeRef, UInt32, UInt32, UnsafeMutableRawPointer, UInt32) -> Int32
typealias AVCopyProps = @convention(c) (CFTypeRef) -> Unmanaged<CFDictionary>?
let avCreate = sym("IOAVServiceCreateWithService", as: AVCreate.self)
let avCopyEDID = sym("IOAVServiceCopyEDID", as: AVCopyEDID.self)
let avRead = sym("IOAVServiceReadI2C", as: AVI2C.self)
let avWrite = sym("IOAVServiceWriteI2C", as: AVI2C.self)
let avCopyProps = sym("IOAVServiceCopyProperties", as: AVCopyProps.self)

func ddcRead(_ av: CFTypeRef, vcp: UInt8) -> (cur: UInt16, max: UInt16)? {
    guard let avRead, let avWrite else { return nil }
    var req: [UInt8] = [0x82, 0x01, vcp, 0]
    req[3] = 0x6E ^ 0x51 ^ req[0] ^ req[1] ^ req[2]
    for _ in 0..<3 {
        guard avWrite(av, 0x37, 0x51, &req, UInt32(req.count)) == 0 else { usleep(20000); continue }
        usleep(50000)
        var reply = [UInt8](repeating: 0, count: 11)
        guard avRead(av, 0x37, 0x51, &reply, UInt32(reply.count)) == 0 else { usleep(20000); continue }
        var chk: UInt8 = 0x50
        for b in reply[0..<10] { chk ^= b }
        if chk == reply[10], reply[2] == 0x02, reply[3] == 0 {
            return (UInt16(reply[8]) << 8 | UInt16(reply[9]), UInt16(reply[6]) << 8 | UInt16(reply[7]))
        }
    }
    return nil
}

if let avCreate {
    for s in services("DCPAVServiceProxy") {
        let loc = prop(s, "Location") ?? "-"
        guard let av = avCreate(kCFAllocatorDefault, s)?.takeRetainedValue() else { print("  location=\(loc) 생성 실패"); continue }
        var edidRef: Unmanaged<CFData>?
        let e = avCopyEDID?(av, &edidRef) ?? -1
        let edid = edidRef?.takeRetainedValue() as Data?
        let props = avCopyProps?(av)?.takeRetainedValue() as? [String: Any]
        print("  location=\(loc) CopyEDID err=0x\(String(UInt32(bitPattern: e), radix: 16)) bytes=\(edid?.count ?? 0) properties 키 \(props?.count ?? -1)개")
        if let props { print("    키: \(props.keys.sorted().joined(separator: ", "))") }
        if "\(loc)" == "External" {
            for (name, code) in [("밝기", UInt8(0x10)), ("대비", 0x12), ("볼륨", 0x62), ("입력", 0x60)] {
                if let r = ddcRead(av, vcp: code) { print("    DDC \(name)(0x\(String(code, radix: 16))): 현재 \(r.cur) / 최대 \(r.max)") } else { print("    DDC \(name)(0x\(String(code, radix: 16))): 응답 없음") }
            }
        }
    }
}

// MARK: - S6 DisplayServices 밝기

section("S6 DisplayServices 밝기")
typealias DSGet = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
typealias DSCan = @convention(c) (CGDirectDisplayID) -> Bool
let dsGet = sym("DisplayServicesGetBrightness", as: DSGet.self)
let dsCan = sym("DisplayServicesCanChangeBrightness", as: DSCan.self)
for id in ids {
    var b: Float = -1
    let e = dsGet?(id, &b) ?? -1
    print("  display \(id): canChange=\(String(describing: dsCan?(id))) err=\(e) brightness=\(b)")
}

// MARK: - S7 클래스 존재 확인

section("S7 Objective-C 클래스")
dlopen("/System/Library/PrivateFrameworks/MonitorPanel.framework/MonitorPanel", RTLD_NOW)
dlopen("/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness", RTLD_NOW)
for name in ["CGVirtualDisplay", "CGVirtualDisplayDescriptor", "CGVirtualDisplaySettings", "CGVirtualDisplayMode", "MPDisplay", "MPDisplayMgr", "CBBlueLightClient", "CBTrueToneClient", "CBAdaptationClient"] {
    print("  \(name): \(NSClassFromString(name) != nil ? "있음" : "없음")")
}
