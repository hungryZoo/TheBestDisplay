import AppKit
import SwiftUI
import TBDCore

/// 업데이트 창: 새 버전과 현재 버전, 패치 노트, 설치 방식별 안내, 버튼 3개. (PRD-UPD-002)
struct UpdateView: View {
    let info: UpdateInfo
    let onSkip: () -> Void
    let onLater: () -> Void
    let onInstall: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 12) {
                Text("TheBestDisplay 새 버전 사용 가능")
                    .font(.title3.bold())
                Text("새 버전 \(info.newVersion.description) (현재 \(info.currentVersion.description))")
                    .foregroundStyle(.secondary)

                Text("패치 노트")
                    .font(.headline)
                ScrollView {
                    Text(releaseNotes)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                }
                .frame(height: 220)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

                Text(installDescription)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Link("릴리스 페이지 보기", destination: info.releaseURL)
                    .font(.callout)

                HStack {
                    Button("이 버전 건너뛰기", action: onSkip)
                    Spacer()
                    Button("다음에", action: onLater)
                        .keyboardShortcut(.cancelAction)
                    Button("예", action: onInstall)
                        .keyboardShortcut(.defaultAction)
                }
                .padding(.top, 4)
            }
        }
        .padding(20)
        .frame(width: 560)
    }

    private var releaseNotes: AttributedString {
        let text = ReleaseNotesFormatter.inlineMarkdown(info.releaseNotes)
        guard !text.isEmpty else { return AttributedString("패치 노트 없음") }
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }

    private var installDescription: String {
        switch info.installMethod {
        case .homebrew:
            "예를 누르면 TheBestDisplay를 종료하고 터미널에서 brew update와 brew upgrade \(InstallMethod.caskFullName)를 실행한 뒤 새 버전을 엶"
        case .manual:
            "예를 누르면 브라우저에서 릴리스 페이지를 엶. DMG를 내려받아 응용 프로그램 폴더의 TheBestDisplay.app을 교체"
        }
    }
}

/// 설정 창: 업데이트 자동 확인 토글과 즉시 확인. (PRD-UPD-003)
struct UpdateSettingsView: View {
    @Bindable private var updates = UpdateController.shared

    var body: some View {
        Form {
            Section("업데이트") {
                LabeledContent("현재 버전", value: updates.currentVersion?.description ?? "번들 없음 (\(AppVersion.current))")
                Toggle("업데이트 자동 확인 (하루 1회)", isOn: $updates.automaticallyChecks)
                HStack {
                    Button("지금 확인") { updates.checkNow() }
                        .disabled(updates.isChecking)
                    if updates.isChecking { ProgressView().controlSize(.small) }
                }
                Text("GitHub의 최신 릴리스 정보를 조회. 새 버전이 있으면 패치 노트와 함께 업데이트 창 표시. 조회 외의 정보는 보내지 않음")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }
}
