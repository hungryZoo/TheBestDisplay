import Foundation
import Testing
@testable import TBDCore

/// TC-CLR-007: SDR과 HDR 상태별 프로파일 지정.
@Suite("TC-CLR-007 상태별 색 프로파일")
struct HDRProfileTests {
    @Test func 상태에_따른_전환_대상() {
        let preference = HDRProfilePreference(sdrProfilePath: "/p/sRGB.icc", hdrProfilePath: "/p/2020.icc")
        #expect(preference.target(hdrEnabled: true, currentPath: "/p/sRGB.icc") == "/p/2020.icc")
        #expect(preference.target(hdrEnabled: false, currentPath: "/p/2020.icc") == "/p/sRGB.icc")
        // 이미 그 프로파일이면 전환하지 않음.
        #expect(preference.target(hdrEnabled: true, currentPath: "/p/2020.icc") == nil)
        // 한쪽만 지정한 경우 지정이 없는 상태에서는 그대로 둠.
        let hdrOnly = HDRProfilePreference(hdrProfilePath: "/p/2020.icc")
        #expect(hdrOnly.target(hdrEnabled: false, currentPath: "/p/2020.icc") == nil)
        #expect(HDRProfilePreference().isEmpty)
    }

    @Test func 저장과_삭제() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("tbd-hdrprofile-\(UUID().uuidString).json")
        let store = HDRProfileStore(fileURL: url)
        let tv = DisplayIdentity(displayID: 2, uuid: nil, vendorID: 0x1E6D, productID: 0xC0C8, serialNumber: 16843009, name: "TV", isBuiltin: false)
        #expect(store.preference(for: tv).isEmpty)
        let preference = HDRProfilePreference(sdrProfilePath: "/p/sRGB.icc", hdrProfilePath: nil)
        try store.save(preference, for: tv)
        #expect(store.preference(for: tv) == preference)
        // 빈 지정을 저장하면 항목과 파일 삭제.
        try store.save(HDRProfilePreference(), for: tv)
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test func 프로파일_이름과_경로로_찾기() {
        let profiles = [
            ColorProfileInfo(name: "sRGB IEC61966-2.1", path: "/s/sRGB Profile.icc", isFactoryDefault: false),
            ColorProfileInfo(name: "Rec. ITU-R BT.2020-1", path: "/s/ITU-2020.icc", isFactoryDefault: false),
            ColorProfileInfo(name: "Rec. ITU-R BT.709-5", path: "/s/ITU-709.icc", isFactoryDefault: false),
        ]
        #expect(ColorProfileCatalog.resolve("srgb", in: profiles)?.path == "/s/sRGB Profile.icc")
        #expect(ColorProfileCatalog.resolve("/s/ITU-2020.icc", in: profiles)?.name == "Rec. ITU-R BT.2020-1")
        #expect(ColorProfileCatalog.resolve("BT.2020", in: profiles)?.path == "/s/ITU-2020.icc")
        // 여러 개와 맞으면 거부.
        #expect(ColorProfileCatalog.resolve("Rec.", in: profiles) == nil)
        #expect(ColorProfileCatalog.resolve("없음", in: profiles) == nil)
    }
}
