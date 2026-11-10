import CoreGraphics
import IOKit
import Foundation
import Testing
import TBDCore
@testable import TBDPlatform

/// 시험 장비 조건. 조건이 맞지 않는 테스트는 실패가 아니라 건너뜀으로 기록.
enum Hardware {
    static var hasExternalDisplay: Bool { DisplayCatalog.displays().contains { !$0.identity.isBuiltin } }
    static var hasBuiltinDisplay: Bool { DisplayCatalog.displays().contains { $0.identity.isBuiltin } }
    static var displayCount: Int { DisplayCatalog.onlineDisplayIDs().count }
}

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
    @Test(.enabled(if: Hardware.hasExternalDisplay, "외장 디스플레이 필요"))
    func 외장_디스플레이의_EDID_획득과_식별_정보_일치() throws {
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
            // 화면 객체가 없는 디스플레이(미러 대상 등)는 헤드룸 조회 불가.
            if let maxEDR = status.maxEDRHeadroom { #expect(maxEDR >= 1) }
            // 신호의 전달 함수와 HDR 상태 일치 (외장 디스플레이).
            if status.isSupported, let link = SignalService.linkData(for: display) {
                #expect(link.eotf.isHDR == status.isEnabled)
            }
        }
    }
}

/// TC-LNK-001: 링크 정보 조회. 읽기 전용.
@Suite("TC-LNK-001 링크 정보 조회")
struct LinkServiceTests {
    @Test(.enabled(if: Hardware.hasExternalDisplay, "외장 디스플레이 필요"))
    func 외장_디스플레이의_전송_상태가_레지스트리_값과_일치() throws {
        let displays = DisplayCatalog.displays()
        let externals = displays.filter { !$0.identity.isBuiltin }
        try #require(!externals.isEmpty, "외장 디스플레이 없음")
        // 레지스트리 원시 속성.
        let raw: [[String: Any]] = IORegistry.forEachService(matching: "IOPortTransportStateDisplayPort") { IORegistry.properties($0) }
        for display in externals {
            let state = try #require(LinkService.transportState(for: display), "전송 상태 대응 실패: \(display.identity.name)")
            let node = try #require(raw.first { ($0["TransportDescription"] as? String) == state.transportDescription })
            #expect(state.isActive)
            #expect(state.laneCount == (node["LaneCount"] as? NSNumber)?.intValue)
            #expect(state.maxLaneCount == (node["MaxLaneCount"] as? NSNumber)?.intValue)
            #expect(state.isTunneled == (node["Tunneled"] as? NSNumber)?.boolValue)
            #expect(state.hpdDescription == node["HPD_StateDescription"] as? String)
            #expect(state.linkRateDescription == node["LinkRateDescription"] as? String)
            #expect(state.productName == display.identity.name)
            #expect(state.hasLink)
            let rate = try #require(state.laneRateGbps)
            #expect(state.linkRateDescription.hasPrefix(String(format: "%.1f", rate)))

            let signal = SignalService.signalInfo(for: display)
            let report = LinkService.report(for: display, signal: signal, dsc: nil)
            let available = try #require(report.availableGbps)
            let required = try #require(report.requiredGbps)
            // 무압축 송출 중이면 필요 대역폭이 유효 대역폭 이내.
            #expect(required <= available)
            // 링크 훈련 데이터와 전송 상태의 레인 수 일치.
            if let training = LinkService.linkTraining(for: display) {
                #expect(training.laneCount == state.laneCount)
            }
        }
    }

    @Test func 내장_패널은_링크_훈련_데이터로_보고() throws {
        let displays = DisplayCatalog.displays()
        guard let builtin = displays.first(where: { $0.identity.isBuiltin }) else { return }
        #expect(LinkService.transportState(for: builtin) == nil)
        let report = LinkService.report(for: builtin, signal: SignalService.signalInfo(for: builtin), dsc: nil)
        #expect(report.transportName == "내장 패널 (eDP)")
        if let available = report.availableGbps, let required = report.requiredGbps {
            #expect(required <= available)
        }
    }
}

/// TC-PRT-001: 포트와 케이블 정보 조회. 읽기 전용.
@Suite("TC-PRT-001 포트 정보 조회")
struct PortServiceTests {
    @Test func 포트_목록과_연결_경로가_레지스트리와_일치() throws {
        let inventory = PortService.inventory()
        try #require(!inventory.ports.isEmpty, "포트 컨트롤러 노드 없음")
        // 포트 설명 문자열이 레지스트리의 포트 컨트롤러 노드와 1대1 대응.
        var registryPorts = Set<String>()
        for className in PortInventory.relevantClasses where className.hasPrefix("AppleHPM") || className.hasPrefix("AppleTC") || className == "AppleHDMIPortController" {
            let names: [String] = IORegistry.forEachService(matching: className) { IORegistry.property($0, "PortDescription") as? String }
            registryPorts.formUnion(names)
        }
        #expect(Set(inventory.ports.map(\.portDescription)) == registryPorts)
        for port in inventory.ports {
            #expect(port.transportsActive.allSatisfy { port.transportsSupported.contains($0) || port.transportsProvisioned.contains($0) })
        }

        let displays = DisplayCatalog.displays()
        let paths = ConnectionPathBuilder.build(inventory: inventory, displays: displays)
        #expect(paths.count == inventory.ports.count)
        // 외장 디스플레이마다 경로 1개가 도달.
        for display in displays where !display.identity.isBuiltin {
            let reaching = paths.filter { $0.displayID == display.id }
            #expect(reaching.count == 1, "\(display.identity.name)")
            if let path = reaching.first {
                #expect(path.steps.last?.kind == .display)
                #expect(path.steps.allSatisfy { $0.status != .broken })
                #expect(path.dp?.isActive == true)
            }
        }
        // 디스플레이에 도달한 경로 수는 외장 디스플레이 수 이하.
        #expect(paths.filter(\.reachesDisplay).count <= displays.filter { !$0.identity.isBuiltin }.count)
    }
}

/// TC-BRT-001, TC-BRT-003: 내장 디스플레이 밝기와 자동 밝기. 값을 바꾼 뒤 원래 값으로 복원.
@Suite("TC-BRT-001 내장 디스플레이 밝기", .serialized)
struct BrightnessServiceTests {
    @Test(.enabled(if: Hardware.hasBuiltinDisplay, "내장 디스플레이 필요"))
    func 밝기_조회_설정_복원() throws {
        let builtin = try #require(DisplayCatalog.displays().first { $0.identity.isBuiltin })
        #expect(BrightnessService.supportsNative(builtin))
        #expect(BrightnessService.method(for: builtin, ddc: nil) == .native)
        let original = try #require(BrightnessService.nativeBrightness(builtin.id))
        #expect((0...1).contains(original))
        let target = original > 0.5 ? original - 0.1 : original + 0.1
        try BrightnessService.setNativeBrightness(target, on: builtin.id)
        usleep(400_000)
        let changed = try #require(BrightnessService.nativeBrightness(builtin.id))
        try BrightnessService.setNativeBrightness(original, on: builtin.id)
        usleep(400_000)
        let restored = try #require(BrightnessService.nativeBrightness(builtin.id))
        #expect(abs(changed - target) < 0.02)
        #expect(abs(restored - original) < 0.02)
    }

    @Test(.enabled(if: Hardware.hasBuiltinDisplay, "내장 디스플레이 필요"))
    func 자동_밝기_반전과_복원() throws {
        let builtin = try #require(DisplayCatalog.displays().first { $0.identity.isBuiltin })
        try #require(BrightnessService.hasAutoBrightness(builtin.id), "자동 밝기 미지원 기기")
        let original = try #require(BrightnessService.autoBrightnessEnabled(builtin.id))
        // 자동 밝기를 다시 켜면 시스템이 밝기를 새로 계산하므로 시험 전 밝기도 함께 복원.
        let brightness = BrightnessService.nativeBrightness(builtin.id)
        try BrightnessService.setAutoBrightness(!original, on: builtin.id)
        usleep(300_000)
        let changed = BrightnessService.autoBrightnessEnabled(builtin.id)
        try BrightnessService.setAutoBrightness(original, on: builtin.id)
        usleep(300_000)
        if let brightness { try BrightnessService.setNativeBrightness(brightness, on: builtin.id) }
        #expect(changed == !original)
        #expect(BrightnessService.autoBrightnessEnabled(builtin.id) == original)
    }

    @Test func 내장_패널은_DDC_대상_아님() throws {
        guard let builtin = DisplayCatalog.displays().first(where: { $0.identity.isBuiltin }) else { return }
        #expect(DDCService.probe(for: builtin).status == .notApplicable)
    }
}

/// TC-BRT-002 실측: 전달 테이블 적용과 복원. 화면이 잠깐 어두워짐.
@Suite("TC-BRT-002 소프트웨어 디밍 실측", .serialized)
struct GammaServiceTests {
    @Test func 디밍_적용_후_복원() throws {
        let display = try #require(DisplayCatalog.displays().first)
        let service = GammaService()
        let before = try #require(GammaService.currentTable(display.id))
        var adjustment = ColorAdjustment()
        adjustment.dimming = 0.8
        try service.apply(adjustment, to: display.id)
        let dimmed = try #require(GammaService.currentTable(display.id))
        // 재구성 알림 없이 다시 적용을 요청해도 겹쳐 적용되지 않음.
        service.reapply(onlineDisplays: [display.id])
        let afterReapply = try #require(GammaService.currentTable(display.id))
        try service.apply(.identity, to: display.id)
        let restored = try #require(GammaService.currentTable(display.id))

        #expect(abs(dimmed.red.last! - before.red.last! * 0.8) < 0.01)
        #expect(dimmed.isMonotonic)
        #expect(GammaService.approximatelyEqual(dimmed, afterReapply))
        #expect(GammaService.approximatelyEqual(before, restored))
        #expect(service.adjustment(for: display.id).isIdentity)
    }
}

/// TC-CLR-001: 색 프로파일 열거와 지정. 지정 뒤 원래 프로파일로 복원.
@Suite("TC-CLR-001 색 프로파일", .serialized)
struct ColorProfileServiceTests {
    @Test func 목록과_현재_프로파일() throws {
        for display in DisplayCatalog.displays() {
            let available = ColorProfileService.available(for: display.id)
            #expect(!available.isEmpty, "\(display.identity.name)")
            #expect(Set(available.map(\.path)).count == available.count)
            #expect(available.filter(\.isFactoryDefault).count <= 1)
            let current = try #require(ColorProfileService.current(for: display.id))
            #expect(!current.name.isEmpty)
        }
    }

    @Test func 지정_후_복원() throws {
        let display = try #require(DisplayCatalog.displays().first)
        let original = try #require(ColorProfileService.current(for: display.id))
        let available = ColorProfileService.available(for: display.id)
        let target = try #require(available.first { $0.name.hasPrefix("sRGB") && $0.path != original.path } ?? available.first { $0.path != original.path && !$0.isFactoryDefault })
        try ColorProfileService.set(target, for: display.id)
        usleep(500_000)
        let changed = ColorProfileService.current(for: display.id)
        try ColorProfileService.set(original, for: display.id)
        usleep(500_000)
        let restored = ColorProfileService.current(for: display.id)
        #expect(changed?.name == target.name)
        #expect(restored?.name == original.name)
        #expect(restored?.path == original.path)
    }
}

/// TC-CLR-002: Night Shift와 True Tone. 반전 뒤 원래 상태로 복원.
@Suite("TC-CLR-002 Night Shift와 True Tone", .serialized)
struct NightShiftTrueToneTests {
    @Test func Night_Shift_반전과_복원() throws {
        let original = try #require(NightShiftService.status())
        try #require(original.isSupported, "Night Shift 미지원 기기")
        try NightShiftService.setEnabled(!original.isEnabled)
        usleep(600_000)
        let changed = NightShiftService.status()
        try NightShiftService.setEnabled(original.isEnabled)
        usleep(600_000)
        let restored = NightShiftService.status()
        #expect(changed?.isEnabled == !original.isEnabled)
        #expect(restored?.isEnabled == original.isEnabled)
    }

    @Test func Night_Shift_강도_변경과_복원() throws {
        let original = try #require(NightShiftService.status())
        let strength = try #require(original.strength)
        let target = strength > 0.5 ? strength - 0.2 : strength + 0.2
        try NightShiftService.setStrength(target)
        usleep(300_000)
        let changed = NightShiftService.status()?.strength
        try NightShiftService.setStrength(strength)
        usleep(300_000)
        #expect(abs((changed ?? -1) - target) < 0.02)
        #expect(abs((NightShiftService.status()?.strength ?? -1) - strength) < 0.02)
    }

    @Test func True_Tone_반전과_복원() throws {
        let original = try #require(TrueToneService.status())
        try #require(original.isSupported && original.isAvailable, "True Tone을 쓸 수 없는 구성")
        try TrueToneService.setEnabled(!original.isEnabled)
        usleep(600_000)
        let changed = TrueToneService.status()
        try TrueToneService.setEnabled(original.isEnabled)
        usleep(600_000)
        #expect(changed?.isEnabled == !original.isEnabled)
        #expect(TrueToneService.status()?.isEnabled == original.isEnabled)
    }
}

/// TC-VRT-001 실측: 가상 디스플레이 생성과 삭제.
@Suite("TC-VRT-001 가상 디스플레이 생성", .serialized)
struct VirtualDisplayServiceTests {
    @Test func 생성_후_온라인_목록_증가_삭제_후_원복() throws {
        let service = VirtualDisplayService()
        let before = DisplayCatalog.onlineDisplayIDs()
        let config = VirtualDisplayConfig(name: "TBD 시험용", width: 1920, height: 1080, hiDPI: true)
        let id = try service.create(config)
        let during = DisplayCatalog.onlineDisplayIDs()
        let summary = DisplayCatalog.displays().first { $0.id == id }
        let modes = ModeService.modes(for: id)
        // 같은 구성의 재생성 요청은 기존 디스플레이 반환.
        let again = try service.create(config)
        service.destroy(config.id)
        var after = DisplayCatalog.onlineDisplayIDs()
        for _ in 0..<30 where after.contains(id) {
            usleep(100_000)
            after = DisplayCatalog.onlineDisplayIDs()
        }

        #expect(during.count == before.count + 1)
        #expect(during.contains(id))
        #expect(again == id)
        #expect(summary?.identity.vendorID == VirtualDisplayService.vendorID)
        #expect(summary?.identity.productID == VirtualDisplayService.productID)
        #expect(summary?.identity.serialNumber == config.serialNumber)
        #expect(summary?.identity.isBuiltin == false)
        #expect(summary.map { ($0.pointWidth, $0.pointHeight) } ?? (0, 0) == (1920, 1080))
        #expect(summary?.pixelWidth == 3840)
        #expect(modes.contains { $0.width == 1920 && $0.height == 1080 && $0.isHiDPI })
        #expect(Set(after) == Set(before))
        #expect(service.activeDisplayIDs.isEmpty)
    }

    @Test func 잘못된_구성은_생성_전에_거부() {
        let service = VirtualDisplayService()
        #expect(throws: DisplayChangeError.self) {
            try service.create(VirtualDisplayConfig(name: "", width: 100, height: 100, hiDPI: false))
        }
        #expect(service.activeDisplayIDs.isEmpty)
    }
}
