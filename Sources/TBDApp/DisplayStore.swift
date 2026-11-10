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
        refreshCount += 1
        onDisplaysChanged(Set(snapshot.displays.map(\.id)))
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
