import SwiftUI
import TBDCore
import TBDPlatform

/// 해상도 탭의 디스플레이 오버라이드 구역: 이름, 기본 해상도, TV 역할 표시. (PRD-MOD-016)
/// 한 번의 관리자 인증으로 세 값을 함께 저장하고, 재초기화로 반영.
struct DisplayOverrideKeysSection: View {
    @Environment(DisplayStore.self) private var store
    let display: DisplaySummary

    @State private var file: DisplayOverrideFile?
    @State private var name = ""
    /// 기본 해상도 선택값: "" 지정 없음, "<폭>x<높이>".
    @State private var defaultSize = ""
    /// TV 역할 선택값: 0 지정 없음, 1 켬, 2 끔.
    @State private var tvChoice = 0
    @State private var message: String?
    @State private var expanded = false
    @State private var loadedID: UInt32?

    private let service = DisplayOverrideService()

    /// 기본 해상도 후보: 모드 목록의 HiDPI 논리 해상도 (큰 순서).
    private var sizeOptions: [(width: Int, height: Int)] {
        let modes = store.modes[display.id] ?? []
        var seen = Set<String>()
        return modes.filter(\.isHiDPI)
            .sorted { ($0.width, $0.height) > ($1.width, $1.height) }
            .compactMap { seen.insert("\($0.width)x\($0.height)").inserted ? (width: $0.width, height: $0.height) : nil }
    }

    private var isDirty: Bool {
        guard let file else { return false }
        return name.trimmingCharacters(in: .whitespaces) != (file.productName ?? "")
            || defaultSize != (file.defaultResolution.map { "\($0.width)x\($0.height)" } ?? "")
            || tvChoice != (file.isTV.map { $0 ? 1 : 2 } ?? 0)
    }

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("이름").frame(width: 90, alignment: .leading)
                    TextField("이름", text: $name, prompt: Text(display.identity.name))
                        .labelsHidden()
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 240)
                    Text("비우면 원래 이름").font(.caption).foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    Text("기본 해상도").frame(width: 90, alignment: .leading)
                    Picker("기본 해상도", selection: $defaultSize) {
                        Text("지정 없음 (시스템 기본)").tag("")
                        ForEach(sizeOptions, id: \.width) { size in
                            Text("\(size.width) x \(size.height) HiDPI").tag("\(size.width)x\(size.height)")
                        }
                        // 목록에 없는 값이 파일에 있으면 그대로 표시.
                        if !defaultSize.isEmpty, !sizeOptions.contains(where: { "\($0.width)x\($0.height)" == defaultSize }) {
                            Text(defaultSize.replacingOccurrences(of: "x", with: " x ") + " (모드 목록에 없음)").tag(defaultSize)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                    Text("시스템 설정의 기본값으로 표시되는 해상도").font(.caption).foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    Text("TV 역할 표시").frame(width: 90, alignment: .leading)
                    Picker("TV 역할 표시", selection: $tvChoice) {
                        Text("지정 없음").tag(0)
                        Text("켬").tag(1)
                        Text("끔").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                    Text("시스템 정보에 TV로 표시. 바뀌는 동작은 구성에 따라 다름").font(.caption).foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    Button("저장 (관리자 인증)") { save() }
                        .disabled(!isDirty)
                    Button("모두 해제") { clear() }
                        .disabled(file?.productName == nil && file?.defaultResolution == nil && file?.isTV == nil)
                    Button("디스플레이 재초기화") { reinitialize() }
                        .help("연결을 끊었다 다시 연결해 저장한 값을 반영. 화면이 잠깐 꺼짐")
                }
                .controlSize(.small)
                if let message {
                    Text(message).font(.caption).foregroundStyle(.secondary)
                }
                Text("시스템의 디스플레이 오버라이드 파일에 기록. 저장에 관리자 인증 필요, 같은 제조사와 제품 ID의 디스플레이 전체에 적용, 재초기화 또는 재연결 뒤 반영. 현재 쓰는 모드는 바뀌지 않음")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .font(.callout)
            .padding(.top, 4)
        } label: {
            Text("디스플레이 오버라이드 (이름, 기본 해상도, 역할)").font(.callout.weight(.medium))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .task(id: display.id) {
            if loadedID != display.id {
                if loadedID != nil { message = nil }
                loadedID = display.id
            }
            reload()
        }
    }

    private func reload() {
        let id = display.identity
        do {
            let loaded = try service.read(vendorID: id.vendorID, productID: id.productID)
            file = loaded
            name = loaded.productName ?? ""
            defaultSize = loaded.defaultResolution.map { "\($0.width)x\($0.height)" } ?? ""
            tvChoice = loaded.isTV.map { $0 ? 1 : 2 } ?? 0
        } catch {
            file = nil
            message = RevertCoordinator.describe(error)
        }
    }

    private func save() {
        guard var edited = file else { return }
        do {
            let trimmed = name.trimmingCharacters(in: .whitespaces)
            try edited.setProductName(trimmed.isEmpty ? nil : trimmed)
            if let size = DisplayOverrideFile.parseSize(defaultSize) {
                try edited.setDefaultResolution(width: size.width, height: size.height)
            } else {
                edited.defaultResolution = nil
            }
            edited.isTV = tvChoice == 0 ? nil : tvChoice == 1
        } catch {
            message = RevertCoordinator.describe(error)
            return
        }
        write(edited, done: "저장 완료. 재초기화 또는 재연결 뒤 반영")
    }

    private func clear() {
        guard var edited = file else { return }
        edited.productName = nil
        edited.defaultResolution = nil
        edited.isTV = nil
        write(edited, done: "해제 완료. 재초기화 또는 재연결 뒤 반영")
    }

    private func write(_ edited: DisplayOverrideFile, done: String) {
        do {
            try service.write(edited)
            message = done
        } catch DisplayOverrideService.ServiceError.needsPrivilege(_, let commands) {
            message = ScaledResolutionSection.runPrivileged(commands).map { "저장 실패: \($0)" } ?? done
        } catch {
            message = "저장 실패: \(RevertCoordinator.describe(error))"
        }
        reload()
    }

    private func reinitialize() {
        do {
            try ArrangementService.reinitialize(display.id)
            message = "재초기화 완료"
            store.scheduleRefresh()
        } catch {
            message = "재초기화 실패: \(RevertCoordinator.describe(error))"
        }
    }
}
