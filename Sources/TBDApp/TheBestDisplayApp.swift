import AppKit
import SwiftUI

/// 단일 창 앱 진입점. 메뉴 막대 상태 항목 없음. (PRD-APP-001, SRS-UI-002, ADR-0004)
@main
struct TheBestDisplayApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = DisplayStore()

    var body: some Scene {
        Window("TheBestDisplay", id: "main") {
            ContentView()
                .environment(store)
                .frame(minWidth: 860, minHeight: 560)
        }
        .defaultSize(width: 1040, height: 680)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .toolbar) {
                Button("새로 고침") { store.refresh() }
                    .keyboardShortcut("r", modifiers: .command)
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
}
