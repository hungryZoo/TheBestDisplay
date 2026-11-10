import Foundation
import TBDCore

/// 복귀 정보 파일에 기록된 동작 수행. (SRS-SAF-002)
public enum PendingRevertApplier {
    public static func apply(_ pending: PendingRevert, displays: [DisplaySummary]) throws {
        for action in pending.actions {
            switch action {
            case .displayMode(let target, let mode):
                guard let display = target.resolve(in: displays) else { throw DisplayChangeError.displayNotFound }
                try ModeService.setMode(matching: mode, on: display.id, permanently: true)
            case .colorMode(let target, let color):
                guard let display = target.resolve(in: displays) else { throw DisplayChangeError.displayNotFound }
                try SignalService.setColorMode(matching: color, for: display)
            case .hdr(let target, let enabled):
                guard let display = target.resolve(in: displays) else { throw DisplayChangeError.displayNotFound }
                try HDRService.setEnabled(enabled, on: display.id)
            }
        }
    }
}
