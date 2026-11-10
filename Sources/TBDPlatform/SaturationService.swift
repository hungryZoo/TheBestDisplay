import ColorSync
import CoreGraphics
import Foundation
import TBDCore

/// 채도 조정: 현재 디스플레이 프로파일의 색 좌표를 바꾼 프로파일을 만들어 사용자 지정 프로파일로 지정. (SRS-CLR-007, PRD-CLR-008)
/// 색 프로파일 지정은 시스템 설정으로 남으므로 조정 전 프로파일을 저장해 두고 해제 시 되돌림.
public enum SaturationService {
    public struct Status: Codable, Sendable {
        /// 현재 채도. 조정이 없으면 1.
        public var saturation: Double
        /// 조정의 기준이 되는 프로파일 이름.
        public var baseName: String
        /// 조정할 수 없는 사유. 가능하면 nil.
        public var unavailableReason: String?
    }

    static func profilesFolder(_ store: SaturationStore) -> URL {
        store.fileURL.deletingLastPathComponent().appendingPathComponent("Profiles", isDirectory: true)
    }

    /// 현재 적용 중인 프로파일의 자료. 파일 경로가 없으면 ColorSync에서 복사.
    static func currentProfileData(_ display: CGDirectDisplayID) -> Data? {
        guard let profile = ColorSyncProfileCreateWithDisplayID(display)?.takeRetainedValue() else { return nil }
        return ColorSyncProfileCopyData(profile, nil)?.takeRetainedValue() as Data?
    }

    /// 저장된 조정이 지금도 적용 중인지 (다른 경로로 프로파일이 바뀌지 않았는지).
    static func activeEntry(for display: DisplaySummary, store: SaturationStore) -> SaturationStore.Entry? {
        guard let entry = store.entry(for: display.identity), ColorProfileService.current(for: display.id)?.path == entry.generatedPath else { return nil }
        return entry
    }

    public static func status(for display: DisplaySummary, store: SaturationStore = .standard) -> Status {
        if let entry = activeEntry(for: display, store: store) {
            return Status(saturation: entry.saturation, baseName: entry.baseName, unavailableReason: nil)
        }
        let current = ColorProfileService.current(for: display.id)
        var reason: String?
        if let data = currentProfileData(display.id) {
            do {
                let profile = try ICCProfile(data: data)
                _ = try SaturationAdjustment.adjustedProfile(profile, saturation: 1, baseName: "")
            } catch {
                reason = "현재 프로파일은 행렬 방식이 아니라 채도 조정 대상이 아님 (\(RevertCoordinator.describe(error)))"
            }
        } else {
            reason = "현재 색 프로파일을 읽을 수 없음"
        }
        return Status(saturation: 1, baseName: current?.name ?? "미확인", unavailableReason: reason)
    }

    /// 만든 프로파일을 ColorSync로 열어 검사. 문제가 있으면 사유 반환.
    static func verify(_ url: URL) -> String? {
        var error: Unmanaged<CFError>?
        guard let profile = ColorSyncProfileCreateWithURL(url as CFURL, &error)?.takeRetainedValue() else {
            return (error?.takeRetainedValue()).map { "\($0)" } ?? "프로파일을 열 수 없음"
        }
        var errors: Unmanaged<CFError>?
        var warnings: Unmanaged<CFError>?
        guard ColorSyncProfileVerify(profile, &errors, &warnings) else {
            return (errors?.takeRetainedValue()).map { "\($0)" } ?? "프로파일 검사 실패"
        }
        return nil
    }

    /// 채도 지정 (0.5-1.5). 1이면 해제와 같음.
    public static func apply(_ saturation: Double, to display: DisplaySummary, store: SaturationStore = .standard) throws {
        let value = min(max(saturation, SaturationAdjustment.range.lowerBound), SaturationAdjustment.range.upperBound)
        if abs(value - 1) < 0.005 {
            try reset(display, store: store)
            return
        }
        // 기준 프로파일: 이미 조정 중이면 저장해 둔 조정 전 프로파일, 아니면 현재 프로파일.
        let previous = activeEntry(for: display, store: store)
        let basePath: String, baseName: String, baseIsFactory: Bool
        let baseData: Data
        if let previous {
            (basePath, baseName, baseIsFactory) = (previous.basePath, previous.baseName, previous.baseIsFactoryDefault)
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: basePath)) else {
                throw DisplayChangeError.unavailable("조정 전 프로파일 파일을 읽을 수 없음: \(basePath)")
            }
            baseData = data
        } else {
            guard let current = ColorProfileService.current(for: display.id), let data = currentProfileData(display.id) else {
                throw DisplayChangeError.unavailable("현재 색 프로파일을 읽을 수 없음")
            }
            guard !current.path.isEmpty else { throw DisplayChangeError.unavailable("현재 색 프로파일의 파일 경로가 없어 해제 시 되돌릴 수 없음") }
            (basePath, baseName, baseIsFactory) = (current.path, current.name, current.isFactoryDefault)
            baseData = data
        }
        let adjusted: ICCProfile
        do {
            adjusted = try SaturationAdjustment.adjustedProfile(try ICCProfile(data: baseData), saturation: value, baseName: baseName)
        } catch {
            throw DisplayChangeError.unavailable("현재 프로파일은 채도 조정 대상이 아님: \(RevertCoordinator.describe(error))")
        }
        let folder = profilesFolder(store)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let percent = Int((value * 100).rounded())
        let target = folder.appendingPathComponent("saturation-\(ModeFavoritesStore.key(for: display.identity))-\(percent).icc")
        try adjusted.serialized().write(to: target, options: .atomic)
        if let problem = verify(target) {
            try? FileManager.default.removeItem(at: target)
            throw DisplayChangeError.unavailable("만든 프로파일이 ColorSync 검사를 통과하지 못함: \(problem)")
        }
        try ColorProfileService.set(ColorProfileInfo(name: "\(baseName) (채도 \(percent)%)", path: target.path, isFactoryDefault: false), for: display.id)
        try store.set(.init(basePath: basePath, baseName: baseName, baseIsFactoryDefault: baseIsFactory, saturation: value, generatedPath: target.path), for: display.identity)
        if let previous, previous.generatedPath != target.path { try? FileManager.default.removeItem(atPath: previous.generatedPath) }
    }

    /// 조정 해제: 조정 전 프로파일로 되돌리고 만든 파일 삭제. 조정이 없으면 변화 없음.
    public static func reset(_ display: DisplaySummary, store: SaturationStore = .standard) throws {
        guard let entry = store.entry(for: display.identity) else { return }
        // 그 사이 다른 프로파일로 바뀌었으면 프로파일은 건드리지 않고 기록만 정리.
        if ColorProfileService.current(for: display.id)?.path == entry.generatedPath {
            let base = entry.baseIsFactoryDefault ? nil : ColorProfileInfo(name: entry.baseName, path: entry.basePath, isFactoryDefault: false)
            try ColorProfileService.set(base, for: display.id)
        }
        try? FileManager.default.removeItem(atPath: entry.generatedPath)
        try store.set(nil, for: display.identity)
    }
}
