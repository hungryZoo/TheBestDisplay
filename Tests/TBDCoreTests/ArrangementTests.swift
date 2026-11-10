import Foundation
import Testing
@testable import TBDCore

/// TC-ARR-003 일부, TC-ARR-004 일부: 배치 계산과 연결 해제 보호 (순수 로직).
@Suite("TC-ARR-003 배치 계산")
struct ArrangementPlannerTests {
    /// 실측 배치: LG TV(메인, 2304x1296) 아래에 내장(1147x745).
    let tv = DisplayFrame(id: 2, x: 0, y: 0, width: 2304, height: 1296)
    let builtin = DisplayFrame(id: 1, x: 625, y: 1296, width: 1147, height: 745)

    @Test func 메인_지정은_상대_배치를_유지한_평행_이동() throws {
        let planned = try #require(ArrangementPlanner.makeMain(1, frames: [tv, builtin]))
        let newBuiltin = try #require(planned.first { $0.id == 1 })
        let newTV = try #require(planned.first { $0.id == 2 })
        #expect((newBuiltin.x, newBuiltin.y) == (0, 0))
        #expect((newTV.x, newTV.y) == (-625, -1296))
        #expect(newTV.touches(newBuiltin))
        // 이미 메인인 디스플레이를 지정하면 변화 없음.
        #expect(ArrangementPlanner.makeMain(2, frames: [tv, builtin]) == [tv, builtin])
        #expect(ArrangementPlanner.makeMain(9, frames: [tv, builtin]) == nil)
    }

    @Test func 맞닿는_위치는_그대로_유지() throws {
        let moved = try #require(ArrangementPlanner.move(1, toX: 0, y: 1296, frames: [tv, builtin]))
        #expect(moved.first { $0.id == 1 } == DisplayFrame(id: 1, x: 0, y: 1296, width: 1147, height: 745))
        let right = try #require(ArrangementPlanner.move(1, toX: 2304, y: 100, frames: [tv, builtin]))
        #expect(right.first { $0.id == 1 }.map { ($0.x, $0.y) } ?? (0, 0) == (2304, 100))
    }

    @Test func 겹치는_위치는_가장_가까운_변으로_보정() throws {
        // TV 안쪽 왼쪽 위 근처: 왼쪽 변이 가장 가까움.
        let moved = try #require(ArrangementPlanner.move(1, toX: -1000, y: 100, frames: [tv, builtin]))
        let frame = try #require(moved.first { $0.id == 1 })
        #expect(!frame.overlaps(tv))
        #expect(frame.touches(tv))
        #expect((frame.x, frame.y) == (-1147, 100))
        // TV 한가운데: 겹치지 않는 가장 가까운 위치로.
        let center = try #require(ArrangementPlanner.move(1, toX: 600, y: 300, frames: [tv, builtin])?.first { $0.id == 1 })
        #expect(!center.overlaps(tv))
        #expect(center.touches(tv))
    }

    @Test func 떨어진_위치는_맞닿도록_보정() throws {
        let far = try #require(ArrangementPlanner.move(1, toX: 5000, y: 4000, frames: [tv, builtin])?.first { $0.id == 1 })
        #expect(far.touches(tv))
        #expect(!far.overlaps(tv))
        // 대각 방향으로 떨어져도 한 변을 공유 (모서리만 닿는 배치는 불가).
        let diagonal = try #require(ArrangementPlanner.move(1, toX: -3000, y: -3000, frames: [tv, builtin])?.first { $0.id == 1 })
        #expect(diagonal.touches(tv))
    }

    @Test func 세_대_배치에서_다른_디스플레이와_겹치지_않음() throws {
        let third = DisplayFrame(id: 3, x: 2304, y: 0, width: 1920, height: 1080)
        let moved = try #require(ArrangementPlanner.move(1, toX: 2400, y: 200, frames: [tv, builtin, third])?.first { $0.id == 1 })
        #expect(!moved.overlaps(tv))
        #expect(!moved.overlaps(third))
        #expect(moved.touches(tv) || moved.touches(third))
    }

    @Test func 한_대뿐이면_원점_고정() throws {
        let moved = try #require(ArrangementPlanner.move(2, toX: 300, y: 300, frames: [tv]))
        #expect(moved == [tv])
        #expect(ArrangementPlanner.move(9, toX: 0, y: 0, frames: [tv]) == nil)
    }

    @Test func 메인이_움직이면_원점으로_정규화() {
        let shifted = [DisplayFrame(id: 2, x: 100, y: 50, width: 2304, height: 1296), DisplayFrame(id: 1, x: 725, y: 1346, width: 1147, height: 745)]
        #expect(ArrangementPlanner.normalized(shifted, main: 2) == [tv, builtin])
    }

    @Test func 회전_값_검사() {
        for degrees in [0, 90, 180, 270] { #expect(ArrangementPlanner.isValidRotation(degrees)) }
        for degrees in [-90, 45, 360] { #expect(!ArrangementPlanner.isValidRotation(degrees)) }
    }

    @Test func 미리_보기_축척() {
        let layout = ArrangementPlanner.previewLayout([tv, builtin], width: 400, height: 300, padding: 10)
        // 전체 배치(2304 x 2041)가 영역 안에 들어감.
        #expect(layout.scale <= 380.0 / 2304 + 0.0001)
        #expect(Double(2041) * layout.scale <= 280.0001)
        #expect(layout.offsetX >= 10 - 0.0001)
        #expect(ArrangementPlanner.previewLayout([], width: 400, height: 300).scale == 1)
    }
}

@Suite("TC-ARR-004 연결 해제 보호")
struct DisconnectGuardTests {
    @Test func 마지막_온라인_디스플레이는_거부() {
        #expect(!ArrangementPlanner.canDisconnect(1, online: [1]))
        #expect(ArrangementPlanner.disconnectRefusal(1, online: [1])?.contains("마지막") == true)
        #expect(ArrangementPlanner.canDisconnect(2, online: [1, 2]))
        #expect(ArrangementPlanner.disconnectRefusal(2, online: [1, 2]) == nil)
        #expect(!ArrangementPlanner.canDisconnect(5, online: [1, 2]))
        #expect(ArrangementPlanner.disconnectRefusal(5, online: [1, 2]) != nil)
        #expect(!ArrangementPlanner.canDisconnect(1, online: []))
    }

    @Test func 미러_설정_거부_조건() {
        let a = DisplaySelectorTests.display(1, "A")
        var b = DisplaySelectorTests.display(2, "B")
        #expect(ArrangementPlanner.mirrorRefusal(display: 1, master: 2, displays: [a, b]) == nil)
        #expect(ArrangementPlanner.mirrorRefusal(display: 1, master: 1, displays: [a, b]) != nil)
        #expect(ArrangementPlanner.mirrorRefusal(display: 1, master: 9, displays: [a, b]) != nil)
        #expect(ArrangementPlanner.mirrorRefusal(display: 9, master: 2, displays: [a, b]) != nil)
        b.mirrorsDisplayID = 3
        #expect(ArrangementPlanner.mirrorRefusal(display: 1, master: 2, displays: [a, b])?.contains("미러 중") == true)
    }

    @Test func 복귀_동작_직렬화() throws {
        let ref = DisplayRef(uuid: "U", vendorID: 1, productID: 2, serialNumber: 3, name: "TV")
        let pending = PendingRevert(createdAt: Date(timeIntervalSince1970: 1_800_000_000), summary: "복귀", actions: [
            .rotation(target: ref, degrees: 90), .mirror(target: ref, master: nil), .mirror(target: ref, master: ref), .reconnect(displayID: 2, name: "TV"), .hdr(target: ref, enabled: true),
        ])
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        #expect(try decoder.decode(PendingRevert.self, from: encoder.encode(pending)) == pending)
    }
}
