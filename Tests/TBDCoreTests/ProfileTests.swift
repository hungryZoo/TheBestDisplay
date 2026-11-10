import Foundation
import Testing
@testable import TBDCore

enum ProfileFixture {
    static let tvRef = DisplayRef(RegistryFixture.lgTV.identity)
    static let builtinRef = DisplayRef(RegistryFixture.builtin.identity)

    static func tvEntry(mode: ModeDescriptor = ModeDescriptor(width: 2304, height: 1296, isHiDPI: true, refreshRate: 120), hdr: Bool? = true, color: ColorDescriptor? = ColorDescriptor(pixelEncoding: .ycbcr422, bitsPerComponent: 12, eotf: .pq, dynamicRange: .limited, colorimetry: 7), rotation: Int = 0, x: Int = 0, y: Int = 0, main: Bool = true, mirror: DisplayRef? = nil) -> DisplayProfileEntry {
        DisplayProfileEntry(ref: tvRef, mode: mode, color: color, hdrEnabled: hdr, rotation: rotation, originX: x, originY: y, isMain: main, mirrorOf: mirror, brightness: nil)
    }

    static func builtinEntry(x: Int = 625, y: Int = 1296, main: Bool = false, brightness: Double? = 0.7) -> DisplayProfileEntry {
        DisplayProfileEntry(ref: builtinRef, mode: ModeDescriptor(width: 1147, height: 745, isHiDPI: true, refreshRate: 120, isVRR: true), color: nil, hdrEnabled: nil, rotation: 0, originX: x, originY: y, isMain: main, mirrorOf: nil, brightness: brightness)
    }

    static func profile(_ name: String = "사무실", _ entries: [DisplayProfileEntry]? = nil) -> DisplayProfile {
        DisplayProfile(name: name, createdAt: Date(timeIntervalSince1970: 1_800_000_000), displays: entries ?? [tvEntry(), builtinEntry()])
    }

    static let displays = [RegistryFixture.lgTV, RegistryFixture.builtin]
}

/// TC-PRF-001: 프로파일 직렬화, 저장소, 디스플레이 대응.
@Suite("TC-PRF-001 프로파일 저장과 대응")
struct ProfileStoreTests {
    func store() -> (ProfileStore, URL) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("tbd-test-\(UUID().uuidString)")
        return (ProfileStore(fileURL: dir.appendingPathComponent("nested/profiles.json")), dir)
    }

    @Test func JSON_왕복() throws {
        let (s, dir) = store()
        defer { try? FileManager.default.removeItem(at: dir) }
        #expect(s.load().isEmpty)
        let profile = ProfileFixture.profile()
        try s.add(profile)
        #expect(s.load() == [profile])
        #expect(s.find(named: "사무실") == profile)
        #expect(s.load().first?.version == DisplayProfile.currentVersion)
        #expect(profile.displays[0].summary == "LG TV SSCR2: 2304 x 1296 HiDPI 120 Hz, HDR 켜짐, 메인")
    }

    @Test func 추가_이름_변경_삭제() throws {
        let (s, dir) = store()
        defer { try? FileManager.default.removeItem(at: dir) }
        let a = try s.add(ProfileFixture.profile("  사무실  "))
        #expect(a.name == "사무실")
        #expect(throws: ProfileStore.StoreError.duplicateName("사무실")) { try s.add(ProfileFixture.profile("사무실")) }
        #expect(throws: ProfileStore.StoreError.emptyName) { try s.add(ProfileFixture.profile("   ")) }
        // 교체 허용 시 같은 이름을 덮어씀.
        let replacement = ProfileFixture.profile("사무실", [ProfileFixture.builtinEntry()])
        try s.add(replacement, replace: true)
        #expect(s.load().count == 1)
        #expect(s.load()[0].displays.count == 1)

        let b = try s.add(ProfileFixture.profile("집"))
        try s.rename(b.id, to: "재택")
        #expect(s.load().map(\.name) == ["사무실", "재택"])
        #expect(throws: ProfileStore.StoreError.duplicateName("사무실")) { try s.rename(b.id, to: "사무실") }
        #expect(throws: ProfileStore.StoreError.self) { try s.rename(UUID(), to: "없음") }
        try s.delete(b.id)
        #expect(s.load().map(\.name) == ["사무실"])
        #expect(throws: ProfileStore.StoreError.self) { try s.delete(b.id) }
    }

    @Test func 손상_파일과_상위_판_번호() throws {
        let (s, dir) = store()
        defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: s.fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("{ 손상".utf8).write(to: s.fileURL)
        #expect(s.load().isEmpty)
        var future = ProfileFixture.profile("미래")
        future.version = DisplayProfile.currentVersion + 1
        try s.save([future, ProfileFixture.profile("현재")])
        #expect(s.load().map(\.name) == ["현재"])
    }

    @Test func 디스플레이_대응_UUID_우선() {
        // UUID가 같으면 제품 정보가 달라도 대응.
        var moved = RegistryFixture.lgTV
        moved.identity.serialNumber = 999
        let byUUID = ProfilePlanner.match(ProfileFixture.profile(), displays: [moved, RegistryFixture.builtin])
        #expect(byUUID.map { $0.display?.id } == [2, 1])
        // UUID가 달라도 제조사, 제품 코드, 일련번호가 같으면 대응.
        var reconnected = RegistryFixture.lgTV
        reconnected.identity.uuid = "NEW-UUID"
        reconnected.identity.displayID = 7
        let byProduct = ProfilePlanner.match(ProfileFixture.profile(), displays: [reconnected, RegistryFixture.builtin])
        #expect(byProduct.map { $0.display?.id } == [7, 1])
        // 전부 다르면 대응 없음.
        var other = RegistryFixture.lgTV
        other.identity.uuid = "X"
        other.identity.productID = 1
        let none = ProfilePlanner.match(ProfileFixture.profile(), displays: [other])
        #expect(none.map { $0.display?.id } == [nil, nil])
    }
}

/// TC-PRF-002 일부: 적용 계획 (순수 로직).
@Suite("TC-PRF-002 프로파일 적용 계획")
struct ProfilePlannerTests {
    @Test func 같은_구성이면_단계_없음() {
        let profile = ProfileFixture.profile()
        let plan = ProfilePlanner.plan(profile, current: profile, displays: ProfileFixture.displays)
        #expect(plan.steps.isEmpty)
        #expect(plan.unmatched.isEmpty)
    }

    @Test func 차이만_단계로_산출하고_순서_유지() {
        let saved = ProfileFixture.profile()
        // 현재: TV가 60 Hz, HDR 꺼짐, RGB, 회전 90도. 내장은 왼쪽 배치, 밝기 다름.
        let current = ProfileFixture.profile("현재", [
            ProfileFixture.tvEntry(mode: ModeDescriptor(width: 2304, height: 1296, isHiDPI: true, refreshRate: 60), hdr: false, color: ColorDescriptor(pixelEncoding: .rgb444, bitsPerComponent: 8, eotf: .sdr, dynamicRange: .full, colorimetry: 16), rotation: 90),
            ProfileFixture.builtinEntry(x: -1147, y: 0, brightness: 0.4),
        ])
        let plan = ProfilePlanner.plan(saved, current: current, displays: ProfileFixture.displays)
        #expect(plan.steps.map(\.kind) == [.rotation, .mode, .hdr, .color, .arrangement, .brightness])
        #expect(plan.steps.map(\.displayName) == ["LG TV SSCR2", "LG TV SSCR2", "LG TV SSCR2", "LG TV SSCR2", "전체", "내장 디스플레이"])
        #expect(plan.steps[1].detail == "2304 x 1296 HiDPI, 120 Hz")
        #expect(plan.steps[2].detail == "켜기")
        #expect(plan.steps[3].detail == "YCbCr 4:2:2, 12 bpc, Limited, PQ (HDR10)")
        #expect(plan.steps[5].detail == "70%")
        // 단계 종류의 정의 순서: HDR이 색 모드보다 먼저, 회전이 모드보다 먼저.
        let order = ProfileStepKind.allCases
        #expect(order.firstIndex(of: .hdr)! < order.firstIndex(of: .color)!)
        #expect(order.firstIndex(of: .rotation)! < order.firstIndex(of: .mode)!)
        #expect(order.firstIndex(of: .mode)! < order.firstIndex(of: .color)!)
    }

    @Test func 모드나_HDR이_바뀌면_색_모드가_같아도_색_모드_단계_포함() {
        let saved = ProfileFixture.profile()
        let current = ProfileFixture.profile("현재", [ProfileFixture.tvEntry(mode: ModeDescriptor(width: 1920, height: 1080, isHiDPI: true, refreshRate: 120)), ProfileFixture.builtinEntry()])
        let plan = ProfilePlanner.plan(saved, current: current, displays: ProfileFixture.displays)
        #expect(plan.steps.map(\.kind) == [.mode, .color])
    }

    @Test func 미러와_메인_변경() {
        let saved = ProfileFixture.profile("미러", [ProfileFixture.tvEntry(main: false, mirror: ProfileFixture.builtinRef), ProfileFixture.builtinEntry(x: 0, y: 0, main: true)])
        let plan = ProfilePlanner.plan(saved, current: ProfileFixture.profile(), displays: ProfileFixture.displays)
        #expect(plan.steps.map(\.kind) == [.mirror, .arrangement])
        #expect(plan.steps[0].detail == "내장 디스플레이 미러")
        // 미러 대상은 배치 설명에서 제외.
        #expect(plan.steps[1].detail == "내장 디스플레이 (0, 0) 메인")
        let back = ProfilePlanner.plan(ProfileFixture.profile(), current: saved, displays: ProfileFixture.displays)
        #expect(back.steps.first?.detail == "미러 해제")
    }

    @Test func 연결되지_않은_디스플레이는_대응_없음으로_보고() {
        let plan = ProfilePlanner.plan(ProfileFixture.profile(), current: ProfileFixture.profile("현재", [ProfileFixture.builtinEntry(x: 0, y: 0, main: true)]), displays: [RegistryFixture.builtin])
        #expect(plan.unmatched.map(\.ref.name) == ["LG TV SSCR2"])
        // 남은 내장 디스플레이의 배치 차이만 단계로.
        #expect(plan.steps.map(\.kind) == [.arrangement])
    }

    @Test func 결과_문구() {
        #expect(ProfileStepResult.Outcome.applied.title == "적용")
        #expect(ProfileStepResult.Outcome.unchanged.title == "변경 없음")
        #expect(ProfileStepResult(kind: .hdr, displayName: "TV", outcome: .failed, detail: "x").id == "hdr|TV")
        #expect(ProfileStepKind.allCases.map(\.title) == ["미러", "회전", "모드", "HDR", "색 모드", "배치", "밝기"])
    }
}
