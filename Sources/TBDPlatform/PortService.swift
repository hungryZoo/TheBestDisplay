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
        // PHY 노드는 칩마다 클래스 이름이 달라 속성 존재로 찾음.
        let phys = IORegistry.services(havingProperty: PortInventory.phyPropertyKey).map { service -> [String: Any] in
            defer { IOObjectRelease(service) }
            return IORegistry.properties(service)
        }
        if !phys.isEmpty { nodes["Apple" + PortInventory.phyClassSuffix] = phys }
        let battery: [[String: Any]] = IORegistry.forEachService(matching: PortInventory.batteryClass) { IORegistry.properties($0) }
        if !battery.isEmpty { nodes[PortInventory.batteryClass] = battery }
        return PortInventory.decode(nodesByClass: nodes)
    }

    public static func connectionPaths(displays: [DisplaySummary]) -> [ConnectionPath] {
        ConnectionPathBuilder.build(inventory: inventory(), displays: displays)
    }
}
