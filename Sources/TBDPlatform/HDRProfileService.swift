import CoreGraphics
import Foundation
import TBDCore

/// SDR과 HDR 상태별 색 프로파일 적용. (SRS-CLR-006)
public enum HDRProfileService {
    /// 현재 HDR 상태에 맞는 프로파일로 전환. 전환했으면 적용한 프로파일 이름, 할 일이 없으면 nil.
    @discardableResult
    public static func applyIfNeeded(for display: DisplaySummary, store: HDRProfileStore = .standard) throws -> String? {
        let preference = store.preference(for: display.identity)
        guard !preference.isEmpty, HDRService.isSupported(display.id) else { return nil }
        let current = ColorProfileService.current(for: display.id)
        guard let path = preference.target(hdrEnabled: HDRService.isEnabled(display.id), currentPath: current?.path) else { return nil }
        let name = (ColorProfileService.available(for: display.id).first { $0.path == path })?.name ?? URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
        try ColorProfileService.set(ColorProfileInfo(name: name, path: path, isFactoryDefault: false), for: display.id)
        return name
    }
}
