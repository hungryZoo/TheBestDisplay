import Foundation
import Testing
@testable import TBDCore

/// TC-DDC-004: DDC capabilities 요청, 응답 조각, 문자열 해석.
@Suite("TC-DDC-004 DDC capabilities 해석")
struct DDCCapabilitiesTests {
    @Test func 요청_바이트열() {
        // 6E ^ 51 ^ 83 ^ F3 ^ 00 ^ 00 = 4F
        #expect(DDCCapabilities.request(offset: 0) == [0x83, 0xF3, 0x00, 0x00, 0x4F])
        #expect(DDCCapabilities.request(offset: 0x0120).prefix(4) == [0x83, 0xF3, 0x01, 0x20])
    }

    static func fragment(offset: Int, _ text: String) -> [UInt8] {
        let data = Array(text.utf8)
        var bytes: [UInt8] = [0x6E, 0x80 | UInt8(3 + data.count), 0xE3, UInt8(offset >> 8), UInt8(offset & 0xFF)] + data
        bytes.append(bytes.reduce(0x50) { $0 ^ $1 })
        return bytes
    }

    @Test func 응답_조각_해석() throws {
        let first = try #require(DDCCapabilities.parseFragment(Self.fragment(offset: 0, "(prot(monitor)")))
        #expect(first.offset == 0)
        #expect(String(decoding: first.data, as: UTF8.self) == "(prot(monitor)")
        let end = try #require(DDCCapabilities.parseFragment(Self.fragment(offset: 14, "")))
        #expect(end.offset == 14 && end.data.isEmpty)
        var corrupted = Self.fragment(offset: 0, "abc")
        corrupted[5] ^= 0xFF
        #expect(DDCCapabilities.parseFragment(corrupted) == nil)
        #expect(DDCCapabilities.parseFragment([0x6E, 0x88, 0x02, 0, 0, 0]) == nil)
        // 뒤에 채움 바이트가 붙은 버퍼도 해석.
        #expect(DDCCapabilities.parseFragment(Self.fragment(offset: 0, "ab") + [0, 0, 0])?.data.count == 2)
    }

    @Test func 문자열_해석() {
        let caps = DDCCapabilities.parse("(prot(monitor)type(lcd)model(ABC27)cmds(01 02 03 07 0C E3 F3)vcp(10 12 14(05 08 0B) 16 18 1A 60(0F 11 12) 62 8D(01 02) D6(01 04 05))mccs_ver(2.1))")
        #expect(caps.model == "ABC27")
        #expect(caps.type == "lcd")
        #expect(caps.mccsVersion == "2.1")
        #expect(caps.commands == [0x01, 0x02, 0x03, 0x07, 0x0C, 0xE3, 0xF3])
        #expect(caps.vcpCodes == [0x10, 0x12, 0x14, 0x16, 0x18, 0x1A, 0x60, 0x62, 0x8D, 0xD6])
        #expect(caps.vcpValues[0x60] == [0x0F, 0x11, 0x12])
        #expect(caps.vcpValues[0x14] == [0x05, 0x08, 0x0B])
        #expect(caps.vcpValues[0x10] == nil)
        #expect(caps.supports(0x62) && !caps.supports(0x87))
    }

    @Test func 불완전한_문자열() {
        let truncated = DDCCapabilities.parse("(prot(monitor)vcp(10 12 60(0F 11")
        #expect(truncated.vcpCodes == [0x10, 0x12, 0x60])
        #expect(truncated.vcpValues[0x60] == [0x0F, 0x11])
        let empty = DDCCapabilities.parse("")
        #expect(empty.vcpCodes.isEmpty && empty.model == nil)
    }
}
