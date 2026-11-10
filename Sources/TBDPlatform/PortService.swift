import Foundation
import TBDCore

/// 포트, 케이블, 독 정보 조회. IORegistry 읽기 전용. (SRS-PRT-001)
public enum PortService {
    public static func inventory() -> PortInventory {
        var nodes: [String: [[String: Any]]] = [:]
        for className in PortInventory.relevantClasses {
            let list: [[String: Any]] = IORegistry.forEachService(matching: className) { IORegistry.properties($0) }
            if !list.isEmpty { nodes[className] = list }
        }
        return PortInventory.decode(nodesByClass: nodes)
    }

    public static func connectionPaths(displays: [DisplaySummary]) -> [ConnectionPath] {
        ConnectionPathBuilder.build(inventory: inventory(), displays: displays)
    }
}
