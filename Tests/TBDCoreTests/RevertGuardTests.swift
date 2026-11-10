import Foundation
import Testing
@testable import TBDCore

final class FakeTimer: RevertTimer {
    var startedSeconds: TimeInterval?
    var stopCount = 0
    private var onFire: (() -> Void)?

    func start(seconds: TimeInterval, onFire: @escaping () -> Void) {
        startedSeconds = seconds
        self.onFire = onFire
    }

    func stop() {
        stopCount += 1
        onFire = nil
    }

    func fire() {
        let action = onFire
        onFire = nil
        action?()
    }
}

struct TestFailure: Error, LocalizedError {
    var errorDescription: String? { "시험용 실패" }
}

/// TC-SAF-001: PRD 3절 상태 전이.
@Suite("TC-SAF-001 자동 복귀 상태 기계")
struct RevertStateMachineTests {
    func machine(after events: [RevertEvent]) -> RevertStateMachine {
        var m = RevertStateMachine()
        for e in events { _ = m.handle(e) }
        return m
    }

    @Test func 전이_9종이_표와_일치() {
        let cases: [(before: [RevertEvent], event: RevertEvent, state: RevertState, effects: [RevertEffect])] = [
            ([], .request, .applying, [.saveStateAndApply]),
            ([.request], .applySucceeded, .awaitingConfirmation, [.showConfirmationAndStartTimer]),
            ([.request], .applyFailed, .idle, [.reportApplyError, .deletePendingFile]),
            ([.request, .applySucceeded], .confirm, .idle, [.stopTimer, .commit, .deletePendingFile]),
            ([.request, .applySucceeded], .cancel, .reverting, [.stopTimer, .restore]),
            ([.request, .applySucceeded], .timerExpired, .reverting, [.restore]),
            ([.request, .applySucceeded], .targetDisconnected, .idle, [.stopTimer]),
            ([.request, .applySucceeded, .timerExpired], .revertSucceeded, .idle, [.reportReverted, .deletePendingFile]),
            ([.request, .applySucceeded, .timerExpired], .revertFailed, .idle, [.reportRevertError]),
        ]
        for c in cases {
            var m = machine(after: c.before)
            let effects = m.handle(c.event)
            #expect(m.state == c.state, "\(c.before) + \(c.event)")
            #expect(effects == c.effects, "\(c.before) + \(c.event)")
        }
    }

    @Test func 진행_중_새_요청은_거부() {
        for before in [[RevertEvent.request], [.request, .applySucceeded], [.request, .applySucceeded, .cancel]] {
            var m = machine(after: before)
            let state = m.state
            #expect(m.handle(.request) == [.rejectBusy])
            #expect(m.state == state)
        }
    }

    @Test func 해당_없는_이벤트는_무시() {
        var idle = RevertStateMachine()
        for event in [RevertEvent.confirm, .cancel, .timerExpired, .applySucceeded, .revertSucceeded, .targetDisconnected] {
            #expect(idle.handle(event).isEmpty)
            #expect(idle.state == .idle)
        }
        var applying = machine(after: [.request])
        #expect(applying.handle(.confirm).isEmpty)
        #expect(applying.handle(.timerExpired).isEmpty)
        #expect(applying.state == .applying)
    }
}

@Suite("TC-SAF-001 자동 복귀 실행기")
struct RevertCoordinatorTests {
    final class Recorder {
        var applied = 0, committed = 0, restored = 0
        var notices: [RevertCoordinator.Notice] = []
        var failApply = false, failRestore = false
    }

    func make(timeout: TimeInterval = 15, store: PendingRevertStore? = nil) -> (RevertCoordinator, FakeTimer, Recorder) {
        let timer = FakeTimer()
        let recorder = Recorder()
        let coordinator = RevertCoordinator(timeout: timeout, timer: timer, store: store)
        coordinator.onNotice = { recorder.notices.append($0) }
        return (coordinator, timer, recorder)
    }

    func change(_ r: Recorder, pending: PendingRevert? = nil) -> RevertCoordinator.Change {
        .init(
            summary: "시험 변경", pending: pending,
            apply: { if r.failApply { throw TestFailure() }; r.applied += 1 },
            commit: { r.committed += 1 },
            restore: { if r.failRestore { throw TestFailure() }; r.restored += 1 }
        )
    }

    @Test func 확인하면_확정() {
        let (c, timer, r) = make()
        #expect(c.request(change(r)))
        #expect(c.state == .awaitingConfirmation)
        #expect(timer.startedSeconds == 15)
        c.confirm()
        #expect(c.state == .idle)
        #expect((r.applied, r.committed, r.restored) == (1, 1, 0))
        #expect(r.notices == [.awaitingConfirmation(summary: "시험 변경", timeout: 15), .committed(summary: "시험 변경")])
        // 확정 뒤 타이머가 울려도 복귀 없음.
        timer.fire()
        #expect(r.restored == 0)
    }

    @Test func 타이머_만료_시_복귀_1회() {
        let (c, timer, r) = make(timeout: 7)
        c.request(change(r))
        #expect(timer.startedSeconds == 7)
        timer.fire()
        timer.fire()
        #expect(c.state == .idle)
        #expect((r.applied, r.committed, r.restored) == (1, 0, 1))
        #expect(r.notices.last == .reverted(summary: "시험 변경"))
    }

    @Test func 취소하면_복귀() {
        let (c, timer, r) = make()
        c.request(change(r))
        c.cancel()
        #expect(c.state == .idle)
        #expect(r.restored == 1)
        #expect(timer.stopCount == 1)
    }

    @Test func 확인_대기_중_새_요청_거부() {
        let (c, _, r) = make()
        c.request(change(r))
        #expect(!c.request(change(r)))
        #expect(r.applied == 1)
        #expect(r.notices.last == .rejectedBusy)
        #expect(c.state == .awaitingConfirmation)
    }

    @Test func 적용_실패는_오류_보고_후_대기_상태() {
        let (c, timer, r) = make()
        r.failApply = true
        c.request(change(r))
        #expect(c.state == .idle)
        #expect(timer.startedSeconds == nil)
        #expect(r.notices == [.applyFailed(summary: "시험 변경", message: "시험용 실패")])
        // 실패 뒤 새 요청 가능.
        r.failApply = false
        #expect(c.request(change(r)))
    }

    @Test func 복귀_실패는_오류_보고() {
        let (c, timer, r) = make()
        c.request(change(r))
        r.failRestore = true
        timer.fire()
        #expect(c.state == .idle)
        #expect(r.notices.last == .revertFailed(summary: "시험 변경", message: "시험용 실패"))
    }

    @Test func 대상_연결_해제_시_타이머_중단과_복귀_정보_유지() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("tbd-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = PendingRevertStore(fileURL: dir.appendingPathComponent("pending-revert.json"))
        let (c, timer, r) = make(store: store)
        let pending = PendingRevertStoreTests.sample
        c.request(change(r, pending: pending))
        #expect(store.load() == pending)
        c.targetDisconnected()
        #expect(c.state == .idle)
        #expect(timer.stopCount == 1)
        #expect(r.restored == 0)
        #expect(store.load() == pending)
        #expect(r.notices.last == .targetDisconnected(summary: "시험 변경"))
    }

    @Test func 복귀_정보_파일은_확정과_복귀_성공_시_삭제_복귀_실패_시_유지() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("tbd-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = PendingRevertStore(fileURL: dir.appendingPathComponent("pending-revert.json"))
        let pending = PendingRevertStoreTests.sample

        var (c, timer, r) = make(store: store)
        c.request(change(r, pending: pending))
        c.confirm()
        #expect(store.load() == nil)

        (c, timer, r) = make(store: store)
        c.request(change(r, pending: pending))
        timer.fire()
        #expect(store.load() == nil)

        (c, timer, r) = make(store: store)
        c.request(change(r, pending: pending))
        r.failRestore = true
        timer.fire()
        #expect(store.load() == pending)
    }
}

/// TC-SAF-002: 복귀 정보 파일.
@Suite("TC-SAF-002 복귀 정보 파일")
struct PendingRevertStoreTests {
    static let sample = PendingRevert(
        createdAt: Date(timeIntervalSince1970: 1_800_000_000),
        summary: "LG TV 모드 복귀",
        actions: [.displayMode(target: DisplayRef(uuid: "U-1", vendorID: 7789, productID: 49352, serialNumber: 1, name: "LG TV"), mode: ModeDescriptor(width: 2304, height: 1296, isHiDPI: true, refreshRate: 120))]
    )

    @Test func 기록_조회_삭제() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("tbd-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = PendingRevertStore(fileURL: dir.appendingPathComponent("nested/pending-revert.json"))
        #expect(store.load() == nil)
        try store.save(Self.sample)
        #expect(store.load() == Self.sample)
        store.clear()
        #expect(store.load() == nil)
        store.clear()
    }

    @Test func 손상_파일은_없음으로_처리() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("tbd-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("pending-revert.json")
        try Data("{ 손상".utf8).write(to: url)
        #expect(PendingRevertStore(fileURL: url).load() == nil)
    }

    @Test func 디스플레이_참조는_UUID_우선_제품_정보_차선() {
        let a = DisplaySelectorTests.display(2, "LG TV")
        var b = DisplaySelectorTests.display(5, "LG TV 2")
        b.identity.uuid = "U-1"
        b.identity.serialNumber = 99
        let ref = DisplayRef(uuid: "U-1", vendorID: 1, productID: 2, serialNumber: 3, name: "LG TV")
        #expect(ref.resolve(in: [a, b])?.id == 5)
        // UUID가 없으면 제조사, 제품 코드, 일련번호가 같은 유일한 디스플레이.
        #expect(DisplayRef(uuid: "없음", vendorID: 1, productID: 2, serialNumber: 3, name: "").resolve(in: [a, b])?.id == 2)
        #expect(DisplayRef(uuid: nil, vendorID: 9, productID: 9, serialNumber: 9, name: "").resolve(in: [a, b]) == nil)
        // 같은 식별 정보가 2대면 대응 불가.
        #expect(DisplayRef(uuid: nil, vendorID: 1, productID: 2, serialNumber: 3, name: "").resolve(in: [a, a]) == nil)
    }
}
