// 지정한 프로세스가 소유한 창을 레이어별로 집계. 상태 항목(메뉴 막대) 창은 레이어 25.
// 사용: swift scripts/window_probe.swift <pid>
import CoreGraphics
import Foundation

let pid = Int(CommandLine.arguments.dropFirst().first ?? "") ?? -1
let windows = (CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]]) ?? []
var layers: [Int: Int] = [:]
for w in windows where (w[kCGWindowOwnerPID as String] as? Int) == pid {
    let bounds = w[kCGWindowBounds as String] as? [String: Double] ?? [:]
    guard (bounds["Width"] ?? 0) > 1, (bounds["Height"] ?? 0) > 1 else { continue }
    layers[(w[kCGWindowLayer as String] as? Int) ?? -1, default: 0] += 1
}
print("pid=\(pid) layer0Windows=\(layers[0] ?? 0) statusItemWindows=\(layers[25] ?? 0) layers=\(layers.sorted { $0.key < $1.key })")
