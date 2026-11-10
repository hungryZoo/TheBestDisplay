import SwiftUI
import TBDCore

/// 디스플레이 상세 영역의 기능 탭. (PRD-APP-003)
enum DisplayTab: String, CaseIterable, Identifiable {
    case overview, resolution, colorMode, link, brightness, colorAdjust, arrangement

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: "개요"
        case .resolution: "해상도"
        case .colorMode: "색 모드"
        case .link: "링크"
        case .brightness: "밝기"
        case .colorAdjust: "색 조정"
        case .arrangement: "배치"
        }
    }

    var systemImage: String {
        switch self {
        case .overview: "info.circle"
        case .resolution: "rectangle.dashed"
        case .colorMode: "paintpalette"
        case .link: "point.3.connected.trianglepath.dotted"
        case .brightness: "sun.max"
        case .colorAdjust: "slider.horizontal.3"
        case .arrangement: "rectangle.3.group"
        }
    }

    /// 구현 예정 단계. 구현된 탭은 nil.
    var pendingStage: String? {
        switch self {
        case .overview, .resolution, .colorMode, .link: nil
        case .brightness, .colorAdjust, .arrangement: "P4"
        }
    }
}

struct DisplayDetailView: View {
    let display: DisplaySummary
    @State private var tab: DisplayTab = .overview

    var body: some View {
        TabView(selection: $tab) {
            ForEach(DisplayTab.allCases) { item in
                Tab(item.title, systemImage: item.systemImage, value: item) {
                    content(for: item)
                }
            }
        }
        .navigationTitle(display.identity.name)
        .navigationSubtitle(display.modeDescription)
    }

    @ViewBuilder
    private func content(for item: DisplayTab) -> some View {
        switch item {
        case .overview:
            OverviewTab(display: display)
        case .resolution:
            ResolutionTab(display: display)
        case .colorMode:
            ColorModeTab(display: display)
        case .link:
            LinkTab(display: display)
        default:
            PendingFeatureView(title: item.title, systemImage: item.systemImage, stage: item.pendingStage ?? "")
        }
    }
}
