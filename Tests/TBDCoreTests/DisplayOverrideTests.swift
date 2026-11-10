import Foundation
import Testing
@testable import TBDCore

/// TC-MOD-005: 사용자 정의 스케일 해상도의 오버라이드 파일 모델.
@Suite("TC-MOD-005 오버라이드 파일 모델")
struct DisplayOverrideTests {
    @Test func 항목_부호화는_백킹_크기_8바이트() {
        let entry = ScaleResolutionEntry(logicalWidth: 2560, logicalHeight: 1440)
        #expect([UInt8](entry.raw) == [0x00, 0x00, 0x14, 0x00, 0x00, 0x00, 0x0B, 0x40])
        #expect(entry.width == 5120 && entry.height == 2880)
        #expect(entry.flags == nil)
        #expect(entry.isBackingSize)
        #expect(entry.label == "2560 x 1440 HiDPI (백킹 5120 x 2880)")
    }

    @Test func 플래그가_붙은_12바이트_항목_해석() {
        // 시스템 오버라이드 파일의 형식: 0x000005a0 0x00000354 0x00000001
        let entry = ScaleResolutionEntry(raw: Data([0x00, 0x00, 0x05, 0xA0, 0x00, 0x00, 0x03, 0x54, 0x00, 0x00, 0x00, 0x01]))
        #expect(entry.width == 1440 && entry.height == 852)
        #expect(entry.flags == 1)
        #expect(!entry.isBackingSize)
        #expect(entry.label == "1440 x 852 (플래그 0x1)")
        #expect(ScaleResolutionEntry(raw: Data([1, 2])).width == 0)
    }

    @Test func 경로_형식은_소문자_16진수() {
        #expect(DisplayOverrideFile.relativePath(vendorID: 0x1E6D, productID: 0xC0C8) == "DisplayVendorID-1e6d/DisplayProductID-c0c8")
        #expect(DisplayOverrideFile.relativePath(vendorID: 0x610, productID: 0xA05F) == "DisplayVendorID-610/DisplayProductID-a05f")
    }

    @Test func 추가_삭제_중복_범위_점검() throws {
        var file = DisplayOverrideFile(vendorID: 0x1E6D, productID: 0xC0C8)
        try file.add(logicalWidth: 2560, logicalHeight: 1440)
        try file.add(logicalWidth: 3008, logicalHeight: 1692)
        #expect(file.entries.count == 2)
        #expect(throws: DisplayOverrideFile.EditError.duplicate) { try file.add(logicalWidth: 2560, logicalHeight: 1440) }
        #expect(throws: DisplayOverrideFile.EditError.self) { try file.add(logicalWidth: 100, logicalHeight: 100) }
        try file.remove(logicalWidth: 2560, logicalHeight: 1440)
        #expect(file.entries.map(\.label) == ["3008 x 1692 HiDPI (백킹 6016 x 3384)"])
        #expect(throws: DisplayOverrideFile.EditError.notFound) { try file.remove(logicalWidth: 2560, logicalHeight: 1440) }
        #expect(DisplayOverrideFile.parseSize("2560x1440")?.width == 2560)
        #expect(DisplayOverrideFile.parseSize("2560") == nil)
    }

    @Test func plist_왕복과_다른_키_보존() throws {
        // 다른 도구가 만든 파일: 제품명과 12바이트 항목 포함.
        let existing: [String: Any] = [
            "DisplayVendorID": 0x1E6D, "DisplayProductID": 0xC0C8, "DisplayProductName": "사용자 지정 이름",
            "scale-resolutions": [Data([0x00, 0x00, 0x05, 0xA0, 0x00, 0x00, 0x03, 0x54, 0x00, 0x00, 0x00, 0x01])],
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: existing, format: .xml, options: 0)
        var file = try #require(DisplayOverrideFile.decode(data, vendorID: 0x1E6D, productID: 0xC0C8))
        #expect(file.entries.count == 1)
        #expect(file.hasOtherKeys)
        try file.add(logicalWidth: 2560, logicalHeight: 1440)

        let encoded = try file.encode()
        let dict = try #require(try PropertyListSerialization.propertyList(from: encoded, format: nil) as? [String: Any])
        #expect(dict["DisplayProductName"] as? String == "사용자 지정 이름")
        #expect(dict["DisplayVendorID"] as? Int == 0x1E6D)
        #expect(dict["DisplayProductID"] as? Int == 0xC0C8)
        #expect((dict["scale-resolutions"] as? [Data])?.map(\.count) == [12, 8])

        let again = try #require(DisplayOverrideFile.decode(encoded, vendorID: 0x1E6D, productID: 0xC0C8))
        #expect(again.entries == file.entries)
        #expect(DisplayOverrideFile.decode(Data("plist 아님".utf8), vendorID: 1, productID: 1) == nil)

        let fresh = DisplayOverrideFile(vendorID: 1, productID: 2)
        #expect(!fresh.hasOtherKeys)
    }
}
