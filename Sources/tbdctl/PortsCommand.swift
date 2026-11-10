import Foundation
import TBDCore
import TBDPlatform

struct PortsOutput: Encodable {
    var inventory: PortInventory
    var paths: [ConnectionPath]
}

/// `tbdctl ports [--json]` (PRD-PRT-001-003)
func runPorts(_ command: ParsedCommand, json: Bool) {
    let displays = DisplayCatalog.displays()
    let inventory = PortService.inventory()
    let paths = ConnectionPathBuilder.build(inventory: inventory, displays: displays)
    if json {
        printJSON(PortsOutput(inventory: inventory, paths: paths))
        return
    }
    if paths.isEmpty {
        print("포트 정보 없음 (이 기기의 포트 컨트롤러 노드를 찾지 못함)")
        return
    }
    for path in paths {
        print("\(path.port.key.label) [\(path.port.portDescription)]")
        print("  지원 전송: \(path.port.transportsSupported.isEmpty ? "없음" : path.port.transportsSupported.joined(separator: ", "))")
        for step in path.steps {
            let mark: String
            switch step.status {
            case .ok: mark = "정상"
            case .unknown: mark = "정보"
            case .broken: mark = "문제"
            }
            print("  [\(mark)] \(step.title): \(step.detail)")
        }
        if path.isConnected { print("  경로: \(path.summary)") }
    }
    let devices = inventory.switches.filter { !$0.isHost }
    if !inventory.switches.isEmpty {
        print("Thunderbolt 또는 USB4 스위치: 호스트 라우터 \(inventory.switches.count - devices.count)개, 연결 장치 \(devices.count)개")
        for device in devices { print("  \(device.summary)") }
    }
    if let adapter = inventory.powerAdapter { print("전원 어댑터: \(adapter.summary)") }
}
