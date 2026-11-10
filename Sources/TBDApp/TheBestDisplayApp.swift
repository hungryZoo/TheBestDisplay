import AppKit
import SwiftUI
import TBDPlatform

/// 단일 창 앱 진입점. 메뉴 막대 상태 항목 없음. (PRD-APP-001, SRS-UI-002, ADR-0004)
@main
struct TheBestDisplayApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = DisplayStore()
    @State private var changes = ChangeController()
    @State private var protection = ProtectionController()

    var body: some Scene {
        Window("TheBestDisplay", id: "main") {
            ContentView()
                .environment(store)
                .environment(changes)
                .environment(protection)
                .onAppear {
                    changes.onChanged = { [store] in store.scheduleRefresh() }
                    changes.onUserChange = { [protection] in protection.userChangedConfiguration() }
                    store.onDisplaysChanged = { [changes, protection] ids in
                        changes.displaysChanged(onlineIDs: ids)
                        protection.displaysChanged(isBusy: changes.isBusy)
                    }
                }
                .frame(minWidth: 860, minHeight: 560)
        }
        .defaultSize(width: 1040, height: 680)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .toolbar) {
                Button("새로 고침") { store.refresh() }
                    .keyboardShortcut("r", modifiers: .command)
                Button("진단 보고서 내보내기") { ReportSaver.save(store: store, redact: false, asText: false) }
                    .keyboardShortcut("e", modifiers: .command)
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 번들 없이 실행 파일로 직접 실행한 경우에도 일반 앱으로 표시.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    /// 프로세스 수명에 종속된 화면 조정(전달 테이블)을 종료 시 원래대로 복원. (ADR-0004)
    func applicationWillTerminate(_ notification: Notification) {
        XDRBoostService.shared.resetAll()
        GammaService.shared.resetAll()
        // 가상 디스플레이와 HiDPI 스케일링(미러)을 정리하고 종료.
        for display in DisplayCatalog.displays() { try? VirtualDisplayService.shared.stopScaling(target: display.id) }
        VirtualDisplayService.shared.destroyAll()
    }
}
