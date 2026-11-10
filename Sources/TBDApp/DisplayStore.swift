import AppKit
import CoreGraphics
import Observation
import TBDCore
import TBDPlatform

/// 화면에 표시할 시스템 상태 보관과 자동 갱신. (SRS-ARC-004)
@MainActor
@Observable
final class DisplayStore {
    private(set) var snapshot = SystemSnapshot(capturedAt: .now, displays: [])
    private(set) var capabilities: [Capability: CapabilityStatus] = [:]
    private(set) var refreshCount = 0
    /// 디스플레이 ID별 EDID 원본과 해석 결과. 내장 패널은 없음.
    private(set) var edidRecords: [UInt32: EDIDRecord] = [:]
    /// 디스플레이 ID별 전체 모드와 현재 모드.
    private(set) var modes: [UInt32: [DisplayMode]] = [:]
    private(set) var currentModes: [UInt32: DisplayMode] = [:]
    /// 디스플레이 ID별 신호 상태와 DSC 판정.
    private(set) var signals: [UInt32: SignalInfo] = [:]
    private(set) var dscAssessments: [UInt32: DSCAssessment] = [:]
    private(set) var hdrStatuses: [UInt32: HDRStatus] = [:]
    /// 디스플레이 ID별 링크 보고와 DPCD, 링크 훈련 결과.
    private(set) var linkReports: [UInt32: LinkReport] = [:]
    private(set) var linkDetails: [UInt32: LinkDetails] = [:]
    /// 전 포트의 DisplayPort 전송 상태.
    private(set) var transportStates: [DPTransportState] = []
    /// 포트별 연결 경로.
    private(set) var connectionPaths: [ConnectionPath] = []
    /// 진단 입력과 결과, 이벤트 기록.
    private(set) var diagnosticSnapshot: DiagnosticSnapshot?
    private(set) var diagnosis = DiagnosticResult(findings: [], portDiagnoses: [])
    private(set) var eventLog = EventLog()
    /// 이 앱에서 연결 해제한 디스플레이 (ID와 이름). 재연결 항목 표시에 사용.
    private(set) var disconnected: [UInt32: String] = [:]
    @ObservationIgnored private var lastEventState: EventState?
    @ObservationIgnored private var lastInventory: PortInventory?
    @ObservationIgnored private var portPollTimer: Timer?

    struct LinkDetails {
        var dpcd: DPCDInfo?
        var training: LinkTrainingData?
    }
    /// 온라인 목록이 바뀔 때 호출.
    @ObservationIgnored var onDisplaysChanged: (Set<UInt32>) -> Void = { _ in }

    @ObservationIgnored private var pendingRefresh: Task<Void, Never>?
    @ObservationIgnored private var observer: NSObjectProtocol?

    /// 재구성 알림 후 재조회까지의 지연. 연속 알림을 1회 조회로 묶음.
    static let debounce: Duration = .milliseconds(300)

    init() {
        for status in PrivateSymbols.shared.allStatuses() {
            capabilities[status.capability] = status
        }
        refresh()
        startMonitoring()
    }

    var displays: [DisplaySummary] { snapshot.displays }

    func display(id: UInt32) -> DisplaySummary? {
        snapshot.displays.first { $0.id == id }
    }

    func status(_ capability: Capability) -> CapabilityStatus {
        capabilities[capability] ?? CapabilityStatus(capability: capability, isAvailable: false, missingSymbols: [])
    }

    func refresh() {
        snapshot = DisplayCatalog.snapshot()
        // 다시 온라인이 된 디스플레이는 연결 해제 목록에서 제거.
        for display in snapshot.displays { disconnected[display.id] = nil }
        edidRecords = Dictionary(EDIDSource.records(for: snapshot.displays).map { ($0.displayID, $0) }, uniquingKeysWith: { first, _ in first })
        var allModes: [UInt32: [DisplayMode]] = [:]
        var current: [UInt32: DisplayMode] = [:]
        for display in snapshot.displays {
            let list = ModeService.modes(for: display.id)
            allModes[display.id] = list
            current[display.id] = ModeService.currentMode(for: display.id, in: list)
        }
        modes = allModes
        currentModes = current
        var signalMap: [UInt32: SignalInfo] = [:]
        var dscMap: [UInt32: DSCAssessment] = [:]
        let sourceDSC = SignalService.sourceSupportsDSC()
        for display in snapshot.displays {
            guard let info = SignalService.signalInfo(for: display) else { continue }
            signalMap[display.id] = info
            dscMap[display.id] = DSCAssessment.assess(signal: info, edidSupportsDSC: edidRecords[display.id]?.parsed.sinkCapabilities.supportsDSC, sourceSupportsDSC: sourceDSC)
        }
        signals = signalMap
        dscAssessments = dscMap
        let inventory = PortService.inventory()
        transportStates = inventory.dpStates
        lastInventory = inventory
        connectionPaths = ConnectionPathBuilder.build(inventory: inventory, displays: snapshot.displays)
        var reports: [UInt32: LinkReport] = [:]
        var details: [UInt32: LinkDetails] = [:]
        for display in snapshot.displays {
            reports[display.id] = LinkService.report(for: display, signal: signalMap[display.id], dsc: dscMap[display.id], states: transportStates)
            details[display.id] = LinkDetails(dpcd: LinkService.dpcd(for: display), training: LinkService.linkTraining(for: display))
        }
        linkReports = reports
        linkDetails = details
        hdrStatuses = Dictionary(uniqueKeysWithValues: snapshot.displays.map { ($0.id, HDRService.status(for: $0, edid: edidRecords[$0.id]?.parsed)) })
        let diagnostic = DiagnosticSnapshot(
            capturedAt: snapshot.capturedAt,
            system: SnapshotBuilder.systemInfo(displays: snapshot.displays),
            displays: snapshot.displays.map { display in
                DisplayDiagnostics(
                    summary: display,
                    edid: edidRecords[display.id]?.parsed,
                    edidHex: edidRecords[display.id].map { $0.data.map { String(format: "%02x", $0) }.joined() },
                    currentMode: current[display.id],
                    modeCount: allModes[display.id]?.count ?? 0,
                    signal: signalMap[display.id],
                    dsc: dscMap[display.id],
                    hdr: hdrStatuses[display.id],
                    link: reports[display.id],
                    dpcd: details[display.id]?.dpcd,
                    linkTraining: details[display.id]?.training
                )
            },
            inventory: inventory,
            paths: connectionPaths,
            attachedFramebuffers: SnapshotBuilder.attachedFramebuffers()
        )
        diagnosticSnapshot = diagnostic
        diagnosis = DiagnosticEngine.evaluate(diagnostic)
        // 이벤트 기록: 직전 상태와의 차이. 첫 조회는 기준 상태만 저장.
        let state = EventState(diagnostic)
        if let previous = lastEventState { eventLog.record(from: previous, to: state, at: diagnostic.capturedAt) }
        lastEventState = state
        refreshCount += 1
        // 재구성 뒤 시스템이 전달 테이블을 초기화하므로 소프트웨어 조정 값 재적용.
        GammaService.shared.reapply(onlineDisplays: snapshot.displays.map(\.id))
        onDisplaysChanged(Set(snapshot.displays.map(\.id)))
    }

    func rememberDisconnected(_ display: DisplaySummary) {
        disconnected[display.id] = display.identity.name
    }

    /// 연결 해제한 디스플레이 재연결. 실패 사유 반환.
    func reconnect(_ id: UInt32) -> String? {
        do {
            try ArrangementService.reconnect(id, timeout: 8)
            disconnected[id] = nil
            scheduleRefresh()
            return nil
        } catch {
            scheduleRefresh()
            return RevertCoordinator.describe(error)
        }
    }

    func scheduleRefresh() {
        pendingRefresh?.cancel()
        pendingRefresh = Task { [weak self] in
            try? await Task.sleep(for: Self.debounce)
            guard !Task.isCancelled else { return }
            self?.refresh()
        }
    }

    private func startMonitoring() {
        // 디스플레이 연결, 해제, 모드, 배치 변경 알림.
        CGDisplayRegisterReconfigurationCallback(displayReconfigured, Unmanaged.passUnretained(self).toOpaque())
        // 온라인 목록에 들지 못한 연결(HPD만 감지 등)은 CoreGraphics 알림이 없으므로 포트 상태를 2초 주기로 대조.
        portPollTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, PortService.inventory() != self.lastInventory else { return }
                self.scheduleRefresh()
            }
        }
        observer = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.scheduleRefresh() }
        }
    }
}

/// CoreGraphics 재구성 콜백. 메인 런 루프에서 호출됨.
private func displayReconfigured(_ display: CGDirectDisplayID, _ flags: CGDisplayChangeSummaryFlags, _ userInfo: UnsafeMutableRawPointer?) {
    guard let userInfo, !flags.contains(.beginConfigurationFlag) else { return }
    let store = Unmanaged<DisplayStore>.fromOpaque(userInfo).takeUnretainedValue()
    DispatchQueue.main.async {
        MainActor.assumeIsolated { store.scheduleRefresh() }
    }
}
