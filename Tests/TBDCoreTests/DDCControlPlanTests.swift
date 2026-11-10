import Foundation
import Testing
@testable import TBDCore

/// TC-DDC-006: capabilities 기반 제어 구성.
@Suite("TC-DDC-006 capabilities 기반 제어 구성")
struct DDCControlPlanTests {
    /// 일반 모니터의 capabilities 문자열 형식을 따른 합성 자료 (제조사 정의 코드 E0, F4 포함).
    static let sample = "(prot(monitor)type(lcd)model(SAMPLE27)cmds(01 02 03 07 0C E3 F3)vcp(02 04 05 08 10 12 14(05 08 0B) 16 18 1A 52 60(0F 11 12 1B) 62 8D(01 02) AC AE B6 C8 D6(01 04 05) DC(00 03 05) DF E0 F4(01 02))mswhql(1)mccs_ver(2.1))"

    @Test func 지원_코드만_표준_순서로_구성() {
        let controls = DDCControlPlan.controls(for: DDCCapabilities.parse(Self.sample))
        #expect(controls.map(\.code) == [0x12, 0x16, 0x18, 0x1A, 0x62, 0x8D, 0x14, 0xDC, 0x60, 0xD6])
        #expect(controls.map(\.title) == ["대비", "게인 (빨강)", "게인 (초록)", "게인 (파랑)", "볼륨", "음소거", "색 프리셋", "화면 모드", "입력 소스", "전원 모드"])
        // 밝기는 밝기 조절 막대가 담당.
        #expect(!controls.contains { $0.code == 0x10 })
    }

    @Test func 연속_값과_선택_값_구분() throws {
        let controls = DDCControlPlan.controls(for: DDCCapabilities.parse(Self.sample))
        #expect(controls.filter(\.isContinuous).map(\.code) == [0x12, 0x16, 0x18, 0x1A, 0x62])
        let preset = try #require(controls.first { $0.code == 0x14 })
        #expect(preset.options == [.init(value: 0x05, name: "6500 K"), .init(value: 0x08, name: "9300 K"), .init(value: 0x0B, name: "사용자 1")])
        let mode = try #require(controls.first { $0.code == 0xDC })
        #expect(mode.options.map(\.name) == ["표준", "영화", "게임"])
    }

    @Test func 선택값은_capabilities가_알린_값만_표기하고_이름_없는_값은_숫자로() throws {
        let controls = DDCControlPlan.controls(for: DDCCapabilities.parse(Self.sample))
        let input = try #require(controls.first { $0.code == 0x60 })
        #expect(input.options.map(\.name) == ["DisplayPort 1", "HDMI 1", "HDMI 2", "값 0x1B"])
        #expect(input.isDisruptive)
        let power = try #require(controls.first { $0.code == 0xD6 })
        #expect(power.options.map(\.value) == [0x01, 0x04, 0x05])
        #expect(power.isDisruptive)
        #expect(controls.filter(\.isDisruptive).map(\.code) == [0x60, 0xD6])
    }

    @Test func 선택값을_알리지_않은_코드는_표준_값_전체() throws {
        let caps = DDCCapabilities.parse("(vcp(10 60 8D D6)mccs_ver(2.2))")
        let controls = DDCControlPlan.controls(for: caps)
        #expect(controls.map(\.code) == [0x8D, 0x60, 0xD6])
        let input = try #require(controls.first { $0.code == 0x60 })
        #expect(input.options.count == 18)
        #expect(input.options.last == .init(value: 0x12, name: "HDMI 2"))
        #expect(controls[0].options.map(\.name) == ["음소거", "음소거 해제"])
    }

    @Test func 그_밖의_코드_목록() {
        let caps = DDCCapabilities.parse(Self.sample)
        #expect(DDCControlPlan.otherCodes(in: caps) == [0x02, 0x04, 0x05, 0x08, 0x52, 0xAC, 0xAE, 0xB6, 0xC8, 0xDF, 0xE0, 0xF4])
    }

    @Test func 빈_capabilities는_항목_없음() {
        #expect(DDCControlPlan.controls(for: DDCCapabilities.parse("")).isEmpty)
        #expect(DDCControlPlan.controls(for: DDCCapabilities.parse("(prot(monitor)type(lcd))")).isEmpty)
        #expect(DDCControlPlan.otherCodes(in: DDCCapabilities.parse("")).isEmpty)
    }

    @Test func 이름과_요약_행() throws {
        #expect(DDCControlPlan.title(for: 0x10) == "밝기")
        #expect(DDCControlPlan.title(for: 0x87) == "선명도")
        #expect(DDCControlPlan.title(for: 0xE0) == nil)
        let controls = DDCControlPlan.controls(for: DDCCapabilities.parse(Self.sample))
        #expect(DDCControlPlan.describe(controls[0]) == "0x12 대비: 조절 막대")
        let power = try #require(controls.last)
        #expect(DDCControlPlan.describe(power) == "0xD6 전원 모드: 선택: 켜짐(01), 꺼짐 (소프트)(04), 꺼짐 (전원)(05) [화면 출력이 끊길 수 있음]")
    }

    @Test func 표준_목록에_중복_코드_없음() {
        let codes = DDCControlPlan.catalog.map(\.code)
        #expect(Set(codes).count == codes.count)
        #expect(!codes.contains(0x10))
    }
}
