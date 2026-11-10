import Foundation
import Testing
@testable import TBDCore

/// TC-COL-006: DSC 켜기와 끄기 계획.
@Suite("TC-COL-006 DSC 전환 계획")
struct DSCControlTests {
    static func element(_ id: Int, _ encoding: PixelEncoding, _ bpc: Int, eotf: EOTF = .sdr, range: DynamicRange = .full, score: Int? = nil, virtual: Bool = false) -> ColorElement {
        ColorElement(id: id, pixelEncoding: encoding, bitsPerComponent: bpc, eotf: eotf, dynamicRange: range, colorimetry: 16, supportsDSC: true, isVirtual: virtual, score: score)
    }

    static func timing(id: Int, hz: Double, colors: [ColorElement], dsc: [Int], unsafe: [Int] = []) -> TimingElement {
        TimingElement(
            id: id, hActive: 3840, hTotal: 4000, hFrontPorch: 48, hSyncWidth: 32, hBackPorch: 80,
            vActive: 2160, vTotal: 2222, vFrontPorch: 3, vSyncWidth: 5, vBackPorch: 54,
            refreshRate: hz, isInterlaced: false, isPreferred: false, isVirtual: false,
            colorModes: colors, dscRequiredColorElementIDs: dsc, unsafeColorElementIDs: unsafe,
            minVariableRefreshRate: 0, maxVariableRefreshRate: 0
        )
    }

    /// 4K 144 Hz: RGB 10 bpc와 RGB 8 bpc(DSC), YCbCr 4:2:2 10 bpc와 RGB 8 bpc(비압축 후보는 4:2:2뿐), PQ 형식 2개.
    static func signal(current: Int) -> SignalInfo {
        let colors = [
            element(10, .rgb444, 10, score: 90),          // DSC
            element(11, .rgb444, 8, score: 80),           // DSC
            element(12, .ycbcr422, 10, score: 40),        // 비압축
            element(13, .ycbcr420, 8, score: 20),         // 비압축
            element(14, .ycbcr420, 10, score: 30),        // 비압축, 안전하지 않음
            element(20, .rgb444, 10, eotf: .pq, score: 95),      // DSC
            element(21, .ycbcr422, 10, eotf: .pq, range: .limited, score: 50), // 비압축
            element(1, .rgb444, 8, virtual: true),
        ]
        let t144 = timing(id: 5, hz: 144, colors: colors, dsc: [10, 11, 20], unsafe: [14])
        let t60 = timing(id: 6, hz: 60, colors: [element(30, .rgb444, 10), element(31, .rgb444, 8)], dsc: [])
        return SignalInfo(displayID: 9, timings: [t144, t60], sinkColorElements: [], currentTimingID: 5, currentColorID: current, linkData: nil, transport: "DP")
    }

    @Test func DSC_끄기는_같은_전달_함수의_비압축_모드_중_점수가_높은_것_선택() throws {
        let target = try DSCControl.plan(signal: Self.signal(current: 10), enable: false).get()
        #expect(target.id == 12)
        // 안전하지 않은 형식과 가상 형식은 후보에서 제외.
        #expect(DSCControl.candidates(signal: Self.signal(current: 10), usingDSC: false).map(\.id) == [12, 13, 21])
    }

    @Test func DSC_켜기는_같은_전달_함수의_압축_모드_선택() throws {
        #expect(try DSCControl.plan(signal: Self.signal(current: 12), enable: true).get().id == 10)
        // PQ 상태에서는 PQ 형식 안에서만 전환.
        #expect(try DSCControl.plan(signal: Self.signal(current: 21), enable: true).get().id == 20)
        #expect(try DSCControl.plan(signal: Self.signal(current: 20), enable: false).get().id == 21)
    }

    @Test func 이미_요청한_상태면_거부() {
        #expect(DSCControl.plan(signal: Self.signal(current: 10), enable: true) == .failure(.alreadyInState(enabled: true)))
        #expect(DSCControl.plan(signal: Self.signal(current: 12), enable: false) == .failure(.alreadyInState(enabled: false)))
        let availability = DSCControl.availability(signal: Self.signal(current: 10))
        #expect(availability.canEnable == false)
        #expect(availability.canDisable == true)
    }

    @Test func 현재_모드를_모르면_거부() {
        var info = Self.signal(current: 10)
        info.currentColorID = nil
        #expect(DSCControl.plan(signal: info, enable: false) == .failure(.unknownCurrentMode))
        info.currentColorID = 10
        info.currentTimingID = nil
        #expect(DSCControl.plan(signal: info, enable: true) == .failure(.unknownCurrentMode))
    }

    @Test func 후보가_없을_때의_사유() throws {
        // 60 Hz 타이밍에는 DSC 사용 모드가 없고 다른 타이밍에 있음.
        var at60 = Self.signal(current: 30)
        at60.currentTimingID = 6
        guard case .failure(.noCandidate(let enable, let reason)) = DSCControl.plan(signal: at60, enable: true) else {
            Issue.record("거부 기대")
            return
        }
        #expect(enable == true)
        #expect(reason.contains("현재 타이밍(3840 x 2160, 60 Hz)에는 DSC 사용 색 모드 없음"))

        // 모든 색 모드가 DSC 필요한 타이밍. 다른 타이밍에는 비압축 모드가 있음.
        let all = [Self.element(10, .rgb444, 10), Self.element(11, .rgb444, 8)]
        let onlyDSC = SignalInfo(
            displayID: 9,
            timings: [Self.timing(id: 5, hz: 240, colors: all, dsc: [10, 11]), Self.timing(id: 6, hz: 60, colors: all, dsc: [])],
            sinkColorElements: [], currentTimingID: 5, currentColorID: 10, linkData: nil, transport: "DP"
        )
        guard case .failure(.noCandidate(_, let reason2)) = DSCControl.plan(signal: onlyDSC, enable: false) else {
            Issue.record("거부 기대")
            return
        }
        #expect(reason2.contains("해상도 또는 주사율을 낮추면 DSC 미사용 모드 선택 가능"))

        // 전달 함수가 다른 후보만 있는 경우.
        let pqOnly = SignalInfo(
            displayID: 9,
            timings: [Self.timing(id: 5, hz: 144, colors: [Self.element(10, .rgb444, 10), Self.element(21, .ycbcr422, 10, eotf: .pq)], dsc: [10])],
            sinkColorElements: [], currentTimingID: 5, currentColorID: 10, linkData: nil, transport: "DP"
        )
        guard case .failure(.noCandidate(_, let reason3)) = DSCControl.plan(signal: pqOnly, enable: false) else {
            Issue.record("거부 기대")
            return
        }
        #expect(reason3.contains("HDR 상태를 바꾸면 후보 1개 선택 가능"))
    }

    @Test func 실측_픽스처는_DSC_켜기_불가() throws {
        let info = try SignalFixture.lgTV()
        guard case .failure(.noCandidate(_, let reason)) = DSCControl.plan(signal: info, enable: true) else {
            Issue.record("거부 기대")
            return
        }
        #expect(reason == "시스템이 이 연결에 DSC 사용 색 모드를 제공하지 않음 (싱크 또는 중간 장치의 DSC 미지원)")
        #expect(DSCControl.plan(signal: info, enable: false) == .failure(.alreadyInState(enabled: false)))
    }
}
