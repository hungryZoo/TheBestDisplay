import AppKit
import SwiftUI
import TBDCore
import TBDPlatform

/// 해상도 탭의 사용자 정의 스케일 해상도 영역: 디스플레이 오버라이드 파일의 항목 조회, 추가, 삭제. (PRD-MOD-007)
struct ScaledResolutionSection: View {
    @Environment(DisplayStore.self) private var store
    let display: DisplaySummary

    @State private var file: DisplayOverrideFile?
    @State private var width = ""
    @State private var height = ""
    @State private var message: String?
    @State private var expanded = false
    @State private var loadedID: UInt32?

    private let service = DisplayOverrideService()

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 8) {
                if let file, !file.entries.isEmpty {
                    ForEach(file.entries, id: \.self) { entry in
                        HStack {
                            Text(entry.label).font(.callout.monospacedDigit())
                            Spacer()
                            Button("삭제") { remove(entry) }.controlSize(.small)
                        }
                    }
                } else {
                    Text("등록된 스케일 해상도 없음").font(.callout).foregroundStyle(.secondary)
                }
                HStack(spacing: 6) {
                    TextField("폭", text: $width).frame(width: 70)
                    Text("x")
                    TextField("높이", text: $height).frame(width: 70)
                    Text("HiDPI")
                    Button("추가") { add() }
                        .disabled(Int(width) == nil || Int(height) == nil)
                    Button("다단계 5개 일괄 추가") { addLadder() }
                        .help("패널 해상도의 절반부터 패널 해상도까지 같은 종횡비로 5단계 등록")
                }
                .textFieldStyle(.roundedBorder)
                .controlSize(.small)
                if let message {
                    Text(message).font(.caption).foregroundStyle(.secondary)
                }
                Text("시스템의 디스플레이 오버라이드 파일에 HiDPI 해상도를 등록. 저장에 관리자 인증 필요, 같은 제조사와 제품 ID의 디스플레이 전체에 적용, 디스플레이 재연결 또는 재시동 후 모드 목록에 반영. 기기의 백킹 크기 한도를 넘는 해상도는 시스템이 무시")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        } label: {
            Text("사용자 정의 스케일 해상도").font(.callout.weight(.medium))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .task(id: display.id) {
            // 입력값과 안내문은 디스플레이별 상태: 다른 디스플레이로 넘어가면 비움. (T51 실측)
            // 목록 행이 화면 밖으로 나갔다 돌아올 때도 이 블록이 다시 실행되므로 디스플레이가 바뀐 경우만 비움.
            if loadedID != display.id {
                if loadedID != nil {
                    width = ""
                    height = ""
                    message = nil
                }
                loadedID = display.id
            }
            reload()
        }
    }

    private func reload() {
        let id = display.identity
        do {
            file = try service.read(vendorID: id.vendorID, productID: id.productID)
        } catch {
            file = nil
            message = RevertCoordinator.describe(error)
        }
    }

    private func add() {
        guard var edited = file, let w = Int(width), let h = Int(height) else { return }
        do {
            try edited.add(logicalWidth: w, logicalHeight: h)
        } catch {
            message = RevertCoordinator.describe(error)
            return
        }
        // 백킹 크기(논리 해상도의 2배)가 프레임버퍼 소스 한도를 넘으면 안내를 덧붙임. (PRD-MOD-014)
        let notice = ModeService.framebufferLimits(for: display)?.excessNotice(pixelWidth: w * 2, pixelHeight: h * 2)
        save(edited, done: "\(w) x \(h) HiDPI 등록 완료. 디스플레이 재연결 또는 재시동 후 반영" + (notice.map { ". 주의: \($0)" } ?? ""))
    }

    /// 다단계 스케일 해상도 일괄 등록. (PRD-MOD-013)
    private func addLadder() {
        guard var edited = file else { return }
        let modes = store.modes[display.id] ?? []
        guard let native = ModeCatalog.nativeModes(modes, nativeWidth: display.pixelWidth, nativeHeight: display.pixelHeight).first else {
            message = "패널 원본 해상도를 확인할 수 없음"
            return
        }
        let added = edited.addLadder(nativeWidth: native.pixelWidth, nativeHeight: native.pixelHeight, steps: 5)
        guard added > 0 else {
            message = "추가할 항목 없음 (이미 등록됨)"
            return
        }
        save(edited, done: "\(added)개 등록 완료. 디스플레이 재연결 또는 재시동 후 반영")
    }

    private func remove(_ entry: ScaleResolutionEntry) {
        guard var edited = file else { return }
        edited.entries.removeAll { $0 == entry }
        save(edited, done: "삭제 완료. 디스플레이 재연결 또는 재시동 후 반영")
    }

    /// 쓰기. 권한이 없으면 시스템의 관리자 인증 창을 거쳐 설치 명령 실행.
    private func save(_ edited: DisplayOverrideFile, done: String) {
        do {
            try service.write(edited)
            message = done
        } catch DisplayOverrideService.ServiceError.needsPrivilege(_, let commands) {
            if let failure = Self.runPrivileged(commands) {
                message = "저장 실패: \(failure)"
            } else {
                message = done
            }
        } catch {
            message = "저장 실패: \(RevertCoordinator.describe(error))"
        }
        reload()
    }

    /// 관리자 권한으로 셸 명령 실행. 인증은 시스템 창에서 사용자가 직접 수행. 실패 시 사유 반환.
    static func runPrivileged(_ commands: [String]) -> String? {
        let joined = commands.joined(separator: " && ")
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        var error: NSDictionary?
        NSAppleScript(source: "do shell script \"\(joined)\" with administrator privileges")?.executeAndReturnError(&error)
        guard let error else { return nil }
        return error[NSAppleScript.errorMessage] as? String ?? "관리자 권한 실행 실패"
    }
}
