import CoreGraphics
import Foundation
import TBDCore

/// 전달 테이블 기반 소프트웨어 색 조정. 프로세스 수명 동안만 유지. (SRS-CLR-001, ADR-0004)
public final class GammaService: @unchecked Sendable {
    public static let shared = GammaService()

    private let lock = NSLock()
    private var adjustments: [CGDirectDisplayID: ColorAdjustment] = [:]
    /// 조정 전의 전달 테이블 (디스플레이 보정값). 조정 결과를 이 위에 합성.
    private var baselines: [CGDirectDisplayID: GammaTable] = [:]

    public init() {}

    public func adjustment(for display: CGDirectDisplayID) -> ColorAdjustment {
        lock.lock()
        defer { lock.unlock() }
        return adjustments[display] ?? .identity
    }

    /// 현재 전달 테이블 읽기.
    static func currentTable(_ display: CGDirectDisplayID) -> GammaTable? {
        let capacity = UInt32(GammaTable.defaultSize)
        var red = [CGGammaValue](repeating: 0, count: Int(capacity))
        var green = red, blue = red
        var count: UInt32 = 0
        guard CGGetDisplayTransferByTable(display, capacity, &red, &green, &blue, &count) == .success, count >= 2 else { return nil }
        return GammaTable(red: Array(red.prefix(Int(count))), green: Array(green.prefix(Int(count))), blue: Array(blue.prefix(Int(count))))
    }

    /// 현재 전달 테이블의 최댓값. XDR 밝기 업스케일 적용 확인에 사용.
    public static func currentTableMaximum(_ display: CGDirectDisplayID) -> Double? {
        guard let table = currentTable(display) else { return nil }
        return (table.red + table.green + table.blue).max().map(Double.init)
    }

    /// 마지막으로 적용한 테이블. 시스템이 테이블을 초기화했는지 판별하는 데 사용.
    private var applied: [CGDirectDisplayID: GammaTable] = [:]

    /// 조정 적용. 항등 값이면 해당 디스플레이의 테이블을 기준 테이블로 되돌림.
    public func apply(_ adjustment: ColorAdjustment, to display: CGDirectDisplayID) throws {
        lock.lock()
        defer { lock.unlock() }
        try applyLocked(adjustment, to: display)
    }

    private func applyLocked(_ adjustment: ColorAdjustment, to display: CGDirectDisplayID) throws {
        let clamped = adjustment.clamped()
        if baselines[display] == nil {
            baselines[display] = Self.currentTable(display) ?? .linear()
        }
        let baseline = baselines[display] ?? .linear()
        // XDR 배율은 기준 테이블 합성 뒤에 곱함 (합성 단계의 조회가 0-1 범위로 자르기 때문).
        let table = clamped.isIdentity ? baseline : GammaTable.make(clamped, size: baseline.red.count).composed(over: baseline).scaled(by: clamped.xdrBoost)
        let result = CGSetDisplayTransferByTable(display, UInt32(table.red.count), table.red, table.green, table.blue)
        guard result == .success else { throw DisplayChangeError.system(operation: "전달 테이블 지정", code: result.rawValue) }
        if clamped.isIdentity {
            adjustments[display] = nil
            baselines[display] = nil
            applied[display] = nil
        } else {
            adjustments[display] = clamped
            applied[display] = table
        }
    }

    /// 모든 디스플레이의 전달 테이블을 ColorSync 설정값으로 복원.
    public func resetAll() {
        lock.lock()
        defer { lock.unlock() }
        CGDisplayRestoreColorSyncSettings()
        adjustments.removeAll()
        baselines.removeAll()
        applied.removeAll()
    }

    static func approximatelyEqual(_ a: GammaTable, _ b: GammaTable) -> Bool {
        guard a.red.count == b.red.count else { return false }
        func close(_ x: [Float], _ y: [Float]) -> Bool { zip(x, y).allSatisfy { abs($0 - $1) < 0.004 } }
        return close(a.red, b.red) && close(a.green, b.green) && close(a.blue, b.blue)
    }

    /// 디스플레이 재구성 뒤 시스템이 테이블을 초기화했으면 조정 값 재적용.
    /// 현재 테이블이 마지막 적용 테이블과 같으면 아무것도 하지 않음 (같은 조정을 거듭 겹쳐 적용하지 않기 위함).
    public func reapply(onlineDisplays: [CGDirectDisplayID]) {
        lock.lock()
        defer { lock.unlock() }
        for display in Array(adjustments.keys) where !onlineDisplays.contains(display) {
            adjustments[display] = nil
            baselines[display] = nil
            applied[display] = nil
        }
        for (display, adjustment) in adjustments {
            guard let current = Self.currentTable(display), let last = applied[display], !Self.approximatelyEqual(current, last) else { continue }
            // 시스템이 초기화한 테이블이 새 기준.
            baselines[display] = current
            try? applyLocked(adjustment, to: display)
        }
    }
}
