import Foundation
import Testing
@testable import TBDCore

/// TC-MOD-019: 오버라이드 파일의 이름, 기본 해상도, TV 역할 키.
@Suite("TC-MOD-019 오버라이드 키 해석과 편집")
struct DisplayOverrideKeysTests {
    @Test func 키가_없는_파일은_지정_없음() {
        let file = DisplayOverrideFile(vendorID: 0x1E6D, productID: 0xC0C8)
        #expect(file.productName == nil && file.defaultResolution == nil && file.isTV == nil)
        #expect(!file.hasOtherKeys)
        #expect(file.keySummary == ["이름: 지정 없음", "기본 해상도: 지정 없음", "TV 역할 표시: 지정 없음"])
    }

    @Test func 지정과_부호화_왕복() throws {
        var file = DisplayOverrideFile(vendorID: 0x1E6D, productID: 0xC0C8)
        try file.add(logicalWidth: 2400, logicalHeight: 1350)
        try file.setProductName("  거실 TV  ")
        try file.setDefaultResolution(width: 2560, height: 1440)
        file.isTV = true
        #expect(file.hasOtherKeys)

        let data = try file.encode()
        let dict = try #require(try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        #expect(dict["DisplayProductName"] as? String == "거실 TV")
        #expect(dict["DisplayIsTV"] as? Bool == true)
        // 실측한 형식 (T69): 폭 4바이트, 높이 4바이트, 0x003cffff.
        #expect(dict["default-resolution"] as? Data == Data([0x00, 0x00, 0x0A, 0x00, 0x00, 0x00, 0x05, 0xA0, 0x00, 0x3C, 0xFF, 0xFF]))
        #expect((dict["scale-resolutions"] as? [Data])?.count == 1)

        let decoded = try #require(DisplayOverrideFile.decode(data, vendorID: 0x1E6D, productID: 0xC0C8))
        #expect(decoded.productName == "거실 TV")
        #expect(decoded.defaultResolution?.width == 2560 && decoded.defaultResolution?.height == 1440)
        #expect(decoded.isTV == true)
        #expect(decoded.entries.count == 1)
        #expect(decoded.keySummary == ["이름: 거실 TV", "기본 해상도: 2560 x 1440", "TV 역할 표시: 켬"])
    }

    @Test func 해제하면_키가_사라지고_다른_키는_유지() throws {
        var file = DisplayOverrideFile(vendorID: 1, productID: 2)
        try file.setProductName("이름")
        try file.setDefaultResolution(width: 1920, height: 1080)
        file.isTV = false
        try file.setProductName(nil)
        #expect(file.productName == nil)
        #expect(file.defaultResolution?.width == 1920 && file.isTV == false)
        file.defaultResolution = nil
        file.isTV = nil
        // 세 키를 모두 지우면 스케일 해상도 밖의 키가 없는 상태 (항목도 없으면 파일 삭제 대상).
        #expect(!file.hasOtherKeys)
    }

    @Test func 다른_도구가_넣은_키는_보존() throws {
        let source: [String: Any] = ["DisplayVendorID": 7789, "DisplayProductID": 49352, "target-default-ppmm": 10.07, "dmdg": Data([0, 0, 0, 2])]
        let data = try PropertyListSerialization.data(fromPropertyList: source, format: .xml, options: 0)
        var file = try #require(DisplayOverrideFile.decode(data, vendorID: 7789, productID: 49352))
        try file.setProductName("모니터")
        let dict = try #require(try PropertyListSerialization.propertyList(from: try file.encode(), format: nil) as? [String: Any])
        #expect(dict["target-default-ppmm"] as? Double == 10.07)
        #expect(dict["dmdg"] as? Data == Data([0, 0, 0, 2]))
        #expect(dict["DisplayProductName"] as? String == "모니터")
    }

    @Test func 스케일_해상도가_없으면_해당_키를_쓰지_않음() throws {
        var file = DisplayOverrideFile(vendorID: 1, productID: 2)
        try file.setProductName("이름만")
        let dict = try #require(try PropertyListSerialization.propertyList(from: try file.encode(), format: nil) as? [String: Any])
        #expect(dict["scale-resolutions"] == nil)
        #expect(dict["DisplayProductName"] as? String == "이름만")
    }

    @Test func 언어별_이름_사전은_영어_항목_사용() throws {
        let source: [String: Any] = ["DisplayProductName": ["ko_KR": "한국어 이름", "en_US": "English Name"]]
        let data = try PropertyListSerialization.data(fromPropertyList: source, format: .xml, options: 0)
        let file = try #require(DisplayOverrideFile.decode(data, vendorID: 1, productID: 2))
        #expect(file.productName == "English Name")
    }

    @Test func 형식이_맞지_않는_기본_해상도는_지정_없음() throws {
        let source: [String: Any] = ["default-resolution": Data([0, 0, 5]), "DisplayIsTV": "문자열"]
        let data = try PropertyListSerialization.data(fromPropertyList: source, format: .xml, options: 0)
        let file = try #require(DisplayOverrideFile.decode(data, vendorID: 1, productID: 2))
        #expect(file.defaultResolution == nil)
        #expect(file.isTV == nil)
    }

    @Test func 이름과_해상도_점검() {
        #expect(DisplayOverrideFile.validateName("LG TV") == nil)
        #expect(DisplayOverrideFile.validateName("   ") == "이름 길이는 1-64자")
        #expect(DisplayOverrideFile.validateName(String(repeating: "가", count: 65)) == "이름 길이는 1-64자")
        #expect(DisplayOverrideFile.validateName("줄\u{07}바꿈") == "이름에 제어 문자 사용 불가")
        var file = DisplayOverrideFile(vendorID: 1, productID: 2)
        #expect(throws: DisplayOverrideFile.EditError.self) { try file.setProductName("") }
        #expect(throws: DisplayOverrideFile.EditError.self) { try file.setDefaultResolution(width: 100, height: 100) }
        #expect(file.productName == nil && file.defaultResolution == nil)
    }
}
