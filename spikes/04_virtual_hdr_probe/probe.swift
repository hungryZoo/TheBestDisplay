// 실험 04: CGVirtualDisplayMode의 transferFunction 인자와 HDR 지원 여부의 관계.
// 실행: swiftc -O spikes/04_virtual_hdr_probe/probe.swift -o <출력> && <출력>
import CoreGraphics
import Foundation
import ObjectiveC

let skyLight = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_NOW)
typealias BoolFn = @convention(c) (UInt32) -> Bool
let supportsHDR = unsafeBitCast(dlsym(skyLight, "SLSDisplaySupportsHDRMode"), to: BoolFn.self)
let isHDREnabled = unsafeBitCast(dlsym(skyLight, "SLSDisplayIsHDRModeEnabled"), to: BoolFn.self)

func online(_ id: UInt32) -> Bool {
    var count: UInt32 = 0
    var ids = [CGDirectDisplayID](repeating: 0, count: 16)
    CGGetOnlineDisplayList(16, &ids, &count)
    return ids.prefix(Int(count)).contains(id)
}

let queue = DispatchQueue(label: "probe.virtual")
for transfer: UInt32 in [0, 1, 2] {
    let descriptor = (NSClassFromString("CGVirtualDisplayDescriptor") as! NSObject.Type).init()
    descriptor.setValue("HDR 실험 \(transfer)", forKey: "name")
    descriptor.setValue(NSNumber(value: UInt32(1920)), forKey: "maxPixelsWide")
    descriptor.setValue(NSNumber(value: UInt32(1080)), forKey: "maxPixelsHigh")
    descriptor.setValue(NSValue(size: NSSize(width: 443, height: 249)), forKey: "sizeInMillimeters")
    descriptor.setValue(NSNumber(value: UInt32(0x5442)), forKey: "vendorID")
    descriptor.setValue(NSNumber(value: UInt32(0x4432)), forKey: "productID")
    descriptor.setValue(NSNumber(value: UInt32(100 + transfer)), forKey: "serialNum")
    descriptor.setValue(queue, forKey: "queue")

    let displayClass = NSClassFromString("CGVirtualDisplay") as! NSObject.Type
    typealias InitFn = @convention(c) (NSObject, Selector, NSObject) -> Unmanaged<NSObject>?
    let initSel = NSSelectorFromString("initWithDescriptor:")
    let allocated = displayClass.perform(NSSelectorFromString("alloc"))!.takeUnretainedValue() as! NSObject
    guard let display = unsafeBitCast(allocated.method(for: initSel), to: InitFn.self)(allocated, initSel, descriptor)?.takeRetainedValue() else {
        print("전달 함수 \(transfer): 생성 실패")
        continue
    }
    let modeClass = NSClassFromString("CGVirtualDisplayMode") as! NSObject.Type
    typealias ModeFn = @convention(c) (NSObject, Selector, UInt32, UInt32, Double, UInt32) -> Unmanaged<NSObject>?
    let modeSel = NSSelectorFromString("initWithWidth:height:refreshRate:transferFunction:")
    let modeAllocated = modeClass.perform(NSSelectorFromString("alloc"))!.takeUnretainedValue() as! NSObject
    guard let mode = unsafeBitCast(modeAllocated.method(for: modeSel), to: ModeFn.self)(modeAllocated, modeSel, 1920, 1080, 60, transfer)?.takeRetainedValue() else {
        print("전달 함수 \(transfer): 모드 생성 실패")
        continue
    }
    let settings = (NSClassFromString("CGVirtualDisplaySettings") as! NSObject.Type).init()
    settings.setValue(NSNumber(value: UInt32(0)), forKey: "hiDPI")
    settings.setValue([mode], forKey: "modes")
    typealias ApplyFn = @convention(c) (NSObject, Selector, NSObject) -> Bool
    let applySel = NSSelectorFromString("applySettings:")
    let applied = unsafeBitCast(display.method(for: applySel), to: ApplyFn.self)(display, applySel, settings)
    let id = (display.value(forKey: "displayID") as? NSNumber)?.uint32Value ?? 0
    var isOnline = false
    for _ in 0..<30 where !isOnline {
        usleep(100_000)
        isOnline = online(id)
    }
    usleep(800_000)
    let readBack = (mode.value(forKey: "transferFunction") as? NSNumber)?.uint32Value ?? 99
    print("전달 함수 \(transfer): 설정 적용 \(applied), id \(id), 온라인 \(isOnline), 모드의 전달 함수 \(readBack), HDR 지원 \(supportsHDR(id)), HDR 켜짐 \(isHDREnabled(id))")
    // 객체를 놓아 디스플레이 제거.
    withExtendedLifetime(display) {}
    usleep(300_000)
}
usleep(500_000)
