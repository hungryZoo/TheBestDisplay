import Foundation
import Testing
@testable import TBDCore

/// TC-DDC-001: DDC 패킷 구성과 응답 해석.
@Suite("TC-DDC-001 DDC 패킷")
struct DDCPacketTests {
    /// 응답 11바이트 구성: 머리, 길이, 0x02, 결과, 코드, 유형, 최댓값, 현재값, 체크섬.
    func reply(code: UInt8, current: UInt16, maximum: UInt16, result: UInt8 = 0, opcode: UInt8 = 0x02) -> [UInt8] {
        var bytes: [UInt8] = [0x6E, 0x88, opcode, result, code, 0x00, UInt8(maximum >> 8), UInt8(maximum & 0xFF), UInt8(current >> 8), UInt8(current & 0xFF)]
        bytes.append(bytes.reduce(0x50) { $0 ^ $1 })
        return bytes
    }

    @Test func 읽기_요청_바이트열() {
        // 체크섬: 0x6E ^ 0x51 ^ 0x82 ^ 0x01 ^ 0x10 = 0xAC
        #expect(DDCPacket.getRequest(0x10) == [0x82, 0x01, 0x10, 0xAC])
        #expect(DDCPacket.getRequest(0x62) == [0x82, 0x01, 0x62, 0xDE])
    }

    @Test func 쓰기_요청_바이트열() {
        // 밝기 50: 0x6E ^ 0x51 ^ 0x84 ^ 0x03 ^ 0x10 ^ 0x00 ^ 0x32 = 0x9A
        #expect(DDCPacket.setRequest(0x10, value: 50) == [0x84, 0x03, 0x10, 0x00, 0x32, 0x9A])
        let big = DDCPacket.setRequest(0x60, value: 0x1234)
        #expect(Array(big[0..<5]) == [0x84, 0x03, 0x60, 0x12, 0x34])
        #expect(big.count == 6)
        // 전 바이트와 주소를 XOR하면 0.
        #expect(big.reduce(UInt8(0x6E ^ 0x51)) { $0 ^ $1 } == 0)
    }

    @Test func 정상_응답_해석() throws {
        let parsed = try DDCPacket.parseReply(reply(code: 0x10, current: 70, maximum: 100), expecting: 0x10).get()
        #expect(parsed == DDCPacket.Reply(code: 0x10, current: 70, maximum: 100))
        let wide = try DDCPacket.parseReply(reply(code: 0x60, current: 0x0F11, maximum: 0xFFFF)).get()
        #expect(wide.current == 0x0F11)
        #expect(wide.maximum == 0xFFFF)
    }

    @Test func 오류_응답_거부() {
        var corrupted = reply(code: 0x10, current: 70, maximum: 100)
        corrupted[8] ^= 0x01
        #expect(DDCPacket.parseReply(corrupted) == .failure(.checksumMismatch))
        #expect(DDCPacket.parseReply([0x6E, 0x88]) == .failure(.tooShort))
        #expect(DDCPacket.parseReply([UInt8](repeating: 0, count: 11)) == .failure(.checksumMismatch))
        #expect(DDCPacket.parseReply(reply(code: 0x10, current: 0, maximum: 0, result: 1)) == .failure(.unsupportedCode))
        #expect(DDCPacket.parseReply(reply(code: 0x10, current: 1, maximum: 2, opcode: 0x07)) == .failure(.notVCPReply))
        // 다른 코드의 응답은 거부.
        #expect(DDCPacket.parseReply(reply(code: 0x12, current: 1, maximum: 2), expecting: 0x10) == .failure(.notVCPReply))
    }

    @Test func VCP_코드_이름과_값_해석() {
        #expect(VCPCode.parse("brightness") == 0x10)
        #expect(VCPCode.parse("Volume") == 0x62)
        #expect(VCPCode.parse("0xD6") == 0xD6)
        #expect(VCPCode.parse("18") == 18)
        #expect(VCPCode.parse("0xZZ") == nil)
        #expect(VCPCode.parse("999") == nil)
        #expect(VCPCode.brightness.isContinuous)
        #expect(!VCPCode.inputSource.isContinuous)
        #expect(VCPCode.inputSource.options.contains { $0.value == 0x11 && $0.name == "HDMI 1" })
        #expect(VCPCode.powerMode.options.map(\.value) == [1, 4, 5])
    }

    @Test func 탐지_결과_문구() {
        #expect(DDCProbe(status: .supported).reason == "DDC 응답 확인")
        #expect(DDCProbe(status: .noResponse).reason.contains("TV"))
        #expect(DDCProbe(status: .notApplicable).reason.contains("내장"))
    }
}

/// TC-BRT-002: 전달 테이블 합성.
@Suite("TC-BRT-002 전달 테이블 합성")
struct GammaTableTests {
    @Test func 항등_설정은_선형_테이블() {
        let table = GammaTable.make(.identity)
        #expect(table.red.count == 256)
        #expect(table == GammaTable.linear())
        #expect(table.red.first == 0)
        #expect(table.red.last == 1)
        #expect(ColorAdjustment.identity.isIdentity)
    }

    @Test func 디밍은_최댓값을_낮춤() {
        var a = ColorAdjustment()
        a.dimming = 0.5
        let table = GammaTable.make(a)
        #expect(table.red.last == 0.5)
        #expect(table.green.last == 0.5)
        #expect(table.blue.last == 0.5)
        #expect(abs(table.red[128] - 0.5 * 128 / 255) < 0.001)
        #expect(table.isMonotonic)
        #expect(!a.isIdentity)
    }

    @Test func 허용_범위_밖의_값은_잘림() {
        var a = ColorAdjustment()
        a.dimming = 0
        a.gamma = 10
        a.contrast = -3
        a.temperature = 100
        a.redGain = 5
        let c = a.clamped()
        #expect(c.dimming == 0.1)
        #expect(c.gamma == 2.0)
        #expect(c.contrast == 0.5)
        #expect(c.temperature == 2700)
        #expect(c.redGain == 1.0)
        // 디밍 0을 넣어도 화면이 완전히 꺼지지 않음.
        let table = GammaTable.make(a)
        #expect(max(table.red.last!, table.green.last!, table.blue.last!) > 0.01)
    }

    @Test func 색온도_배율() {
        let neutral = GammaTable.temperatureMultipliers(6500)
        #expect(abs(neutral.red - 1) < 0.001 && abs(neutral.green - 1) < 0.001 && abs(neutral.blue - 1) < 0.001)
        let warm = GammaTable.temperatureMultipliers(3000)
        #expect(warm.red == 1)
        #expect(warm.green < 1)
        #expect(warm.blue < warm.green)
        let cool = GammaTable.temperatureMultipliers(9000)
        #expect(cool.blue == 1)
        #expect(cool.red < 1)
        // 어느 온도에서도 채널 배율은 1 이하.
        for k in stride(from: 2700.0, through: 9300.0, by: 300) {
            let m = GammaTable.temperatureMultipliers(k)
            #expect(max(m.red, m.green, m.blue) <= 1.0001)
            #expect(min(m.red, m.green, m.blue) > 0)
        }
    }

    @Test func 조합_설정에서_단조_증가와_값_범위_유지() {
        var a = ColorAdjustment()
        for (dimming, gamma, contrast, temperature, gain) in [(0.5, 1.4, 1.3, 4000.0, 0.8), (0.1, 0.5, 0.5, 9300.0, 0.5), (1.0, 2.0, 1.5, 2700.0, 1.0), (0.7, 0.8, 1.0, 6500.0, 0.9)] {
            a.dimming = dimming
            a.gamma = gamma
            a.contrast = contrast
            a.temperature = temperature
            a.blueGain = gain
            let table = GammaTable.make(a)
            #expect(table.isMonotonic)
            for channel in [table.red, table.green, table.blue] {
                #expect(channel.allSatisfy { $0 >= 0 && $0 <= 1 })
            }
            #expect(table.red.last! <= Float(dimming) + 0.0001)
        }
    }

    @Test func 감마와_대비() {
        var a = ColorAdjustment()
        a.gamma = 2
        #expect(abs(GammaTable.make(a).red[128] - Float(pow(128.0 / 255, 2))) < 0.001)
        a = ColorAdjustment()
        a.contrast = 1.5
        let table = GammaTable.make(a)
        // 대비를 높이면 어두운 쪽은 더 어둡고 밝은 쪽은 더 밝음. 중간값은 유지.
        #expect(table.red[64] < 64.0 / 255)
        #expect(table.red[192] > 192.0 / 255)
        #expect(abs(table.red[128] - 0.5) < 0.01)
        #expect(table.isMonotonic)
    }

    @Test func 기준_테이블_위_합성() {
        var a = ColorAdjustment()
        a.dimming = 0.5
        let adjusted = GammaTable.make(a)
        // 선형 기준 위에 합성하면 조정 테이블 그대로.
        let overLinear = adjusted.composed(over: .linear())
        #expect(zip(overLinear.red, adjusted.red).allSatisfy { abs($0 - $1) < 0.0001 })
        // 보정 곡선(제곱) 기준 위 합성: 결과 = 기준(조정값).
        let squared = GammaTable.linear().red.map { $0 * $0 }
        let baseline = GammaTable(red: squared, green: squared, blue: squared)
        let composed = adjusted.composed(over: baseline)
        #expect(abs(composed.red.last! - 0.25) < 0.002)
        #expect(composed.isMonotonic)
        // 항등 조정은 기준 테이블 유지.
        let unchanged = GammaTable.make(.identity).composed(over: baseline)
        #expect(zip(unchanged.red, baseline.red).allSatisfy { abs($0 - $1) < 0.0001 })
    }

    @Test func 밝기_제어_방식_이름() {
        #expect(BrightnessMethod.native.title == "시스템 밝기 제어")
        #expect(BrightnessMethod.ddc.title == "DDC")
        #expect(BrightnessMethod.software.title == "소프트웨어 디밍")
    }
}
