import SwiftUI
import TBDCore
import TBDPlatform

/// 배치 탭: 회전, 메인 지정, 미러, 위치 편집, 연결 해제와 재연결, 언더스캔. (PRD-ARR-001-006, PRD-SAF-003)
struct ArrangementTab: View {
    @Environment(DisplayStore.self) private var store
    @Environment(ChangeController.self) private var changes
    @Environment(AutoDisconnectController.self) private var autoDisconnect
    let display: DisplaySummary

    @State private var xText = ""
    @State private var yText = ""
    @State private var message: String?
    @State private var dragOffset: CGSize = .zero
    @State private var underscan: ArrangementService.Underscan?
    @State private var canRotate = false
    @State private var alignReference: UInt32?
    @State private var alignPosition: AlignmentPosition = .rightCenter

    var body: some View {
        Form {
            layoutSection
            Section("회전") {
                Picker("회전", selection: Binding(get: { Int(display.rotationDegrees.rounded()) }, set: { degrees in
                    changes.request(DisplayChanges.rotationChange(display: display, to: degrees), targetDisplayID: display.id)
                })) {
                    ForEach(ArrangementPlanner.rotations, id: \.self) { Text("\($0)도").tag($0) }
                }
                .pickerStyle(.segmented)
                .disabled(!canRotate || changes.isBusy)
                if !canRotate {
                    Text(display.identity.isBuiltin ? "내장 디스플레이는 회전 대상에서 제외" : "이 디스플레이는 회전을 지원하지 않음").font(.caption).foregroundStyle(.secondary)
                }
            }
            if store.displays.count > 1 {
                Section("기준 디스플레이 대비 정렬") {
                    let others = store.displays.filter { $0.id != display.id && $0.mirrorsDisplayID == nil }
                    HStack {
                        Picker("기준", selection: $alignReference) {
                            Text("선택").tag(UInt32?.none)
                            ForEach(others) { Text($0.identity.name).tag(UInt32?.some($0.id)) }
                        }
                        Picker("위치", selection: $alignPosition) {
                            ForEach(AlignmentPosition.allCases, id: \.self) { Text($0.title).tag($0) }
                        }
                        Button("정렬") {
                            guard let reference = others.first(where: { $0.id == alignReference }) else { return }
                            let origin = ArrangementPlanner.alignedOrigin(target: DisplayFrame(display), reference: DisplayFrame(reference), position: alignPosition)
                            perform { try ArrangementService.move(display.id, toX: origin.x, y: origin.y, displays: store.displays) }
                        }
                        .disabled(alignReference == nil || display.mirrorsDisplayID != nil)
                    }
                }
            }
            Section("메인 디스플레이와 미러") {
                LabeledContent("메인 디스플레이") {
                    if display.isMain {
                        Text("현재 메인")
                    } else {
                        Button("메인으로 지정") { perform { try ArrangementService.setMain(display.id, displays: store.displays) } }
                            .disabled(display.mirrorsDisplayID != nil)
                    }
                }
                Picker("미러 원본", selection: Binding(get: { display.mirrorsDisplayID ?? 0 }, set: { id in
                    let master = store.displays.first { $0.id == id }
                    changes.request(DisplayChanges.mirrorChange(display: display, master: master, displays: store.displays), targetDisplayID: display.id)
                })) {
                    Text("없음 (확장)").tag(UInt32(0))
                    ForEach(store.displays.filter { $0.id != display.id }) { other in
                        Text(other.identity.name).tag(other.id)
                    }
                }
                .disabled(store.displays.count < 2 || changes.isBusy)
                if store.displays.count < 2 {
                    Text("미러는 온라인 디스플레이가 2대 이상일 때 사용").font(.caption).foregroundStyle(.secondary)
                }
            }
            if let underscan {
                Section("언더스캔") {
                    HStack(spacing: 10) {
                        Slider(value: Binding(get: { Double(underscan.value) }, set: { value in
                            perform { try ArrangementService.setUnderscan(Int(value.rounded()), on: display.id) }
                            self.underscan = ArrangementService.underscan(of: display.id)
                        }), in: Double(underscan.minimum)...Double(underscan.maximum), step: 1)
                        Text("\(underscan.value)").monospacedDigit().frame(width: 44, alignment: .trailing)
                    }
                    Text("TV에서 화면 가장자리가 잘릴 때 화면을 줄여 맞춤").font(.caption).foregroundStyle(.secondary)
                }
            }
            Section("연결") {
                Toggle("외장 디스플레이 연결 시 내장 디스플레이 자동 연결 해제", isOn: Binding(get: { autoDisconnect.isEnabled }, set: { autoDisconnect.setEnabled($0) }))
                Text("실제 외장 디스플레이가 온라인일 때 내장 디스플레이를 연결 해제하고, 외장이 모두 사라지거나 앱을 종료하면 다시 연결. 앱 실행 중에만 동작. 재연결이 되지 않으면 `tbdctl reconnect` 또는 재시동으로 복구")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let message = autoDisconnect.message {
                    Text(message).font(.caption).foregroundStyle(.secondary)
                }
                let refusal = ArrangementPlanner.disconnectRefusal(display.id, online: store.displays.map(\.id))
                LabeledContent("논리적 연결 해제") {
                    Button("연결 해제") {
                        // 해제된 디스플레이는 온라인 목록에서 사라지므로 대상 사라짐 감시는 사용하지 않음.
                        store.rememberDisconnected(display)
                        changes.request(DisplayChanges.disconnectChange(display: display), targetDisplayID: nil)
                    }
                    .disabled(refusal != nil || changes.isBusy)
                }
                Text(refusal ?? "케이블을 뽑지 않고 디스플레이를 시스템에서 분리. 창은 남은 디스플레이로 이동. 재연결은 사이드바의 연결 해제됨 항목 또는 케이블 재연결")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let message {
                Section { Label(message, systemImage: "exclamationmark.triangle").foregroundStyle(.red) }
            }
        }
        .formStyle(.grouped)
        .task(id: "\(display.id)-\(display.originX)-\(display.originY)") {
            xText = String(display.originX)
            yText = String(display.originY)
            underscan = ArrangementService.underscan(of: display.id)
            canRotate = ArrangementService.canRotate(display.id)
        }
    }

    private var layoutSection: some View {
        Section {
            ArrangementCanvas(frames: store.displays.filter { $0.mirrorsDisplayID == nil }.map(DisplayFrame.init), names: Dictionary(uniqueKeysWithValues: store.displays.map { ($0.id, $0.identity.name) }), selected: display.id, mainID: store.displays.first(where: \.isMain)?.id) { x, y in
                perform { try ArrangementService.move(display.id, toX: x, y: y, displays: store.displays) }
            }
            .frame(height: 220)
            HStack(spacing: 8) {
                Text("위치")
                TextField("x", text: $xText).frame(width: 80)
                TextField("y", text: $yText).frame(width: 80)
                Button("적용") {
                    guard let x = Int(xText), let y = Int(yText) else {
                        message = "좌표는 정수"
                        return
                    }
                    perform { try ArrangementService.move(display.id, toX: x, y: y, displays: store.displays) }
                }
                .disabled(store.displays.count < 2 || display.mirrorsDisplayID != nil)
                Spacer()
                Text("크기 \(display.pointWidth) x \(display.pointHeight)").foregroundStyle(.secondary)
            }
        } header: {
            Text("위치")
        } footer: {
            Text("선택한 디스플레이를 끌어서 이동. 다른 디스플레이와 맞닿는 가장 가까운 위치로 보정. 메인 디스플레이의 원점이 (0, 0)")
                .font(.caption)
        }
    }

    private func perform(_ action: () throws -> Void) {
        do {
            try action()
            message = nil
        } catch {
            message = RevertCoordinator.describe(error)
        }
        store.scheduleRefresh()
    }
}

/// 배치 미리 보기와 끌어서 이동.
private struct ArrangementCanvas: View {
    let frames: [DisplayFrame]
    let names: [UInt32: String]
    let selected: UInt32
    let mainID: UInt32?
    let onMove: (Int, Int) -> Void

    @State private var drag: CGSize = .zero

    var body: some View {
        GeometryReader { proxy in
            let layout = ArrangementPlanner.previewLayout(frames, width: proxy.size.width, height: proxy.size.height)
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 10).fill(.quaternary.opacity(0.35))
                ForEach(frames) { frame in
                    tile(frame, layout: layout)
                }
            }
        }
    }

    private func tile(_ frame: DisplayFrame, layout: (scale: Double, offsetX: Double, offsetY: Double)) -> some View {
        let isSelected = frame.id == selected
        let offset: CGSize = isSelected ? drag : .zero
        let width = Double(frame.width) * layout.scale
        let height = Double(frame.height) * layout.scale
        let x = Double(frame.x) * layout.scale + layout.offsetX + offset.width
        let y = Double(frame.y) * layout.scale + layout.offsetY + offset.height
        let fill: Color = isSelected ? Color.accentColor.opacity(0.35) : Color.gray.opacity(0.25)
        let stroke: Color = isSelected ? Color.accentColor : Color.gray.opacity(0.6)
        let gesture = DragGesture()
            .onChanged { drag = $0.translation }
            .onEnded { value in
                drag = .zero
                guard layout.scale > 0 else { return }
                let dx = Int((value.translation.width / layout.scale).rounded())
                let dy = Int((value.translation.height / layout.scale).rounded())
                onMove(frame.x + dx, frame.y + dy)
            }
        return RoundedRectangle(cornerRadius: 6)
            .fill(fill)
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(stroke, lineWidth: isSelected ? 2 : 1))
            .overlay {
                VStack(spacing: 2) {
                    Text(names[frame.id] ?? "id:\(frame.id)").font(.caption).lineLimit(1)
                    if frame.id == mainID { Text("메인").font(.caption2).foregroundStyle(.secondary) }
                }
                .padding(4)
            }
            .frame(width: width, height: height)
            .offset(x: x, y: y)
            .gesture(gesture, isEnabled: isSelected && frames.count > 1)
    }
}
