import Foundation
import Testing
@testable import TBDCore

enum SnapshotFixture {
    static let system = SystemInfo(chipName: "Apple M5", modelIdentifier: "Mac17,2", osVersion: "26.5.2", lidClosed: false, hasBuiltinDisplay: true)

    /// 실측 구성: 내장 + LG TV (USB-C 4번, 독 경유, 3840x2160 120 Hz, YCbCr 4:2:2 12 bpc PQ).
    static func normal() throws -> DiagnosticSnapshot {
        let inventory = try RegistryFixture.inventory(RegistryFixture.normal)
        let displays = [RegistryFixture.lgTV, RegistryFixture.builtin]
        let signal = try SignalFixture.lgTV()
        let state = try #require(inventory.dpStates.first { $0.isActive })
        let dsc = DSCAssessment.assess(signal: signal, edidSupportsDSC: nil, sourceSupportsDSC: true)
        let edidBytes = try Fixture.lgTV()
        let tv = DisplayDiagnostics(
            summary: RegistryFixture.lgTV,
            edid: EDIDParser.parse(edidBytes),
            edidHex: edidBytes.map { String(format: "%02x", $0) }.joined(),
            currentMode: mode(149, 2304, 1296, hidpi: true, hz: 120),
            modeCount: 319,
            signal: signal,
            dsc: dsc,
            hdr: HDRStatus(displayID: 2, isSupported: true, isEnabled: true, currentEDRHeadroom: 1, maxEDRHeadroom: 10, supportedEOTFs: ["PQ (HDR10)", "HLG"], maxLuminance: nil),
            link: LinkAnalyzer.report(display: RegistryFixture.lgTV, signal: signal, state: state, dscActive: dsc.isActive, fecEnabled: nil),
            dpcd: DPCDDecoder.decode(receiverCaps: [0x14, 0x1E, 0xC4, 0x01, 0, 0, 0x01, 0], dscCaps: [0, 0], linkConfig: [0x1E, 0x84], dscEnable: [0], status: [1, 0, 0x77, 0x77, 1], extendedCaps: nil)
        )
        let builtin = DisplayDiagnostics(summary: RegistryFixture.builtin, modeCount: 132)
        return DiagnosticSnapshot(
            capturedAt: Date(timeIntervalSince1970: 1_800_000_000),
            system: system,
            displays: [tv, builtin],
            inventory: inventory,
            paths: ConnectionPathBuilder.build(inventory: inventory, displays: displays),
            attachedFramebuffers: [
                AttachedFramebuffer(isExternal: false, productName: nil, productID: nil, serialNumber: nil),
                AttachedFramebuffer(isExternal: true, productName: "LG TV SSCR2", productID: 49352, serialNumber: 16843009),
            ]
        )
    }

    /// USB-C 4번의 전송 상태와 온라인 여부를 바꾼 합성 스냅샷.
    static func synthetic(tvOnline: Bool, framebufferAttached: Bool, _ mutate: (inout PortInventory) -> Void) throws -> DiagnosticSnapshot {
        var inventory = try RegistryFixture.inventory(RegistryFixture.normal)
        mutate(&inventory)
        let displays = tvOnline ? [RegistryFixture.lgTV, RegistryFixture.builtin] : [RegistryFixture.builtin]
        var framebuffers = [AttachedFramebuffer(isExternal: false, productName: nil, productID: nil, serialNumber: nil)]
        if framebufferAttached { framebuffers.append(AttachedFramebuffer(isExternal: true, productName: "LG TV SSCR2", productID: 49352, serialNumber: 16843009)) }
        return DiagnosticSnapshot(
            capturedAt: Date(timeIntervalSince1970: 1_800_000_000), system: system,
            displays: displays.map { DisplayDiagnostics(summary: $0) },
            inventory: inventory,
            paths: ConnectionPathBuilder.build(inventory: inventory, displays: displays),
            attachedFramebuffers: framebuffers
        )
    }

    static func editPort4(_ inventory: inout PortInventory, _ edit: (inout DPTransportState) -> Void) {
        for i in inventory.dpStates.indices where inventory.dpStates[i].parentPortType == "USB-C" && inventory.dpStates[i].parentPortNumber == 4 {
            edit(&inventory.dpStates[i])
        }
    }

    static let port4 = PortKey(type: "USB-C", number: 4)
}

/// TC-DGN-001: 미출력 진단 규칙.
@Suite("TC-DGN-001 미출력 진단")
struct OutageDiagnosisTests {
    func result(_ snapshot: DiagnosticSnapshot) throws -> (PortDiagnosis, [Finding]) {
        let result = DiagnosticEngine.evaluate(snapshot)
        let diagnosis = try #require(result.portDiagnoses.first { $0.port == SnapshotFixture.port4 })
        return (diagnosis, result.findings.filter { $0.subject == "USB-C 4번" })
    }

    @Test func 정상은_전_단계_통과() throws {
        let (diagnosis, findings) = try result(try SnapshotFixture.normal())
        #expect(diagnosis.isFullyPassed)
        #expect(diagnosis.checks.map(\.stage) == PortDiagnosis.Stage.allCases)
        #expect(findings.isEmpty)
    }

    @Test func 연결_없는_포트는_점검_대상_아님() throws {
        let snapshot = try SnapshotFixture.normal()
        let result = DiagnosticEngine.evaluate(snapshot)
        // 영상 출력 지원 포트만 점검 (MagSafe 제외).
        #expect(result.portDiagnoses.map(\.port.label) == ["USB-C 1번", "USB-C 2번", "HDMI 3번", "USB-C 4번"])
        let idle = try #require(result.portDiagnoses.first { $0.port == PortKey(type: "USB-C", number: 1) })
        #expect(idle.isIdle)
        #expect(idle.firstFailure == .physical)
        #expect(!result.findings.contains { $0.subject == "USB-C 1번" })
    }

    @Test func HPD_없음() throws {
        let snapshot = try SnapshotFixture.synthetic(tvOnline: false, framebufferAttached: false) { inventory in
            SnapshotFixture.editPort4(&inventory) { $0.hpdState = 0; $0.hpdDescription = "Low"; $0.isActive = false; $0.laneCount = 0; $0.laneRateGbps = nil; $0.edid = nil; $0.sinkCount = 0 }
        }
        let (diagnosis, findings) = try result(snapshot)
        #expect(diagnosis.firstFailure == .hpd)
        #expect(diagnosis.checks.filter { $0.result == .skipped }.map(\.stage) == [.edid, .link, .framebuffer, .online])
        #expect(findings.map(\.code) == ["LINK.DOCK_NO_DISPLAY"])
        #expect(findings[0].detail.contains("Parade Technologies PS9010"))
    }

    @Test func EDID_없음() throws {
        let snapshot = try SnapshotFixture.synthetic(tvOnline: false, framebufferAttached: false) { inventory in
            SnapshotFixture.editPort4(&inventory) { $0.isActive = false; $0.laneCount = 0; $0.laneRateGbps = nil; $0.edid = nil }
        }
        let (diagnosis, findings) = try result(snapshot)
        #expect(diagnosis.firstFailure == .edid)
        #expect(findings.map(\.code) == ["LINK.NO_EDID"])
        #expect(findings[0].severity == .error)
    }

    @Test func 링크_없음() throws {
        let snapshot = try SnapshotFixture.synthetic(tvOnline: false, framebufferAttached: false) { inventory in
            SnapshotFixture.editPort4(&inventory) { $0.isActive = false; $0.laneCount = 0; $0.laneRateGbps = nil; $0.linkRateDescription = "No Link"; $0.sinkCount = 0 }
        }
        let (diagnosis, findings) = try result(snapshot)
        #expect(diagnosis.firstFailure == .link)
        #expect(findings.map(\.code) == ["LINK.HPD_NO_LINK"])
        #expect(findings[0].detail.contains("No Link"))
        #expect(findings[0].remedy.contains("독 전원 재인가"))
    }

    @Test func 프레임버퍼_미할당과_온라인_미등록() throws {
        let noPipe = try SnapshotFixture.synthetic(tvOnline: false, framebufferAttached: false) { _ in }
        let (d1, f1) = try result(noPipe)
        #expect(d1.firstFailure == .framebuffer)
        #expect(f1.map(\.code) == ["DISPLAY.NO_PIPE"])

        let offline = try SnapshotFixture.synthetic(tvOnline: false, framebufferAttached: true) { _ in }
        let (d2, f2) = try result(offline)
        #expect(d2.firstFailure == .online)
        #expect(f2.map(\.code) == ["DISPLAY.NOT_ONLINE"])
    }

    @Test func T04_사고_시점_픽스처() throws {
        let inventory = try RegistryFixture.inventory(RegistryFixture.noLink)
        let displays = [RegistryFixture.builtin]
        let snapshot = DiagnosticSnapshot(
            capturedAt: Date(), system: SnapshotFixture.system, displays: displays.map { DisplayDiagnostics(summary: $0) }, inventory: inventory,
            paths: ConnectionPathBuilder.build(inventory: inventory, displays: displays),
            attachedFramebuffers: [AttachedFramebuffer(isExternal: false, productName: nil, productID: nil, serialNumber: nil)]
        )
        let (diagnosis, findings) = try result(snapshot)
        // HPD는 감지되었으나 그 뒤 단계에서 실패.
        #expect(diagnosis.checks[0].result == .pass)
        #expect(diagnosis.checks[1].result == .pass)
        let failure = try #require(diagnosis.firstFailure)
        #expect(failure == .edid || failure == .link)
        #expect(findings.count == 1)
        #expect(findings[0].severity == .error)
        #expect(!findings[0].remedy.isEmpty)
    }

    @Test func USB_2_전용_케이블() throws {
        let snapshot = try SnapshotFixture.synthetic(tvOnline: false, framebufferAttached: false) { inventory in
            inventory.cables = inventory.cables.map { var c = $0; c.speedCode = 0; return c }
            inventory.cioStates = []
            SnapshotFixture.editPort4(&inventory) { $0.hpdState = 0; $0.hpdDescription = "Low"; $0.isActive = false; $0.laneCount = 0; $0.laneRateGbps = nil; $0.edid = nil; $0.isTunneled = false }
        }
        let (_, findings) = try result(snapshot)
        #expect(findings.map(\.code) == ["CABLE.USB2_ONLY", "PORT.NO_VIDEO_SIGNAL"])
        #expect(findings[0].severity == .error)
    }

    @Test func 모든_발견_항목에_조치_문구() throws {
        for snapshot in [try SnapshotFixture.normal(), try SnapshotFixture.synthetic(tvOnline: false, framebufferAttached: false) { _ in }] {
            for finding in DiagnosticEngine.evaluate(snapshot).findings {
                #expect(!finding.remedy.isEmpty, "\(finding.code)")
                #expect(!finding.detail.isEmpty, "\(finding.code)")
                #expect(finding.code.contains("."), "\(finding.code)")
            }
        }
    }
}

/// TC-DGN-002: 모드 제한 진단.
@Suite("TC-DGN-002 모드 제한 진단")
struct ModeLimitDiagnosisTests {
    @Test func 실측_구성의_대역폭_초과와_DSC_미지원() throws {
        let findings = DiagnosticEngine.evaluate(try SnapshotFixture.normal()).findings.filter { $0.subject == "LG TV SSCR2" }
        let limit = try #require(findings.first { $0.code == "LINK.BANDWIDTH_LIMIT" })
        #expect(limit.detail.contains("유효 대역폭 25.92 Gbps"))
        #expect(limit.detail.contains("RGB 4:4:4, 10 bpc"))
        #expect(limit.detail.contains("32.14 Gbps"))
        #expect(limit.detail.contains("수신 측이 DSC 압축 미지원"))
        #expect(limit.detail.contains("HBR3 x 4레인"))
        #expect(limit.remedy.contains("Parade Technologies PS9010"))
        #expect(limit.remedy.contains("주사율"))
    }

    @Test func 크로마_서브샘플링_안내는_HDR_끄기_제안() throws {
        let findings = DiagnosticEngine.evaluate(try SnapshotFixture.normal()).findings
        let chroma = try #require(findings.first { $0.code == "SIGNAL.CHROMA_SUBSAMPLED" })
        #expect(chroma.severity == .warning)
        #expect(chroma.title.contains("YCbCr 4:2:2"))
        #expect(chroma.remedy.contains("HDR을 끄면"))
        #expect(findings.contains { $0.code == "LINK.NEAR_CAPACITY" })
        // 심각도 높은 항목이 앞.
        #expect(findings.map(\.severity) == findings.map(\.severity).sorted(by: >))
    }

    @Test func RGB_출력_중이면_서브샘플링_안내_없음() throws {
        var snapshot = try SnapshotFixture.normal()
        var signal = try SignalFixture.lgTV(currentColorID: 100)
        signal.linkData = nil
        snapshot.displays[0].signal = signal
        let findings = DiagnosticEngine.evaluate(snapshot).findings
        #expect(!findings.contains { $0.code == "SIGNAL.CHROMA_SUBSAMPLED" })
    }

    @Test func 레인_축소와_낮은_링크_속도() throws {
        var snapshot = try SnapshotFixture.normal()
        var state = try #require(snapshot.displays[0].link?.state)
        state.laneCount = 2
        state.laneRateGbps = 5.4
        state.linkRateDescription = "5.4 Gbps (HBR2)"
        snapshot.displays[0].link = LinkAnalyzer.report(display: RegistryFixture.lgTV, signal: snapshot.displays[0].signal, state: state, dscActive: false, fecEnabled: nil)
        let findings = DiagnosticEngine.evaluate(snapshot).findings
        #expect(findings.contains { $0.code == "LINK.LANES_REDUCED" })
        let slow = try #require(findings.first { $0.code == "LINK.RATE_BELOW_SINK_MAX" })
        #expect(slow.detail.contains("HBR2"))
        #expect(slow.detail.contains("HBR3"))
        // 유효 8.64 Gbps에 현재 모드 25.71 Gbps: 계산상 초과.
        #expect(findings.contains { $0.code == "LINK.OVER_BUDGET" })
    }

    @Test func 레인_상태_불량과_DSC_사용() throws {
        var snapshot = try SnapshotFixture.normal()
        snapshot.displays[0].dpcd = DPCDDecoder.decode(receiverCaps: [0x14, 0x1E, 0xC4, 0x01, 0, 0, 0x01, 0], dscCaps: nil, linkConfig: [0x1E, 0x84], dscEnable: nil, status: [1, 0, 0x77, 0x17, 1], extendedCaps: nil)
        snapshot.displays[0].dsc?.isActive = true
        let findings = DiagnosticEngine.evaluate(snapshot).findings
        let lane = try #require(findings.first { $0.code == "LINK.LANE_STATUS_BAD" })
        #expect(lane.severity == .error)
        #expect(lane.detail.contains("레인 3"))
        #expect(findings.contains { $0.code == "DSC.ACTIVE" })
    }
}

/// TC-DGN-003: 시스템 제약 점검.
@Suite("TC-DGN-003 시스템 제약")
struct SystemConstraintTests {
    @Test func 칩별_외장_디스플레이_한도_추정() {
        func limit(_ chip: String, builtin: Bool = true) -> Int? {
            SystemInfo(chipName: chip, modelIdentifier: "", osVersion: "", lidClosed: false, hasBuiltinDisplay: builtin).estimatedExternalDisplayLimit
        }
        #expect(limit("Apple M1") == 1)
        #expect(limit("Apple M3") == 1)
        #expect(limit("Apple M4") == 2)
        #expect(limit("Apple M5") == 2)
        #expect(limit("Apple M2 Pro") == 2)
        #expect(limit("Apple M4 Max") == 4)
        #expect(limit("Apple M2 Ultra") == nil)
        #expect(limit("Apple M4", builtin: false) == nil)
        #expect(limit("Intel(R) Core(TM) i9") == nil)
    }

    @Test func 한도_도달_발견_항목() throws {
        var snapshot = try SnapshotFixture.normal()
        #expect(!DiagnosticEngine.evaluate(snapshot).findings.contains { $0.code == "SYSTEM.EXTERNAL_LIMIT" })
        snapshot.system.chipName = "Apple M1"
        let finding = try #require(DiagnosticEngine.evaluate(snapshot).findings.first { $0.code == "SYSTEM.EXTERNAL_LIMIT" })
        #expect(finding.severity == .info)
        #expect(finding.detail.contains("1대"))

        // 한도에 도달한 상태에서 다른 포트의 디스플레이가 화면 구성에 들지 못하면 주의로 격상.
        var blocked = try SnapshotFixture.synthetic(tvOnline: false, framebufferAttached: false) { _ in }
        blocked.system.chipName = "Apple M1"
        blocked.displays.append(DisplayDiagnostics(summary: DisplaySelectorTests.display(7, "다른 모니터")))
        let findings = DiagnosticEngine.evaluate(blocked).findings
        #expect(findings.first { $0.code == "SYSTEM.EXTERNAL_LIMIT" }?.severity == .warning)
        #expect(findings.first { $0.code == "DISPLAY.NO_PIPE" }?.detail.contains("한도 추정치 1대") == true)
    }

    @Test func 덮개_닫힘() throws {
        var snapshot = try SnapshotFixture.normal()
        snapshot.system.lidClosed = true
        #expect(DiagnosticEngine.evaluate(snapshot).findings.contains { $0.code == "SYSTEM.LID_CLOSED" })
    }
}

/// TC-DGN-004: 이벤트 기록.
@Suite("TC-DGN-004 이벤트 기록")
struct EventLogTests {
    let date = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func 스냅샷_차이로_이벤트_생성() throws {
        let before = EventState(try SnapshotFixture.normal())
        var changed = try SnapshotFixture.normal()
        changed.displays[0].currentMode = mode(153, 2304, 1296, hidpi: true, hz: 60)
        changed.displays[0].hdr?.isEnabled = false
        var signal = try SignalFixture.lgTV(currentColorID: 100)
        signal.linkData = nil
        changed.displays[0].signal = signal

        var log = EventLog()
        #expect(log.record(from: before, to: EventState(changed), at: date) == 3)
        #expect(log.events.map(\.kind) == [.modeChanged, .colorModeChanged, .hdrChanged])
        #expect(log.events[0].subject == "LG TV SSCR2")
        #expect(log.events[0].detail == "2304 x 1296 HiDPI, 120 Hz → 2304 x 1296 HiDPI, 60 Hz")
        #expect(log.events[2].detail == "HDR 꺼짐")
        // 변화가 없으면 기록 없음.
        #expect(log.record(from: before, to: before, at: date) == 0)
    }

    @Test func 연결_해제와_재연결() throws {
        let normal = EventState(try SnapshotFixture.normal())
        let inventory = try RegistryFixture.inventory(RegistryFixture.noLink)
        let displays = [RegistryFixture.builtin]
        let incident = EventState(DiagnosticSnapshot(capturedAt: date, system: SnapshotFixture.system, displays: displays.map { DisplayDiagnostics(summary: $0) }, inventory: inventory, paths: ConnectionPathBuilder.build(inventory: inventory, displays: displays), attachedFramebuffers: []))

        var log = EventLog()
        log.record(from: normal, to: incident, at: date)
        #expect(log.events.map(\.kind) == [.displayDisconnected, .linkChanged])
        #expect(log.events[1].subject == "USB-C 4번")
        #expect(log.events[1].detail.hasSuffix("→ 링크 없음"))
        log.record(from: incident, to: normal, at: date)
        #expect(log.events.suffix(2).map(\.kind) == [.displayConnected, .linkChanged])
        #expect(log.events.map(\.id) == [1, 2, 3, 4])
    }

    @Test func 포트_연결과_HPD_변화() {
        let key = PortKey(type: "HDMI", number: 3)
        let empty = EventState(ports: [key: .init(connected: false, hpd: false, link: nil)])
        let plugged = EventState(ports: [key: .init(connected: true, hpd: true, link: nil)])
        var log = EventLog()
        log.record(from: empty, to: plugged, at: date)
        #expect(log.events.map(\.kind) == [.portConnected, .hpdChanged])
        log.record(from: plugged, to: empty, at: date)
        #expect(log.events.suffix(2).map(\.kind) == [.portDisconnected, .hpdChanged])
    }

    @Test func 보관_수_1000건_유지() {
        var log = EventLog()
        for i in 0..<1001 { log.append(kind: .modeChanged, subject: "D", detail: "\(i)", at: date) }
        #expect(log.events.count == 1000)
        #expect(log.events.first?.detail == "1")
        #expect(log.events.last?.id == 1001)
        var small = EventLog(capacity: 2)
        for i in 0..<5 { small.append(kind: .hpdChanged, subject: "P", detail: "\(i)", at: date) }
        #expect(small.events.map(\.detail) == ["3", "4"])
    }
}

/// TC-DGN-005: 진단 보고서.
@Suite("TC-DGN-005 진단 보고서")
struct ReportExporterTests {
    func events() -> [DisplayEvent] {
        [DisplayEvent(id: 1, date: Date(timeIntervalSince1970: 1_800_000_100), kind: .hdrChanged, subject: "LG TV SSCR2", detail: "HDR 꺼짐")]
    }

    @Test func JSON_왕복() throws {
        let report = DiagnosticReport(snapshot: try SnapshotFixture.normal(), events: events(), appVersion: "0.1.0", redact: false)
        let data = try ReportExporter.json(report)
        let decoded = try ReportExporter.decode(data)
        #expect(decoded.formatVersion == 1)
        #expect(decoded.snapshot == report.snapshot)
        #expect(decoded.result == report.result)
        #expect(decoded.events == report.events)
        #expect(!decoded.redacted)
        #expect(decoded.snapshot.displays[0].summary.identity.serialNumber == 16843009)
        // 축약: 현재 타이밍만 색 모드 목록 보유.
        let signal = try #require(decoded.snapshot.displays[0].signal)
        #expect(signal.timings.count == 58)
        #expect(signal.timings.filter { !$0.colorModes.isEmpty }.map(\.id) == [96])
    }

    @Test func 일련번호_가림() throws {
        let report = DiagnosticReport(snapshot: try SnapshotFixture.normal(), events: [], appVersion: "0.1.0", redact: true)
        let tv = report.snapshot.displays[0]
        #expect(report.redacted)
        #expect(tv.summary.identity.serialNumber == 0)
        #expect(tv.summary.identity.uuid == nil)
        #expect(tv.edid?.serialNumber == 0)
        #expect(tv.link?.state?.serialNumber == nil)
        #expect(report.snapshot.inventory.dpStates.allSatisfy { $0.serialNumber == nil })
        #expect(report.snapshot.attachedFramebuffers.allSatisfy { $0.serialNumber == nil })
        // EDID 원본의 일련번호 바이트(12-15)는 0, 나머지는 유지.
        let hex = try #require(tv.edidHex)
        #expect(hex.hasPrefix("00ffffffffffff001e6dc8c000000000011f"))
        let json = String(decoding: try ReportExporter.json(report), as: UTF8.self)
        #expect(!json.contains("16843009"))
        #expect(!json.contains("5217ECC3"))
        // 가린 뒤에도 진단 결과는 원본 기준과 동일.
        #expect(report.result == DiagnosticEngine.evaluate(try SnapshotFixture.normal()))
    }

    @Test func 텍스트_보고서_구성() throws {
        let text = ReportExporter.text(DiagnosticReport(snapshot: try SnapshotFixture.normal(), events: events(), appVersion: "0.1.0", redact: true))
        for section in ["[발견 항목", "[포트 점검]", "[연결 경로]", "[디스플레이 2대]", "[이벤트 기록 1건]"] {
            #expect(text.contains(section), "\(section)")
        }
        #expect(text.contains("USB-C 4번: 전 단계 통과"))
        #expect(text.contains("USB-C 4번 → 케이블 → Parade Technologies PS9010 → HBR3 x 4 → LG TV SSCR2"))
        #expect(text.contains("LINK.BANDWIDTH_LIMIT"))
        #expect(text.contains("일련번호 가림: 예"))
        #expect(!text.contains("16843009"))
        #expect(text.contains("HDR 꺼짐"))
    }

    @Test func EDID_16진_가림_함수() {
        #expect(DiagnosticSnapshot.redactEDIDHex("00ffffffffffff001e6dc8c001010101011f") == "00ffffffffffff001e6dc8c000000000011f")
        #expect(DiagnosticSnapshot.redactEDIDHex("00ff") == "00ff")
    }
}
