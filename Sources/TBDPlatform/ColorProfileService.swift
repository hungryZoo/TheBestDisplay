import ColorSync
import CoreGraphics
import Foundation
import TBDCore

/// 색 프로파일 열거와 지정. ColorSync 공개 API 사용. (SRS-CLR-002)
public enum ColorProfileService {
    static func uuid(_ display: CGDirectDisplayID) -> CFUUID? {
        CGDisplayCreateUUIDFromDisplayID(display)?.takeRetainedValue()
    }

    static func deviceInfo(_ display: CGDirectDisplayID) -> [String: Any]? {
        guard let uuid = uuid(display) else { return nil }
        return ColorSyncDeviceCopyDeviceInfo(kColorSyncDisplayDeviceClass.takeUnretainedValue(), uuid)?.takeRetainedValue() as? [String: Any]
    }

    /// 기본 프로파일 ID와 공장 프로파일 경로.
    static func factoryProfile(_ display: CGDirectDisplayID) -> (id: String, path: String?) {
        let factory = deviceInfo(display)?["FactoryProfiles"] as? [String: Any] ?? [:]
        let id = factory["DeviceDefaultProfileID"] as? String ?? (factory["DeviceDefaultProfileID"] as? NSNumber)?.stringValue ?? "1"
        let entry = factory[id] as? [String: Any]
        return (id, (entry?["DeviceProfileURL"] as? URL)?.path)
    }

    /// 현재 적용 중인 프로파일의 이름과 경로.
    public static func current(for display: CGDirectDisplayID) -> ColorProfileInfo? {
        guard let profile = ColorSyncProfileCreateWithDisplayID(display)?.takeRetainedValue() else { return nil }
        let name = ColorSyncProfileCopyDescriptionString(profile)?.takeRetainedValue() as String? ?? "이름 없음"
        let path = (ColorSyncProfileGetURL(profile, nil)?.takeUnretainedValue() as URL?)?.path ?? ""
        return ColorProfileInfo(name: name, path: path, isFactoryDefault: !path.isEmpty && path == factoryProfile(display).path)
    }

    /// 디스플레이에 지정할 수 있는 프로파일: 공장 프로파일과 설치된 RGB 디스플레이 프로파일.
    public static func available(for display: CGDirectDisplayID) -> [ColorProfileInfo] {
        var result: [ColorProfileInfo] = []
        let factory = factoryProfile(display)
        if let path = factory.path, let profile = ColorSyncProfileCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil)?.takeRetainedValue() {
            let name = ColorSyncProfileCopyDescriptionString(profile)?.takeRetainedValue() as String? ?? URL(fileURLWithPath: path).lastPathComponent
            result.append(ColorProfileInfo(name: name, path: path, isFactoryDefault: true))
        }
        final class Box { var items: [ColorProfileInfo] = [] }
        let box = Box()
        ColorSyncIterateInstalledProfiles({ info, context in
            guard let info = info as? [String: Any], let context else { return true }
            let box = Unmanaged<Box>.fromOpaque(context).takeUnretainedValue()
            // 디스플레이 클래스(mntr)의 RGB 프로파일만.
            guard (info[kColorSyncProfileClass.takeUnretainedValue() as String] as? String) == (kColorSyncSigDisplayClass.takeUnretainedValue() as String),
                  (info[kColorSyncProfileColorSpace.takeUnretainedValue() as String] as? String) == (kColorSyncSigRgbData.takeUnretainedValue() as String),
                  let url = info[kColorSyncProfileURL.takeUnretainedValue() as String] as? URL
            else { return true }
            let name = info[kColorSyncProfileDescription.takeUnretainedValue() as String] as? String ?? url.lastPathComponent
            box.items.append(ColorProfileInfo(name: name, path: url.path, isFactoryDefault: false))
            return true
        }, nil, Unmanaged.passUnretained(box).toOpaque(), nil)
        result += box.items.filter { $0.path != factory.path }
        return ColorProfileCatalog.sorted(result)
    }

    /// 사용자 지정 프로파일 설정. `profile`이 nil이거나 공장 프로파일이면 사용자 지정을 지워 기본값으로 복귀.
    public static func set(_ profile: ColorProfileInfo?, for display: CGDirectDisplayID) throws {
        guard let uuid = uuid(display) else { throw DisplayChangeError.displayNotFound }
        let factory = factoryProfile(display)
        let value: Any
        if let profile, !profile.isFactoryDefault, profile.path != factory.path {
            guard FileManager.default.fileExists(atPath: profile.path) else { throw DisplayChangeError.modeNotFound(profile.name) }
            value = URL(fileURLWithPath: profile.path) as CFURL
        } else {
            value = kCFNull as Any
        }
        let settings: [String: Any] = [factory.id: value, kColorSyncDeviceDefaultProfileID.takeUnretainedValue() as String: value]
        guard ColorSyncDeviceSetCustomProfiles(kColorSyncDisplayDeviceClass.takeUnretainedValue(), uuid, settings as CFDictionary) else {
            throw DisplayChangeError.system(operation: "색 프로파일 지정", code: -1)
        }
    }
}
