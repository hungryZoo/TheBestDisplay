import AppKit
import CoreGraphics
import Foundation
import TBDCore

/// 온라인 디스플레이 목록과 기본 상태 조회. (SRS-INF-001)
public enum DisplayCatalog {
    public static func onlineDisplayIDs() -> [CGDirectDisplayID] {
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &count) == .success, count > 0 else { return [] }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetOnlineDisplayList(count, &ids, &count) == .success else { return [] }
        return Array(ids.prefix(Int(count)))
    }

    /// 메인 디스플레이를 앞에 두고 나머지는 디스플레이 ID 순으로 정렬.
    public static func displays() -> [DisplaySummary] {
        let names = screenNames()
        return onlineDisplayIDs()
            .map { summary(for: $0, names: names) }
            .sorted { ($0.isMain ? 0 : 1, $0.identity.displayID) < ($1.isMain ? 0 : 1, $1.identity.displayID) }
    }

    public static func snapshot() -> SystemSnapshot {
        SystemSnapshot(capturedAt: Date(), displays: displays())
    }

    static func summary(for id: CGDirectDisplayID, names: [CGDirectDisplayID: String]) -> DisplaySummary {
        let builtin = CGDisplayIsBuiltin(id) != 0
        let uuid = CGDisplayCreateUUIDFromDisplayID(id).map { CFUUIDCreateString(nil, $0.takeRetainedValue()) as String }
        let identity = DisplayIdentity(
            displayID: id,
            uuid: uuid,
            vendorID: CGDisplayVendorNumber(id),
            productID: CGDisplayModelNumber(id),
            serialNumber: CGDisplaySerialNumber(id),
            name: names[id] ?? infoDictionaryName(id) ?? (builtin ? "내장 디스플레이" : "디스플레이 \(id)"),
            isBuiltin: builtin
        )
        let mode = CGDisplayCopyDisplayMode(id)
        let bounds = CGDisplayBounds(id)
        let size = CGDisplayScreenSize(id)
        let mirror = CGDisplayMirrorsDisplay(id)
        return DisplaySummary(
            identity: identity,
            isMain: CGDisplayIsMain(id) != 0,
            isActive: CGDisplayIsActive(id) != 0,
            mirrorsDisplayID: mirror == kCGNullDirectDisplay ? nil : mirror,
            pointWidth: mode?.width ?? Int(bounds.width),
            pointHeight: mode?.height ?? Int(bounds.height),
            pixelWidth: mode?.pixelWidth ?? CGDisplayPixelsWide(id),
            pixelHeight: mode?.pixelHeight ?? CGDisplayPixelsHigh(id),
            refreshRate: mode?.refreshRate ?? 0,
            rotationDegrees: CGDisplayRotation(id),
            originX: Int(bounds.origin.x),
            originY: Int(bounds.origin.y),
            physicalWidthMM: Double(size.width),
            physicalHeightMM: Double(size.height)
        )
    }

    /// `NSScreen`의 현지화 이름. 활성 디스플레이만 포함.
    static func screenNames() -> [CGDirectDisplayID: String] {
        var result: [CGDirectDisplayID: String] = [:]
        for screen in NSScreen.screens {
            if let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
                result[number.uint32Value] = screen.localizedName
            }
        }
        return result
    }

    /// `NSScreen`에 없는 디스플레이(미러 대상 등)의 이름. CoreDisplay 정보 사전의 제품명 사용.
    /// 시그니처: CFDictionaryRef CoreDisplay_DisplayCreateInfoDictionary(CGDirectDisplayID) — 공개 소스(MonitorControl 등)에서 같은 선언 사용.
    static func infoDictionaryName(_ id: CGDirectDisplayID) -> String? {
        typealias CreateInfo = @convention(c) (CGDirectDisplayID) -> Unmanaged<CFDictionary>?
        guard let create = PrivateSymbols.shared.function("CoreDisplay_DisplayCreateInfoDictionary", in: .coreDisplay, as: CreateInfo.self),
              let info = create(id)?.takeRetainedValue() as? [String: Any],
              let names = info["DisplayProductName"] as? [String: String]
        else { return nil }
        return names["ko_KR"] ?? names["en_US"] ?? names.values.first
    }
}
