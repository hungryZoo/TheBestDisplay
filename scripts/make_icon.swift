// 앱 아이콘 생성: 디스플레이와 신호선 도형을 그려 iconset PNG를 만듦.
// 사용: swift scripts/make_icon.swift <출력 iconset 폴더>
import AppKit
import CoreGraphics

func drawIcon(size: Int) -> Data? {
    let s = CGFloat(size)
    guard let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    // 바탕: 둥근 사각형과 세로 그라디언트 (여백 약 10%).
    let inset = s * 0.1
    let rect = CGRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let background = CGPath(roundedRect: rect, cornerWidth: rect.width * 0.225, cornerHeight: rect.width * 0.225, transform: nil)
    context.saveGState()
    context.addPath(background)
    context.clip()
    let colors = [CGColor(srgbRed: 0.10, green: 0.16, blue: 0.33, alpha: 1), CGColor(srgbRed: 0.05, green: 0.07, blue: 0.15, alpha: 1)] as CFArray
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!, colors: colors, locations: [0, 1])!
    context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: rect.maxY), end: CGPoint(x: 0, y: rect.minY), options: [])
    context.restoreGState()

    // 디스플레이 테두리.
    let screen = CGRect(x: s * 0.24, y: s * 0.40, width: s * 0.52, height: s * 0.34)
    let line = max(1, s * 0.028)
    context.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.95))
    context.setLineWidth(line)
    context.setLineJoin(.round)
    context.setLineCap(.round)
    context.addPath(CGPath(roundedRect: screen, cornerWidth: s * 0.035, cornerHeight: s * 0.035, transform: nil))
    context.strokePath()
    // 받침대.
    context.move(to: CGPoint(x: s * 0.50, y: screen.minY))
    context.addLine(to: CGPoint(x: s * 0.50, y: s * 0.31))
    context.move(to: CGPoint(x: s * 0.39, y: s * 0.31))
    context.addLine(to: CGPoint(x: s * 0.61, y: s * 0.31))
    context.strokePath()

    // 화면 안의 신호선 (진단 파형).
    context.setStrokeColor(CGColor(srgbRed: 0.35, green: 0.85, blue: 0.75, alpha: 1))
    context.setLineWidth(max(1, s * 0.024))
    let midY = screen.midY
    let points: [(CGFloat, CGFloat)] = [(0.29, 0), (0.39, 0), (0.43, 0.085), (0.48, -0.10), (0.53, 0.06), (0.57, 0), (0.71, 0)]
    for (index, point) in points.enumerated() {
        let p = CGPoint(x: s * point.0, y: midY + s * point.1)
        if index == 0 { context.move(to: p) } else { context.addLine(to: p) }
    }
    context.strokePath()

    guard let image = context.makeImage() else { return nil }
    return NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
}

let output = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset")
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
for (points, scale) in [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)] {
    let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
    guard let data = drawIcon(size: points * scale) else { fatalError("그리기 실패: \(name)") }
    try data.write(to: output.appendingPathComponent(name))
}
print(output.path)
