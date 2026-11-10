import SwiftUI
import TBDCore

/// 화면 변경 후 확인 대화상자. 제한 시간 내 유지를 누르지 않으면 이전 설정 복귀. (PRD-SAF-001)
struct ChangeConfirmationSheet: View {
    @Environment(ChangeController.self) private var changes
    let confirmation: ChangeController.Confirmation

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "display.trianglebadge.exclamationmark")
                .font(.system(size: 36))
                .foregroundStyle(.orange)
            Text("이 설정을 유지할까요?")
                .font(.title3.bold())
            Text(confirmation.summary)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            TimelineView(.periodic(from: .now, by: 0.5)) { context in
                let remaining = max(0, Int(confirmation.deadline.timeIntervalSince(context.date).rounded(.up)))
                Text("\(remaining)초 뒤 이전 설정으로 복귀")
                    .monospacedDigit()
            }
            HStack {
                Button("복귀") { changes.cancel() }
                    .keyboardShortcut(.cancelAction)
                Button("유지") { changes.confirm() }
                    .keyboardShortcut(.defaultAction)
            }
            .controlSize(.large)
        }
        .padding(24)
        .frame(minWidth: 380)
        .interactiveDismissDisabled()
    }
}

/// 창 위쪽의 결과 알림 줄.
struct BannerView: View {
    let banner: ChangeController.Banner
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: banner.kind == .error ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundStyle(banner.kind == .error ? .red : .green)
            Text(banner.text)
                .textSelection(.enabled)
            Spacer()
            Button("닫기", systemImage: "xmark", action: dismiss)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 12)
        .padding(.top, 6)
    }
}
