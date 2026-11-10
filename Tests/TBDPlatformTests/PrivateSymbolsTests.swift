import CoreGraphics
import Foundation
import Testing
import TBDCore
@testable import TBDPlatform

/// TC-APP-004: 누락 심볼 처리.
@Suite("TC-APP-004 비공개 심볼 조회")
struct PrivateSymbolsTests {
    let symbols = PrivateSymbols()

    @Test func 누락_심볼은_nil() {
        #expect(symbols.address("TBDNoSuchSymbol_zzz", in: .skyLight) == nil)
        typealias Fn = @convention(c) () -> Void
        #expect(symbols.function("TBDNoSuchSymbol_zzz", in: .ioKit, as: Fn.self) == nil)
        #expect(symbols.objcClass("TBDNoSuchClass_zzz", in: .monitorPanel) == nil)
        // 같은 이름 재조회(캐시 경로)도 nil.
        #expect(symbols.address("TBDNoSuchSymbol_zzz", in: .skyLight) == nil)
    }

    @Test func 존재_심볼은_가용() {
        #expect(symbols.address("IOServiceMatching", in: .ioKit) != nil)
        #expect(symbols.isPresent(.function(.ioKit, "IORegistryEntryCreateCFProperty")))
    }

    @Test func 가용성_판정은_누락_심볼_이름을_보고() {
        let missing = Capability.hdr.status { requirement in
            requirement.name != "SLSDisplaySetHDRModeEnabled"
        }
        #expect(!missing.isAvailable)
        #expect(missing.missingSymbols == ["SLSDisplaySetHDRModeEnabled"])
        #expect(missing.unavailableReason?.contains("SLSDisplaySetHDRModeEnabled") == true)

        let present = Capability.hdr.status { _ in true }
        #expect(present.isAvailable)
        #expect(present.unavailableReason == nil)
    }

    @Test func 전체_기능_판정이_충돌_없이_완료() {
        let statuses = symbols.allStatuses()
        #expect(statuses.count == Capability.allCases.count)
        for status in statuses {
            #expect(status.isAvailable == status.missingSymbols.isEmpty)
        }
    }
}

/// TC-INF-001 일부: 디스플레이 목록 조회의 내부 일관성. 시스템 정보와의 대조는 `scripts/verify_t02.sh`.
@Suite("TC-INF-001 디스플레이 목록")
struct DisplayCatalogTests {
    @Test func 온라인_목록과_요약이_일치() {
        let ids = DisplayCatalog.onlineDisplayIDs()
        let displays = DisplayCatalog.displays()
        #expect(displays.count == ids.count)
        #expect(Set(displays.map(\.id)) == Set(ids))
        if !displays.isEmpty {
            #expect(displays.filter(\.isMain).count == 1)
            #expect(displays[0].isMain)
        }
        for d in displays {
            #expect(!d.identity.name.isEmpty)
            #expect(d.pixelWidth >= d.pointWidth)
            #expect(d.identity.isBuiltin == (CGDisplayIsBuiltin(d.id) != 0))
        }
    }
}

/// TC-INF-001: `system_profiler SPDisplaysDataType`와 대조.
@Suite("TC-INF-001 시스템 정보 대조")
struct DisplayCatalogSystemProfilerTests {
    struct ProfilerDisplay {
        var name: String
        var displayID: UInt32
        var pixels: String
        var resolution: String
        var isInternal: Bool
        var isMain: Bool
    }

    static func profilerDisplays() throws -> [ProfilerDisplay] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = ["SPDisplaysDataType", "-json"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let gpus = root?["SPDisplaysDataType"] as? [[String: Any]] ?? []
        return gpus.flatMap { $0["spdisplays_ndrvs"] as? [[String: Any]] ?? [] }.compactMap { d in
            guard let idText = d["_spdisplays_displayID"] as? String, let id = UInt32(idText, radix: 16) else { return nil }
            return ProfilerDisplay(
                name: d["_name"] as? String ?? "",
                displayID: id,
                pixels: d["_spdisplays_pixels"] as? String ?? "",
                resolution: d["_spdisplays_resolution"] as? String ?? "",
                isInternal: (d["spdisplays_connection_type"] as? String) == "spdisplays_internal",
                isMain: (d["spdisplays_main"] as? String) == "spdisplays_yes"
            )
        }
    }

    @Test func 디스플레이_수_이름_내장_여부_해상도_일치() throws {
        let expected = try Self.profilerDisplays()
        let actual = DisplayCatalog.displays()
        try #require(!expected.isEmpty, "system_profiler가 디스플레이를 보고하지 않음")
        #expect(actual.count == expected.count)
        for e in expected {
            let a = try #require(actual.first { $0.id == e.displayID }, "id \(e.displayID) 없음")
            #expect(a.identity.isBuiltin == e.isInternal)
            #expect(a.isMain == e.isMain)
            #expect("\(a.pixelWidth) x \(a.pixelHeight)" == e.pixels)
            #expect(e.resolution.hasPrefix("\(a.pointWidth) x \(a.pointHeight)"))
            if e.resolution.contains("@") {
                #expect(e.resolution.contains("@ \(String(format: "%.2f", a.refreshRate))Hz"))
            }
            // 내장 패널은 system_profiler가 패널 이름(Color LCD)을, NSScreen이 현지화 이름을 보고하므로 외장만 대조.
            if !e.isInternal { #expect(a.identity.name == e.name) }
        }
    }
}
