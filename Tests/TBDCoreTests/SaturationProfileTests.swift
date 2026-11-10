import Foundation
import Testing
@testable import TBDCore

/// TC-CLR-009: ICC 프로파일 편집과 채도 조정 계산.
@Suite("TC-CLR-009 ICC 편집과 채도 조정 계산")
struct SaturationProfileTests {
    /// 내장 패널 프로파일(Color LCD) 실측 색 좌표 (T58).
    static let red = ICCProfile.XYZ(x: 0.5151, y: 0.2412, z: -0.0011)
    static let green = ICCProfile.XYZ(x: 0.2920, y: 0.6922, z: 0.0419)
    static let blue = ICCProfile.XYZ(x: 0.1571, y: 0.0666, z: 0.7841)

    static func be32(_ value: UInt32) -> [UInt8] { ICCProfile.be32(value) }

    static func xyzBlock(_ v: ICCProfile.XYZ) -> [UInt8] {
        func fixed(_ d: Double) -> [UInt8] { be32(UInt32(bitPattern: Int32((d * 65536).rounded()))) }
        return Array("XYZ ".utf8) + [0, 0, 0, 0] + fixed(v.x) + fixed(v.y) + fixed(v.z)
    }

    /// 행렬 방식 디스플레이 프로파일 합성: 세 TRC 태그가 자료 하나를 공유.
    static func sampleProfile() -> Data {
        var header = [UInt8](repeating: 0, count: 128)
        header.replaceSubrange(12..<16, with: Array("mntr".utf8))
        header.replaceSubrange(16..<20, with: Array("RGB ".utf8))
        header.replaceSubrange(20..<24, with: Array("XYZ ".utf8))
        header.replaceSubrange(36..<40, with: Array("acsp".utf8))
        header.replaceSubrange(84..<100, with: [UInt8](repeating: 0xAB, count: 16))
        let curve = Array("curv".utf8) + [0, 0, 0, 0] + be32(1) + [0x02, 0x33, 0, 0]
        let text = Array("text".utf8) + [0, 0, 0, 0] + Array("c".utf8) + [0]
        let blocks: [(String, [UInt8])] = [("cprt", text), ("rXYZ", xyzBlock(red)), ("gXYZ", xyzBlock(green)), ("bXYZ", xyzBlock(blue)), ("rTRC", curve)]
        let shared = ["gTRC", "bTRC"]
        let count = blocks.count + shared.count
        var offset = 132 + count * 12
        var table = be32(UInt32(count))
        var body: [UInt8] = []
        var curveOffset = 0
        for (signature, bytes) in blocks {
            if signature == "rTRC" { curveOffset = offset }
            table += Array(signature.utf8) + be32(UInt32(offset)) + be32(UInt32(bytes.count))
            body += bytes
            while body.count % 4 != 0 { body.append(0) }
            offset = 132 + count * 12 + body.count
        }
        for signature in shared { table += Array(signature.utf8) + be32(UInt32(curveOffset)) + be32(UInt32(curve.count)) }
        header.replaceSubrange(0..<4, with: be32(UInt32(132 + count * 12 + body.count)))
        return Data(header + table + body)
    }

    static func close(_ a: Double, _ b: Double, _ tolerance: Double = 2e-5) -> Bool { abs(a - b) < tolerance }

    @Test func 해석과_직렬화_왕복() throws {
        let profile = try ICCProfile(data: Self.sampleProfile())
        #expect(profile.profileClass == "mntr" && profile.colorSpace == "RGB ")
        #expect(profile.tags.map(\.signature) == ["cprt", "rXYZ", "gXYZ", "bXYZ", "rTRC", "gTRC", "bTRC"])
        // TRC 태그 3개는 자료 1개 공유.
        #expect(Set(profile.tags.filter { $0.signature.hasSuffix("TRC") }.map(\.block)).count == 1)
        #expect(profile.blocks.count == 5)
        let again = try ICCProfile(data: profile.serialized())
        #expect(again.tags.map(\.signature) == profile.tags.map(\.signature))
        #expect(again.blocks.count == 5)
        #expect(try again.xyz("rXYZ") == profile.xyz("rXYZ"))
        // 직렬화는 크기를 갱신하고 프로파일 ID를 비움.
        let bytes = [UInt8](profile.serialized())
        #expect(ICCProfile.u32(bytes, 0) == bytes.count)
        #expect(bytes[84..<100].allSatisfy { $0 == 0 })
        #expect(bytes.count % 4 == 0)
    }

    @Test func 형식_오류() {
        #expect(throws: ICCProfile.ParseError.tooShort) { try ICCProfile(data: Data(count: 50)) }
        #expect(throws: ICCProfile.ParseError.badSignature) { try ICCProfile(data: Data(count: 200)) }
        var broken = [UInt8](Self.sampleProfile())
        broken.replaceSubrange(128..<132, with: Self.be32(5000))
        #expect(throws: ICCProfile.ParseError.badTagTable) { try ICCProfile(data: Data(broken)) }
        var outside = [UInt8](Self.sampleProfile())
        outside.replaceSubrange(136..<140, with: Self.be32(99999))
        #expect(throws: ICCProfile.ParseError.badTagTable) { try ICCProfile(data: Data(outside)) }
    }

    @Test func 색_좌표_읽기와_쓰기() throws {
        var profile = try ICCProfile(data: Self.sampleProfile())
        let red = try profile.xyz("rXYZ")
        #expect(Self.close(red.x, 0.5151) && Self.close(red.y, 0.2412) && Self.close(red.z, -0.0011))
        profile.setXYZ(.init(x: -0.25, y: 0.5, z: 1.75), for: "rXYZ")
        #expect(try profile.xyz("rXYZ") == ICCProfile.XYZ(x: -0.25, y: 0.5, z: 1.75))
        #expect(throws: ICCProfile.ParseError.missingTag("wtpt")) { try profile.xyz("wtpt") }
        #expect(throws: ICCProfile.ParseError.wrongTagType("cprt")) { try profile.xyz("cprt") }
    }

    @Test func 공유_자료는_교체해도_다른_태그에_영향_없음() throws {
        var profile = try ICCProfile(data: Self.sampleProfile())
        let original = try #require(profile.block(for: "gTRC"))
        profile.setBlock([1, 2, 3, 4], for: "rTRC")
        #expect(profile.block(for: "rTRC") == [1, 2, 3, 4])
        #expect(profile.block(for: "gTRC") == original && profile.block(for: "bTRC") == original)
        let again = try ICCProfile(data: profile.serialized())
        #expect(again.block(for: "rTRC") == [1, 2, 3, 4])
        #expect(again.block(for: "bTRC") == original)
    }

    @Test func 채도_1은_색_좌표_유지() {
        let same = SaturationAdjustment.adjustedColorants(red: Self.red, green: Self.green, blue: Self.blue, saturation: 1)
        #expect(Self.close(same.red.x, Self.red.x) && Self.close(same.green.y, Self.green.y) && Self.close(same.blue.z, Self.blue.z))
    }

    @Test func 흰색과_원색_휘도_유지() {
        let white = Self.red + Self.green + Self.blue
        for saturation in [0.5, 0.8, 1.2, 1.5] {
            let adjusted = SaturationAdjustment.adjustedColorants(red: Self.red, green: Self.green, blue: Self.blue, saturation: saturation)
            let sum = adjusted.red + adjusted.green + adjusted.blue
            #expect(Self.close(sum.x, white.x) && Self.close(sum.y, white.y) && Self.close(sum.z, white.z))
            #expect(Self.close(adjusted.red.y, Self.red.y) && Self.close(adjusted.green.y, Self.green.y) && Self.close(adjusted.blue.y, Self.blue.y))
        }
    }

    /// 색 관리의 출력값은 `M'⁻¹ · XYZ`. 바꾼 좌표 `M'`로 계산한 출력이 원래 출력에 채도 행렬을 곱한 값과 같은지 확인.
    @Test func 바꾼_좌표의_출력은_원래_출력에_채도_행렬을_곱한_값() {
        func solve(_ r: ICCProfile.XYZ, _ g: ICCProfile.XYZ, _ b: ICCProfile.XYZ, _ t: ICCProfile.XYZ) -> (Double, Double, Double) {
            // 크라머 공식으로 [r g b] · c = t 풀이.
            func det(_ a: ICCProfile.XYZ, _ b: ICCProfile.XYZ, _ c: ICCProfile.XYZ) -> Double {
                a.x * (b.y * c.z - c.y * b.z) - b.x * (a.y * c.z - c.y * a.z) + c.x * (a.y * b.z - b.y * a.z)
            }
            let d = det(r, g, b)
            return (det(t, g, b) / d, det(r, t, b) / d, det(r, g, t) / d)
        }
        let white = Self.red + Self.green + Self.blue
        let weights = (Self.red.y / white.y, Self.green.y / white.y, Self.blue.y / white.y)
        // 임의의 목표 색 3개 (원래 장치 값 기준).
        for device in [(1.0, 0.0, 0.0), (0.2, 0.7, 0.1), (0.5, 0.5, 0.9)] {
            let target = Self.red * device.0 + Self.green * device.1 + Self.blue * device.2
            for saturation in [0.5, 0.8, 1.3] {
                let adjusted = SaturationAdjustment.adjustedColorants(red: Self.red, green: Self.green, blue: Self.blue, saturation: saturation)
                let output = solve(adjusted.red, adjusted.green, adjusted.blue, target)
                let expected = SaturationAdjustment.apply(saturation, to: device, weights: weights)
                #expect(Self.close(output.0, expected.0, 1e-9) && Self.close(output.1, expected.1, 1e-9) && Self.close(output.2, expected.2, 1e-9))
            }
        }
        // 무채색은 채도와 무관하게 같은 출력.
        let gray = SaturationAdjustment.apply(0.5, to: (0.4, 0.4, 0.4), weights: weights)
        #expect(Self.close(gray.0, 0.4, 1e-12) && Self.close(gray.1, 0.4, 1e-12) && Self.close(gray.2, 0.4, 1e-12))
    }

    @Test func 프로파일_조정_결과() throws {
        let base = try ICCProfile(data: Self.sampleProfile())
        let adjusted = try SaturationAdjustment.adjustedProfile(base, saturation: 0.8, baseName: "Color LCD")
        let reread = try ICCProfile(data: adjusted.serialized())
        let expected = SaturationAdjustment.adjustedColorants(red: Self.red, green: Self.green, blue: Self.blue, saturation: 0.8)
        let red = try reread.xyz("rXYZ")
        #expect(Self.close(red.x, expected.red.x, 3e-5) && Self.close(red.y, Self.red.y, 3e-5))
        // 채도를 낮추면 프로파일의 빨강 좌표는 흰색에서 더 멀어짐.
        #expect(red.x > Self.red.x)
        // TRC와 저작권 태그는 그대로, 이름 태그 2개 추가.
        #expect(reread.block(for: "gTRC") == base.block(for: "gTRC"))
        #expect(reread.block(for: "cprt") == base.block(for: "cprt"))
        let desc = try #require(reread.block(for: "desc"))
        #expect(String(decoding: desc[12..<12 + 29], as: UTF8.self) == "TheBestDisplay saturation 80%")
        let mluc = try #require(reread.block(for: "dscm"))
        #expect(String(decoding: mluc[0..<4], as: UTF8.self) == "mluc")
        let name = String(bytes: mluc[28...], encoding: .utf16BigEndian)
        #expect(name == "Color LCD (채도 80%)")
    }

    @Test func 색_좌표가_없는_프로파일은_거부() throws {
        var profile = try ICCProfile(data: Self.sampleProfile())
        profile.removeTag("gXYZ")
        #expect(throws: ICCProfile.ParseError.missingTag("gXYZ")) { try SaturationAdjustment.adjustedProfile(profile, saturation: 0.8, baseName: "x") }
    }

    @Test func 입력_범위와_저장() throws {
        #expect(SaturationAdjustment.parsePercent("80") == 0.8)
        #expect(SaturationAdjustment.parsePercent("150") == 1.5)
        #expect(SaturationAdjustment.parsePercent("49") == nil)
        #expect(SaturationAdjustment.parsePercent("151") == nil)
        #expect(SaturationAdjustment.parsePercent("abc") == nil)
        let store = SaturationStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("tbd-saturation-\(UUID().uuidString).json"))
        let identity = DisplayIdentity(displayID: 1, uuid: nil, vendorID: 0x610, productID: 0xA05E, serialNumber: 1, name: "내장", isBuiltin: true)
        #expect(store.entry(for: identity) == nil)
        let entry = SaturationStore.Entry(basePath: "/a.icc", baseName: "Color LCD", baseIsFactoryDefault: true, saturation: 0.8, generatedPath: "/b.icc")
        try store.set(entry, for: identity)
        #expect(store.entry(for: identity) == entry)
        try store.set(nil, for: identity)
        #expect(store.entry(for: identity) == nil)
    }
}
