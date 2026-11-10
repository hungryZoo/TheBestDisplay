import Foundation
import IOKit
import TBDCore

/// 진단 스냅샷 수집. 읽기 전용. (SRS 1.3절)
public enum SnapshotBuilder {
    public static func systemInfo(displays: [DisplaySummary]) -> SystemInfo {
        func sysctlString(_ name: String) -> String {
            var size = 0
            guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return "" }
            var buffer = [CChar](repeating: 0, count: size)
            guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return "" }
            return String(cString: buffer)
        }
        let version = ProcessInfo.processInfo.operatingSystemVersion
        // 덮개 상태: 전원 관리 루트 도메인의 AppleClamshellState. 덮개가 없는 기기는 키 없음.
        let lid: [Bool] = IORegistry.forEachService(matching: "IOPMrootDomain") { IORegistry.property($0, "AppleClamshellState") as? Bool }
        return SystemInfo(
            chipName: sysctlString("machdep.cpu.brand_string"),
            modelIdentifier: sysctlString("hw.model"),
            osVersion: "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)",
            lidClosed: lid.first,
            hasBuiltinDisplay: displays.contains { $0.identity.isBuiltin } || lid.first != nil
        )
    }

    public static func attachedFramebuffers() -> [AttachedFramebuffer] {
        let nodes = SignalService.framebufferNodes()
        defer { nodes.forEach { IOObjectRelease($0.service) } }
        return nodes.map { node in
            let product = ((node.properties["DisplayAttributes"] as? [String: Any])?["ProductAttributes"] as? [String: Any]) ?? [:]
            return AttachedFramebuffer(
                isExternal: node.isExternal,
                productName: product["ProductName"] as? String,
                productID: (product["ProductID"] as? NSNumber)?.uint32Value,
                serialNumber: (product["SerialNumber"] as? NSNumber)?.uint32Value
            )
        }
    }

    public static func build() -> DiagnosticSnapshot {
        let displays = DisplayCatalog.displays()
        let records = EDIDSource.records(for: displays)
        let inventory = PortService.inventory()
        let sourceDSC = SignalService.sourceSupportsDSC()
        let details = displays.map { display -> DisplayDiagnostics in
            let record = records.first { $0.displayID == display.id }
            let modes = ModeService.modes(for: display.id)
            let signal = SignalService.signalInfo(for: display)
            let dsc = signal.map { DSCAssessment.assess(signal: $0, edidSupportsDSC: record?.parsed.sinkCapabilities.supportsDSC, sourceSupportsDSC: sourceDSC) }
            return DisplayDiagnostics(
                summary: display,
                edid: record?.parsed,
                edidHex: record.map { $0.data.map { String(format: "%02x", $0) }.joined() },
                currentMode: ModeService.currentMode(for: display.id, in: modes),
                modeCount: modes.count,
                signal: signal,
                dsc: dsc,
                hdr: HDRService.status(for: display, edid: record?.parsed),
                link: LinkService.report(for: display, signal: signal, dsc: dsc, states: inventory.dpStates),
                dpcd: LinkService.dpcd(for: display),
                linkTraining: LinkService.linkTraining(for: display)
            )
        }
        return DiagnosticSnapshot(
            capturedAt: Date(),
            system: systemInfo(displays: displays),
            displays: details,
            inventory: inventory,
            paths: ConnectionPathBuilder.build(inventory: inventory, displays: displays),
            attachedFramebuffers: attachedFramebuffers()
        )
    }
}
