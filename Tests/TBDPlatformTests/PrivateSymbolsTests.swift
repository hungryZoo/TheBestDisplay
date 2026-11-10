import CoreGraphics
import IOKit
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

/// TC-INF-005: EDID 원본 획득. 외장 디스플레이가 없으면 검사 대상 없음.
@Suite("TC-INF-005 EDID 원본 획득")
struct EDIDSourceTests {
    @Test func 외장_디스플레이의_EDID_획득과_식별_정보_일치() throws {
        let displays = DisplayCatalog.displays()
        let externals = displays.filter { !$0.identity.isBuiltin }
        let records = EDIDSource.records(for: displays)
        try #require(!externals.isEmpty, "외장 디스플레이 없음: 이 테스트는 외장 디스플레이 연결 상태에서 실행")
        for display in externals {
            let record = try #require(records.first { $0.displayID == display.id }, "EDID 없음: \(display.identity.name)")
            #expect(record.data.count % 128 == 0)
            #expect(Array(record.data.prefix(8)) == [0x00, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x00])
            #expect(record.parsed.vendorNumber == display.identity.vendorID)
            #expect(UInt32(record.parsed.productCode) == display.identity.productID)
            #expect(record.source == "IOAVService" || record.source == "IORegistry")
        }
        // 내장 패널은 EDID 기록 없음.
        for display in displays where display.identity.isBuiltin {
            #expect(records.contains { $0.displayID == display.id } == false)
        }
    }
}

/// TC-MOD-001: 전체 모드 열거. 읽기 전용.
@Suite("TC-MOD-001 모드 열거")
struct ModeServiceTests {
    @Test func 전체_모드가_공개_API_이상이고_현재_모드가_1개() throws {
        let displays = DisplayCatalog.displays()
        try #require(!displays.isEmpty)
        for display in displays {
            let modes = ModeService.modes(for: display.id)
            let publicCount = ModeService.publicCGModes(for: display.id, includeDuplicates: true).count
            #expect(modes.count >= publicCount, "\(display.identity.name)")
            #expect(Set(modes.map(\.modeNumber)).count == modes.count, "모드 번호 중복")
            let current = try #require(ModeService.currentMode(for: display.id, in: modes))
            #expect(modes.filter { $0.modeNumber == current.modeNumber }.count == 1)
            // 현재 모드가 CoreGraphics 보고값과 일치.
            #expect(current.width == display.pointWidth)
            #expect(current.height == display.pointHeight)
            #expect(current.pixelWidth == display.pixelWidth)
            #expect(abs(current.refreshRate - display.refreshRate) < 0.01)
            // 시스템 판정: 원본 모드 1개 이상, 현재 모드는 서술로 다시 찾을 수 있음.
            #expect(modes.contains { $0.isNative })
            #expect(current.descriptor.find(in: modes)?.modeNumber == current.modeNumber)
        }
    }
}

/// TC-COL-002: 현재 신호 형식 조회. 읽기 전용.
@Suite("TC-COL-002 현재 신호 조회")
struct SignalServiceTests {
    @Test func 타이밍_ID와_색_모드가_레지스트리와_링크_데이터에_일치() throws {
        let displays = DisplayCatalog.displays()
        try #require(!displays.isEmpty)
        for display in displays {
            let info = try #require(SignalService.signalInfo(for: display), "신호 정보 없음: \(display.identity.name)")
            let node = try #require(SignalService.framebufferNode(for: display))
            defer { IOObjectRelease(node.service) }
            // 현재 타이밍 ID가 레지스트리의 DPTimingModeId와 일치.
            #expect(info.currentTimingID == (node.properties["DPTimingModeId"] as? NSNumber)?.intValue)
            let timing = try #require(info.currentTiming)
            let color = try #require(info.currentColor)
            #expect(timing.colorModes.contains { $0.id == color.id })
            // 프레임버퍼 해상도와 타이밍의 활성 픽셀 일치.
            #expect(timing.hActive == (node.properties["DisplayWidth"] as? NSNumber)?.intValue)
            #expect(timing.vActive == (node.properties["DisplayHeight"] as? NSNumber)?.intValue)
            if display.identity.isBuiltin {
                #expect(info.linkData == nil)
            } else if let link = info.linkData {
                // 실제 송출값과 선택된 색 모드, 타이밍이 일치.
                #expect(link.pixelEncoding == color.pixelEncoding)
                #expect(link.bitsPerComponent == color.bitsPerComponent)
                #expect(link.dynamicRange == color.dynamicRange)
                #expect(link.eotf == color.eotf)
                #expect((link.hActive, link.vActive) == (timing.hActive, timing.vActive))
                #expect((link.hTotal, link.vTotal) == (timing.hTotal, timing.vTotal))
                #expect(abs(link.refreshRate - timing.refreshRate) < 0.01)
                #expect(abs(link.pixelClockHz - timing.pixelClockHz) < 1000)
            } else {
                Issue.record("외장 디스플레이의 링크 데이터를 읽지 못함: \(display.identity.name)")
            }
        }
    }
}

/// TC-HDR-001: HDR 상태 조회. 읽기 전용.
@Suite("TC-HDR-001 HDR 상태 조회")
struct HDRServiceTests {
    @Test func 윈도우_서버와_시스템_설정_판정이_일치() throws {
        let displays = DisplayCatalog.displays()
        try #require(!displays.isEmpty)
        let records = EDIDSource.records(for: displays)
        for display in displays {
            let edid = records.first { $0.displayID == display.id }?.parsed
            let status = HDRService.status(for: display, edid: edid)
            let bridge = try #require(MPDisplayBridge(display: display.id))
            // 시스템 설정(MPDisplay)의 판정과 대조.
            #expect(status.isSupported == bridge.bool("hasHDRModes"))
            if status.isSupported {
                #expect(status.isEnabled == bridge.bool("preferHDRModes"))
                // HDR 지원 디스플레이는 EDID에 HDR 전달 함수 선언.
                if edid != nil { #expect(!status.supportedEOTFs.isEmpty) }
            } else {
                #expect(!status.isEnabled)
            }
            let maxEDR = try #require(status.maxEDRHeadroom)
            #expect(maxEDR >= 1)
            // 신호의 전달 함수와 HDR 상태 일치 (외장 디스플레이).
            if status.isSupported, let link = SignalService.linkData(for: display) {
                #expect(link.eotf.isHDR == status.isEnabled)
            }
        }
    }
}
