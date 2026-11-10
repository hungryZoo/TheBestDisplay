import Foundation

/// 진단 보고서: 스냅샷, 진단 결과, 이벤트 기록. (PRD-DGN-005, SRS-DGN-003)
public struct DiagnosticReport: Codable, Sendable {
    public static let formatVersion = 1

    public var formatVersion: Int
    public var appVersion: String
    public var redacted: Bool
    public var snapshot: DiagnosticSnapshot
    public var result: DiagnosticResult
    public var events: [DisplayEvent]

    /// - Parameter redact: 참이면 일련번호와 기기 고유 식별자를 가림.
    public init(snapshot: DiagnosticSnapshot, events: [DisplayEvent], appVersion: String, redact: Bool) {
        var prepared = redact ? snapshot.redacted() : snapshot
        prepared.displays = prepared.displays.map { d in
            var d = d
            d.signal = d.signal?.slimmed()
            return d
        }
        self.formatVersion = Self.formatVersion
        self.appVersion = appVersion
        self.redacted = redact
        self.snapshot = prepared
        self.result = DiagnosticEngine.evaluate(snapshot)
        self.events = events
    }
}

public enum ReportExporter {
    public static func json(_ report: DiagnosticReport) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(report)
    }

    public static func decode(_ data: Data) throws -> DiagnosticReport {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(DiagnosticReport.self, from: data)
    }

    public static func text(_ report: DiagnosticReport) -> String {
        let formatter = ISO8601DateFormatter()
        var lines: [String] = []
        let s = report.snapshot
        lines.append("TheBestDisplay 진단 보고서")
        lines.append("생성 시각: \(formatter.string(from: s.capturedAt)), 앱 \(report.appVersion), 일련번호 가림: \(report.redacted ? "예" : "아니요")")
        lines.append("시스템: \(s.system.chipName), \(s.system.modelIdentifier), macOS \(s.system.osVersion)" + (s.system.lidClosed.map { ", 덮개 \($0 ? "닫힘" : "열림")" } ?? ""))
        lines.append("")

        lines.append("[발견 항목 \(report.result.findings.count)건]")
        if report.result.findings.isEmpty { lines.append("  없음") }
        for f in report.result.findings {
            lines.append("  [\(f.severity.label)] \(f.subject.map { "\($0): " } ?? "")\(f.title) (\(f.code))")
            lines.append("    근거: \(f.detail)")
            lines.append("    조치: \(f.remedy)")
        }
        lines.append("")

        lines.append("[포트 점검]")
        for d in report.result.portDiagnoses {
            let state = d.isIdle ? "연결 없음" : d.isFullyPassed ? "전 단계 통과" : "\(d.firstFailure?.title ?? "") 단계 미통과"
            lines.append("  \(d.port.label): \(state)")
            guard !d.isIdle else { continue }
            for c in d.checks {
                let mark = c.result == .pass ? "통과" : c.result == .fail ? "실패" : "생략"
                lines.append("    \(c.stage.title): \(mark) (\(c.detail))")
            }
        }
        lines.append("")

        lines.append("[연결 경로]")
        for path in s.paths where path.isConnected {
            lines.append("  \(path.summary)")
            for step in path.steps { lines.append("    \(step.title): \(step.detail)") }
        }
        lines.append("")

        lines.append("[디스플레이 \(s.displays.count)대]")
        for d in s.displays {
            let id = d.summary.identity
            lines.append("  \(id.name) (\(id.isBuiltin ? "내장" : "외장"), id \(id.displayID)\(d.summary.isMain ? ", 메인" : ""))")
            lines.append("    모드: \(d.currentMode?.label ?? d.summary.modeDescription), 픽셀 \(d.summary.pixelWidth) x \(d.summary.pixelHeight), 전체 모드 \(d.modeCount)개")
            lines.append(String(format: "    식별: 제조사 0x%04X, 제품 0x%04X, 일련번호 %@", id.vendorID, id.productID, report.redacted ? "가림" : String(id.serialNumber)))
            if let link = d.signal?.linkData {
                lines.append("    송출 신호: \(link.colorLabel), \(Colorimetry.name(link.colorimetry)), \(link.hActive) x \(link.vActive) \(DisplaySummary.formatHz(link.refreshRate)) Hz, 픽셀 클록 \(String(format: "%.2f", link.pixelClockHz / 1e6)) MHz")
            } else if let color = d.signal?.currentColor {
                lines.append("    색 모드: \(color.label)")
            }
            if let hdr = d.hdr { lines.append("    HDR: \(hdr.stateLabel)") }
            if let dsc = d.dsc { lines.append("    DSC: \(dsc.summary)") }
            if let link = d.link {
                var parts = [link.transportName]
                if let state = link.state, state.hasLink { parts.append("\(state.linkRateDescription), 레인 \(state.laneCount)개\(state.isTunneled ? ", 터널링" : "")") }
                if let a = link.availableGbps, let r = link.requiredGbps { parts.append(String(format: "필요 %.2f / 유효 %.2f Gbps", r, a)) }
                lines.append("    링크: \(parts.joined(separator: ", "))")
            }
            if let dpcd = d.dpcd, let revision = dpcd.revision {
                lines.append("    DPCD: 판 \(revision), 최대 \(dpcd.maxLaneRateGbps.map { DPTransportState.rateName($0) } ?? "미확인") x \(dpcd.maxLaneCount ?? 0)레인, DSC \(dpcd.supportsDSC == true ? "지원" : "미지원")")
            }
            if let edid = d.edid {
                lines.append("    EDID: \(edid.byteCount)바이트, \(edid.manufacturerID) \(edid.productName ?? ""), \(edid.manufactureYear)년" + (edid.issues.isEmpty ? "" : ", 문제 \(edid.issues.count)건"))
            }
            if let hex = d.edidHex { lines.append("    EDID 원본: \(hex)") }
        }
        lines.append("")

        lines.append("[이벤트 기록 \(report.events.count)건]")
        for e in report.events {
            lines.append("  \(formatter.string(from: e.date)) \(e.kind.title) \(e.subject): \(e.detail)")
        }
        return lines.joined(separator: "\n") + "\n"
    }
}
