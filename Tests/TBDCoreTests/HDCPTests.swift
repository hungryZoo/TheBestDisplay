import Foundation
import Testing
@testable import TBDCore

/// TC-LNK-005: DPCD의 HDCP 능력 해석.
@Suite("TC-LNK-005 HDCP 능력 해석")
struct HDCPTests {
    static func decode(bcaps: [UInt8]?, rxCaps: [UInt8]?) -> DPCDInfo {
        DPCDDecoder.decode(receiverCaps: nil, dscCaps: nil, linkConfig: nil, dscEnable: nil, status: nil, extendedCaps: nil, hdcpBcaps: bcaps, hdcpRxCaps: rxCaps)
    }

    @Test func HDCP_2_2와_1_x_지원() {
        let info = Self.decode(bcaps: [0x01], rxCaps: [0x02, 0x00, 0x02])
        #expect(info.hdcp1Capable == true)
        #expect(info.hdcp2Capable == true)
        #expect(info.hdcp2Version == 2)
        #expect(info.hdcpRepeater == false)
        #expect(info.hdcpSummary == "HDCP 2.2 지원, HDCP 1.x 지원")
    }

    @Test func 리피터와_1_x_전용() {
        let repeater = Self.decode(bcaps: [0x03], rxCaps: [0x02, 0x00, 0x03])
        #expect(repeater.hdcpRepeater == true)
        #expect(repeater.hdcpSummary == "HDCP 2.2 지원, HDCP 1.x 지원, 리피터")
        let legacy = Self.decode(bcaps: [0x01], rxCaps: [0x00, 0x00, 0x00])
        #expect(legacy.hdcp2Capable == false && legacy.hdcp2Version == nil)
        #expect(legacy.hdcpSummary == "HDCP 1.x 지원")
    }

    @Test func 미지원과_읽기_불가() {
        #expect(Self.decode(bcaps: [0x00], rxCaps: [0x00, 0x00, 0x00]).hdcpSummary == "미지원")
        let unreadable = Self.decode(bcaps: nil, rxCaps: nil)
        #expect(unreadable.hdcp1Capable == nil && unreadable.hdcp2Capable == nil)
        #expect(unreadable.hdcpSummary == "읽기 불가")
        // 한쪽만 읽힌 경우.
        #expect(Self.decode(bcaps: nil, rxCaps: [0x02, 0x00, 0x02]).hdcpSummary == "HDCP 2.2 지원")
        // 길이가 모자란 RxCaps는 해석하지 않음.
        #expect(Self.decode(bcaps: nil, rxCaps: [0x02]).hdcpSummary == "읽기 불가")
    }
}
