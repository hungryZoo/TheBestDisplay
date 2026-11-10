import SwiftUI
import TBDCore
import TBDPlatform

/// 개요 탭: 제품 정보와 현재 상태. (PRD-INF-001)
struct OverviewTab: View {
    @Environment(DisplayStore.self) private var store
    let display: DisplaySummary
    @State private var measurement: RefreshMeasurement?
    @State private var isMeasuring = false

    var body: some View {
        Form {
            Section("제품") {
                LabeledContent("이름", value: display.identity.name)
                LabeledContent("종류", value: display.identity.isBuiltin ? "내장" : "외장")
                LabeledContent("제조사 ID", value: Self.hex(display.identity.vendorID))
                LabeledContent("제품 ID", value: Self.hex(display.identity.productID))
                LabeledContent("일련번호", value: display.identity.serialNumber == 0 ? "미보고" : String(display.identity.serialNumber))
                LabeledContent("디스플레이 ID", value: String(display.identity.displayID))
                LabeledContent("UUID", value: display.identity.uuid ?? "없음")
            }
            Section("현재 상태") {
                LabeledContent("논리 해상도", value: "\(display.pointWidth) x \(display.pointHeight)\(display.isHiDPI ? " (HiDPI)" : "")")
                LabeledContent("픽셀 해상도", value: "\(display.pixelWidth) x \(display.pixelHeight)")
                LabeledContent("주사율", value: display.refreshRate > 0 ? "\(DisplaySummary.formatHz(display.refreshRate)) Hz" : "미보고")
                LabeledContent("측정 주사율") {
                    HStack(spacing: 10) {
                        Text(isMeasuring ? "측정 중" : measurement?.summary ?? "미측정")
                        Button("측정") { measure() }
                            .controlSize(.small)
                            .disabled(isMeasuring)
                    }
                }
                LabeledContent("회전", value: "\(Int(display.rotationDegrees))도")
                LabeledContent("위치", value: "(\(display.originX), \(display.originY))")
                LabeledContent("메인 디스플레이", value: display.isMain ? "예" : "아니요")
                if let mirror = display.mirrorsDisplayID {
                    LabeledContent("미러 대상", value: store.display(id: mirror)?.identity.name ?? "id:\(mirror)")
                }
            }
            Section("물리 크기") {
                if let inches = display.diagonalInches, let ppi = display.pixelsPerInch {
                    LabeledContent("크기", value: "\(Int(display.physicalWidthMM.rounded())) x \(Int(display.physicalHeightMM.rounded())) mm")
                    LabeledContent("대각", value: String(format: "%.1f 인치", inches))
                    LabeledContent("픽셀 밀도", value: String(format: "%.0f PPI", ppi))
                } else {
                    Text("디스플레이가 물리 크기를 보고하지 않음")
                        .foregroundStyle(.secondary)
                }
            }
            EDIDSections(display: display, record: store.edidRecords[display.id])
            if !display.identity.isBuiltin, let record = store.edidRecords[display.id] {
                EDIDOverrideSection(display: display, record: record)
            }
            let unavailable = Capability.allCases.map(store.status).filter { !$0.isAvailable }
            if !unavailable.isEmpty {
                Section("사용할 수 없는 기능") {
                    ForEach(unavailable, id: \.capability) { status in
                        LabeledContent(status.capability.title, value: status.unavailableReason ?? "")
                    }
                }
            }
        }
        .formStyle(.grouped)
        .textSelection(.enabled)
    }

    /// 2초 동안 화면 갱신 콜백을 모아 주사율 계산. (PRD-MOD-008)
    private func measure() {
        guard let meter = RefreshRateMeter(display: display) else {
            measurement = RefreshMeasurement.compute(nominalHz: display.refreshRate, timestamps: [], reportedDurations: [])
            return
        }
        isMeasuring = true
        meter.start()
        Task {
            try? await Task.sleep(for: .seconds(2))
            measurement = meter.stop()
            isMeasuring = false
        }
    }

    private static func hex(_ value: UInt32) -> String {
        String(format: "0x%04X (%u)", value, value)
    }
}
