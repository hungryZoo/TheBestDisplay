// 실험 03: XDR 밝기 업스케일 가능 여부.
// (1) EDR 콘텐츠를 그리는 작은 창으로 EDR 헤드룸이 열리는지, (2) 1.0을 넘는 전달 테이블 값이 유지되는지 확인.
// 실행: swiftc -O spikes/03_xdr_probe/probe.swift -o <출력> && <출력>
import AppKit
import Metal
import QuartzCore

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

guard let screen = NSScreen.main, let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
    print("화면 없음")
    exit(1)
}
let display = CGDirectDisplayID(number.uint32Value)

/// NSScreen 객체는 구성 시점의 값을 담으므로 매번 새로 조회.
func headroom(_ label: String) {
    let current = NSScreen.screens.first { ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == display } ?? screen
    print("\(label): 현재 \(current.maximumExtendedDynamicRangeColorComponentValue), 잠재 \(current.maximumPotentialExtendedDynamicRangeColorComponentValue), 기준 \(current.maximumReferenceExtendedDynamicRangeColorComponentValue)")
}

func tableMax() -> Float {
    var r = [CGGammaValue](repeating: 0, count: 256), g = r, b = r
    var count: UInt32 = 0
    CGGetDisplayTransferByTable(display, 256, &r, &g, &b, &count)
    return r.prefix(Int(count)).max() ?? -1
}

func pump(_ seconds: TimeInterval) {
    RunLoop.current.run(until: Date().addingTimeInterval(seconds))
}

headroom("시작")
print("전달 테이블 최댓값 (시작): \(tableMax())")

guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
    print("Metal 장치 없음")
    exit(1)
}
let frame = NSRect(x: screen.frame.minX, y: screen.frame.minY, width: 8, height: 8)
let window = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
window.level = .screenSaver
window.ignoresMouseEvents = true
window.isOpaque = false
window.backgroundColor = .clear
window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
let layer = CAMetalLayer()
layer.device = device
layer.pixelFormat = .rgba16Float
layer.wantsExtendedDynamicRangeContent = true
layer.colorspace = CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3)
layer.frame = CGRect(x: 0, y: 0, width: 8, height: 8)
layer.drawableSize = CGSize(width: 16, height: 16)
let view = NSView(frame: NSRect(x: 0, y: 0, width: 8, height: 8))
view.wantsLayer = true
view.layer = layer
window.contentView = view
window.orderFrontRegardless()

func draw(_ value: Double) {
    guard let drawable = layer.nextDrawable() else {
        print("drawable 없음")
        return
    }
    let pass = MTLRenderPassDescriptor()
    pass.colorAttachments[0].texture = drawable.texture
    pass.colorAttachments[0].loadAction = .clear
    pass.colorAttachments[0].storeAction = .store
    pass.colorAttachments[0].clearColor = MTLClearColor(red: value, green: value, blue: value, alpha: 1)
    guard let buffer = queue.makeCommandBuffer(), let encoder = buffer.makeRenderCommandEncoder(descriptor: pass) else { return }
    encoder.endEncoding()
    buffer.present(drawable)
    buffer.commit()
}

for step in 1...6 {
    draw(4.0)
    pump(0.5)
    headroom("EDR 창 표시 후 \(Double(step) * 0.5)초")
}

let factor: Float = 1.4
var table = (0..<256).map { Float($0) / 255 * factor }
let setResult = CGSetDisplayTransferByTable(display, 256, &table, &table, &table)
print("전달 테이블 설정 결과: \(setResult.rawValue)")
pump(1.5)
print("전달 테이블 최댓값 (1.4배 설정 후): \(tableMax())")
headroom("전달 테이블 설정 후")

CGDisplayRestoreColorSyncSettings()
window.orderOut(nil)
pump(1.0)
print("전달 테이블 최댓값 (복원 후): \(tableMax())")
headroom("복원 후")
