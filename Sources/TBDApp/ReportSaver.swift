import AppKit
import TBDCore
import UniformTypeIdentifiers

/// 진단 보고서 저장 대화상자. (PRD-DGN-005)
@MainActor
enum ReportSaver {
    static let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"

    static func save(store: DisplayStore, redact: Bool, asText: Bool) {
        guard let snapshot = store.diagnosticSnapshot else { return }
        let report = DiagnosticReport(snapshot: snapshot, events: store.eventLog.events, appVersion: appVersion, redact: redact)
        let panel = NSSavePanel()
        let stamp = ISO8601DateFormatter().string(from: snapshot.capturedAt).replacingOccurrences(of: ":", with: "")
        panel.nameFieldStringValue = "TheBestDisplay-진단-\(stamp).\(asText ? "txt" : "json")"
        panel.allowedContentTypes = [asText ? .plainText : .json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = asText ? Data(ReportExporter.text(report).utf8) : try ReportExporter.json(report)
            try data.write(to: url)
        } catch {
            NSAlert(error: error).runModal()
        }
    }
}
