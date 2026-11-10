import Foundation
import Testing
@testable import TBDCore

enum RegistryFixture {
    static func nodes(_ folder: String, _ className: String) throws -> [[String: Any]] {
        let data = try Fixture.data("\(folder)/\(className).plist")
        return try #require(try PropertyListSerialization.propertyList(from: data, format: nil) as? [[String: Any]])
    }

    static let normal = "ioreg_normal_dock_lg_tv"
    /// T04 사고 시점: HPD High, 싱크 수 0, 링크 없음.
    static let noLink = "ioreg_hpd_high_no_link"
}

/// TC-LNK-002: 대역폭 계산.
@Suite("TC-LNK-002 대역폭 계산")
struct BandwidthCalculatorTests {
    func round2(_ v: Double) -> Double { (v * 100).rounded() / 100 }

    @Test func 필요_대역폭() {
        let clock = 1_071_360_000.0
        #expect(round2(BandwidthCalculator.requiredGbps(pixelClockHz: clock, encoding: .ycbcr422, bitsPerComponent: 12)) == 25.71)
        #expect(round2(BandwidthCalculator.requiredGbps(pixelClockHz: clock, encoding: .rgb444, bitsPerComponent: 10)) == 32.14)
        #expect(round2(BandwidthCalculator.requiredGbps(pixelClockHz: clock, encoding: .rgb444, bitsPerComponent: 8)) == 25.71)
        #expect(round2(BandwidthCalculator.requiredGbps(pixelClockHz: clock, encoding: .ycbcr420, bitsPerComponent: 10)) == 16.07)
        #expect(round2(BandwidthCalculator.requiredGbps(pixelClockHz: clock, encoding: .ycbcr444, bitsPerComponent: 12)) == 38.57)
    }

    @Test func DP_유효_대역폭() {
        #expect(round2(BandwidthCalculator.dpAvailableGbps(laneRateGbps: 8.1, laneCount: 4)) == 25.92)
        #expect(round2(BandwidthCalculator.dpAvailableGbps(laneRateGbps: 5.4, laneCount: 4)) == 17.28)
        #expect(round2(BandwidthCalculator.dpAvailableGbps(laneRateGbps: 8.1, laneCount: 2)) == 12.96)
        #expect(round2(BandwidthCalculator.dpAvailableGbps(laneRateGbps: 10, laneCount: 4)) == 38.79)
        #expect(round2(BandwidthCalculator.dpAvailableGbps(laneRateGbps: 20, laneCount: 4)) == 77.58)
        #expect(BandwidthCalculator.dpEncodingName(laneRateGbps: 8.1) == "8b/10b")
        #expect(BandwidthCalculator.dpEncodingName(laneRateGbps: 13.5) == "128b/132b")
    }

    @Test func HDMI_유효_대역폭과_문자_속도() {
        #expect(round2(BandwidthCalculator.frlAvailableGbps(totalGbps: 48)) == 42.67)
        #expect(round2(BandwidthCalculator.frlAvailableGbps(totalGbps: 40)) == 35.56)
        #expect(round2(BandwidthCalculator.tmdsAvailableGbps(characterRateMHz: 600)) == 14.4)
        // 4K 60 Hz(594 MHz): RGB 8 bpc는 594, RGB 10 bpc는 742.5, 4:2:2는 594, 4:2:0 8 bpc는 297.
        #expect(BandwidthCalculator.tmdsCharacterRateMHz(pixelClockHz: 594e6, encoding: .rgb444, bitsPerComponent: 8) == 594)
        #expect(BandwidthCalculator.tmdsCharacterRateMHz(pixelClockHz: 594e6, encoding: .rgb444, bitsPerComponent: 10) == 742.5)
        #expect(BandwidthCalculator.tmdsCharacterRateMHz(pixelClockHz: 594e6, encoding: .ycbcr422, bitsPerComponent: 12) == 594)
        #expect(BandwidthCalculator.tmdsCharacterRateMHz(pixelClockHz: 594e6, encoding: .ycbcr420, bitsPerComponent: 8) == 297)
    }
}

/// TC-LNK-001 일부: 전송 상태 노드 해석 (픽스처).
@Suite("TC-LNK-001 전송 상태 해석")
struct DPTransportStateTests {
    @Test func 정상_상태() throws {
        let states = try RegistryFixture.nodes(RegistryFixture.normal, "IOPortTransportStateDisplayPort").compactMap(DPTransportState.decode)
        #expect(states.count == 2)
        let active = try #require(states.first { $0.isActive })
        #expect(active.transportDescription == "Port-USB-C@4/CIO/DisplayPort@0")
        #expect(active.laneRateGbps == 8.1)
        #expect(active.rateName == "HBR3")
        #expect(active.laneCount == 4)
        #expect(active.maxLaneCount == 4)
        #expect(active.isTunneled)
        #expect(active.hpdAsserted)
        #expect(active.hasLink)
        #expect(active.sinkCount == 1)
        #expect(active.parentPortType == "USB-C")
        #expect(active.parentPortNumber == 4)
        #expect(active.productName == "LG TV SSCR2")
        #expect(active.downstreamPortType == "DP")
        #expect(active.edid?.count == 384)
        let lg = DisplayIdentity(displayID: 2, uuid: nil, vendorID: 7789, productID: 49352, serialNumber: 16843009, name: "LG TV SSCR2", isBuiltin: false)
        #expect(active.matches(lg))
        #expect(!active.matches(DisplayIdentity(displayID: 3, uuid: nil, vendorID: 1, productID: 2, serialNumber: 3, name: "다른 모니터", isBuiltin: false)))

        let hdmi = try #require(states.first { $0.parentPortType == "HDMI" })
        #expect(!hdmi.isActive)
        #expect(!hdmi.hasLink)
        #expect(!hdmi.hpdAsserted)
        #expect(hdmi.laneRateGbps == nil)
    }

    @Test func 사고_시점_상태는_HPD만_감지() throws {
        let states = try RegistryFixture.nodes(RegistryFixture.noLink, "IOPortTransportStateDisplayPort").compactMap(DPTransportState.decode)
        let usbc = try #require(states.first { $0.parentPortType == "USB-C" })
        #expect(usbc.hpdAsserted)
        #expect(!usbc.isActive)
        #expect(!usbc.hasLink)
        #expect(usbc.sinkCount == 0)
        #expect(usbc.linkRateDescription == "No Link")
        #expect(usbc.isTunneled)
    }

    @Test func 속도_이름() {
        #expect(DPTransportState.rateName(1.62) == "RBR")
        #expect(DPTransportState.rateName(5.4) == "HBR2")
        #expect(DPTransportState.rateName(13.5) == "UHBR13.5")
        #expect(DPTransportState.rateName(6.21) == "6.21 Gbps")
    }
}

@Suite("TC-LNK-002 링크 보고")
struct LinkAnalyzerTests {
    func lgDisplay() -> DisplaySummary {
        DisplaySelectorTests.display(2, "LG TV SSCR2")
    }

    func activeState() throws -> DisplayPortFixture {
        let states = try RegistryFixture.nodes(RegistryFixture.normal, "IOPortTransportStateDisplayPort").compactMap(DPTransportState.decode)
        return DisplayPortFixture(state: try #require(states.first { $0.isActive }))
    }

    struct DisplayPortFixture { var state: DPTransportState }

    @Test func 실측_구성의_대역폭과_사용률() throws {
        let signal = try SignalFixture.lgTV()
        let report = LinkAnalyzer.report(display: lgDisplay(), signal: signal, state: try activeState().state, dscActive: false, fecEnabled: nil)
        #expect(report.transportName == "DisplayPort")
        #expect(report.rawGbps == 32.4)
        #expect(abs(try #require(report.availableGbps) - 25.92) < 0.001)
        #expect(report.encodingName == "8b/10b")
        // 현재 색 모드 122: YCbCr 4:2:2 12 bpc.
        #expect(abs(try #require(report.requiredGbps) - 25.71) < 0.01)
        #expect(abs(try #require(report.utilization) - 0.992) < 0.001)
        #expect(report.notes.contains { $0.contains("터널") })
    }

    @Test func RGB_10_bpc는_대역폭_초과로_선택_불가() throws {
        let signal = try SignalFixture.lgTV()
        let report = LinkAnalyzer.report(display: lgDisplay(), signal: signal, state: try activeState().state, dscActive: false, fecEnabled: nil)
        let rgb10 = try #require(report.colorModeBudgets.first { $0.descriptor.pixelEncoding == .rgb444 && $0.descriptor.bitsPerComponent == 10 && $0.descriptor.eotf == .sdr })
        #expect(rgb10.verdict == .exceedsBandwidth)
        #expect(abs(rgb10.requiredGbps - 32.14) < 0.01)
        #expect(rgb10.colorElementID == nil)
        let rgb8 = try #require(report.colorModeBudgets.first { $0.descriptor.pixelEncoding == .rgb444 && $0.descriptor.bitsPerComponent == 8 && $0.descriptor.dynamicRange == .full })
        #expect(rgb8.verdict == .offered)
        #expect(rgb8.colorElementID == 100)
        // 선택 가능한 형식은 전부 유효 대역폭 이내, 초과 판정 형식은 전부 유효 대역폭 초과.
        let available = try #require(report.availableGbps)
        #expect(report.colorModeBudgets.filter { $0.verdict == .offered }.allSatisfy { $0.requiredGbps <= available })
        #expect(report.colorModeBudgets.filter { $0.verdict == .exceedsBandwidth }.allSatisfy { $0.requiredGbps > available })
        #expect(Set(report.colorModeBudgets.map(\.id)).count == report.colorModeBudgets.count)
    }

    @Test func 링크가_없으면_대역폭_미확인() throws {
        let report = LinkAnalyzer.report(display: lgDisplay(), signal: nil, state: nil, dscActive: nil, fecEnabled: nil)
        #expect(report.availableGbps == nil)
        #expect(report.requiredGbps == nil)
        #expect(report.utilization == nil)
        #expect(report.colorModeBudgets.isEmpty)
    }

    @Test func 레인_일부만_사용하면_참고_문구() {
        let state = DPTransportState(transportDescription: "Port-USB-C@1/DisplayPort", isActive: true, laneRateGbps: 5.4, linkRateDescription: "5.4 Gbps (HBR2)", laneCount: 2, maxLaneCount: 4, isTunneled: false, hpdState: 2, hpdDescription: "High", sinkCount: 1, parentPortType: "USB-C", parentPortNumber: 1)
        let report = LinkAnalyzer.report(display: lgDisplay(), signal: nil, state: state, dscActive: nil, fecEnabled: nil)
        #expect(abs((report.availableGbps ?? 0) - 8.64) < 0.001)
        #expect(report.notes.contains { $0.contains("레인 2개 사용 중") })
    }
}

/// TC-LNK-004: DPCD 해석과 실패 허용.
@Suite("TC-LNK-004 DPCD 해석")
struct DPCDDecoderTests {
    /// 내장 패널 실측값 (spikes 문서 L2).
    let caps: [UInt8] = [0x14, 0x1E, 0xC4, 0x41, 0x00, 0x00, 0x01, 0x80, 0x02, 0x00, 0x00, 0x00, 0x0F, 0x09, 0x00, 0x00]
    let linkConfig: [UInt8] = [0x17, 0x84, 0, 0, 0, 0, 0, 0]
    let status: [UInt8] = [0x01, 0x40, 0x00, 0x00, 0x80, 0x01, 0x00, 0x00]
    let extended: [UInt8] = [0x14, 0x1E, 0xE4, 0x81, 0x01, 0x00, 0x01, 0xC0, 0x02, 0x01, 0x04, 0x01, 0x0F, 0x00, 0x80, 0x00]

    @Test func 내장_패널_실측값() {
        let info = DPCDDecoder.decode(receiverCaps: caps, dscCaps: [UInt8](repeating: 0, count: 16), linkConfig: linkConfig, dscEnable: [0], status: status, extendedCaps: extended)
        #expect(info.revision == "1.4")
        #expect(info.maxLaneRateGbps.map { ($0 * 100).rounded() / 100 } == 8.1)
        #expect(info.maxLaneCount == 4)
        #expect(info.supportsEnhancedFraming == true)
        #expect(info.supportsTPS3 == true)
        #expect(info.supports8b10b == true)
        #expect(info.supports128b132b == false)
        #expect(info.supportsDSC == false)
        #expect(info.dscEnabled == false)
        #expect(info.currentLaneCount == 4)
        // 속도 부호 0x17은 표준이 아니므로 현재 속도 미해석.
        #expect(info.currentLaneRateGbps == nil)
        #expect(info.sinkCount == 1)
        #expect(info.laneStatus.count == 4)
    }

    @Test func 정상_훈련된_외장_링크() {
        let info = DPCDDecoder.decode(receiverCaps: caps, dscCaps: [0x01, 0x21], linkConfig: [0x1E, 0x84], dscEnable: [0x01], status: [0x01, 0x00, 0x77, 0x77, 0x01, 0, 0, 0], extendedCaps: nil)
        #expect(info.currentLaneRateGbps.map { ($0 * 100).rounded() / 100 } == 8.1)
        #expect(info.laneStatus.allSatisfy { $0.isGood })
        #expect(info.interlaneAlignDone == true)
        #expect(info.supportsDSC == true)
        #expect(info.dscRevision == "1.2")
        #expect(info.dscEnabled == true)
        // 레인 2의 채널 등화 미완료.
        let partial = DPCDDecoder.decode(receiverCaps: caps, dscCaps: nil, linkConfig: [0x1E, 0x84], dscEnable: nil, status: [0x01, 0x00, 0x77, 0x75, 0x00, 0, 0, 0], extendedCaps: nil)
        #expect(partial.laneStatus.map(\.isGood) == [true, true, false, true])
        #expect(partial.interlaneAlignDone == false)
    }

    @Test func 읽기_실패_구간은_없음으로_처리() {
        let empty = DPCDDecoder.decode(receiverCaps: nil, dscCaps: nil, linkConfig: nil, dscEnable: nil, status: nil, extendedCaps: nil)
        #expect(empty.revision == nil)
        #expect(empty.maxLaneCount == nil)
        #expect(empty.supportsDSC == nil)
        #expect(empty.laneStatus.isEmpty)
        let short = DPCDDecoder.decode(receiverCaps: [0x14], dscCaps: [0x01], linkConfig: [0x1E], dscEnable: [], status: [0x01], extendedCaps: [0x00])
        #expect(short.revision == nil)
        #expect(short.laneStatus.isEmpty)
    }

    @Test func 링크_훈련_데이터() {
        var bytes = [UInt8](repeating: 0, count: 0x98)
        bytes[0x08] = 4
        bytes[0x0C] = 0x1E
        let external = LinkTrainingData.decode(bytes)
        #expect(external?.laneCount == 4)
        #expect(external?.isStandardRate == true)
        #expect(external?.laneRateGbps.map { ($0 * 100).rounded() / 100 } == 8.1)
        bytes[0x0C] = 0x17
        let builtin = LinkTrainingData.decode(bytes)
        #expect(builtin?.isStandardRate == false)
        #expect(builtin?.laneRateGbps.map { ($0 * 100).rounded() / 100 } == 6.21)
        bytes[0x08] = 0
        #expect(LinkTrainingData.decode(bytes) == nil)
        #expect(LinkTrainingData.decode([UInt8](repeating: 0, count: 10)) == nil)
    }
}
