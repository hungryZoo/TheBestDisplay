import AppKit
import SwiftUI
import TBDCore
import TBDPlatform
import UniformTypeIdentifiers

/// 개요 탭의 싱크 능력, EDID 해석, EDID 원본 영역. (PRD-INF-002, PRD-INF-003, PRD-INF-004)
struct EDIDSections: View {
    let display: DisplaySummary
    let record: EDIDRecord?
    @State private var saveError: String?

    var body: some View {
        if let record {
            let edid = record.parsed
            capabilities(edid.sinkCapabilities)
            Section("EDID") {
                LabeledContent("크기와 출처", value: "\(edid.byteCount)바이트, \(record.source)")
                LabeledContent("판", value: edid.version)
                LabeledContent("제조사", value: edid.manufacturerID.isEmpty ? "미보고" : edid.manufacturerID)
                LabeledContent("제품 코드", value: String(format: "0x%04X (%u)", edid.productCode, edid.productCode))
                LabeledContent("제조 시기", value: "\(edid.manufactureYear)년 \(edid.manufactureWeek)주")
                LabeledContent("제품명", value: edid.productName ?? "미보고")
                LabeledContent("입력", value: inputDescription(edid))
                LabeledContent("감마", value: edid.gamma.map { String(format: "%.2f", $0) } ?? "미지정")
                if let c = edid.chromaticity {
                    LabeledContent("색도", value: String(format: "R %.3f, %.3f  G %.3f, %.3f  B %.3f, %.3f  W %.3f, %.3f", c.redX, c.redY, c.greenX, c.greenY, c.blueX, c.blueY, c.whiteX, c.whiteY))
                }
                if let limits = edid.rangeLimits {
                    LabeledContent("주사율 범위", value: "수직 \(limits.minVerticalHz)-\(limits.maxVerticalHz) Hz, 수평 \(limits.minHorizontalKHz)-\(limits.maxHorizontalKHz) kHz" + (limits.maxPixelClockMHz > 0 ? ", 최대 픽셀 클록 \(limits.maxPixelClockMHz) MHz" : ""))
                }
                ForEach(edid.issues, id: \.self) { issue in
                    Label(issue, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
                DisclosureGroup("상세 타이밍 \(edid.detailedTimings.count)개") {
                    ForEach(Array(edid.detailedTimings.enumerated()), id: \.offset) { _, t in
                        LabeledContent(
                            "\(t.hActive) x \(t.vActive)\(t.interlaced ? "i" : "")  \(String(format: "%.2f", t.refreshRate)) Hz",
                            value: "픽셀 클록 \(String(format: "%.2f", t.pixelClockHz / 1e6)) MHz, 총 \(t.hTotal) x \(t.vTotal), 출처 \(t.source)"
                        )
                    }
                }
                if let cta = edid.cta {
                    DisclosureGroup("CTA-861 확장 (판 \(cta.revision))") {
                        LabeledContent("데이터 블록", value: cta.dataBlocks.joined(separator: ", "))
                        LabeledContent("오디오", value: cta.audioFormats.isEmpty ? "미보고" : cta.audioFormats.joined(separator: ", "))
                        ForEach(Array(cta.videoCodes.enumerated()), id: \.offset) { _, code in
                            LabeledContent("VIC \(code.vic)\(code.isNative ? " (네이티브)" : "")", value: code.description + (cta.ycbcr420CapableVICs.contains(code.vic) ? ", YCbCr 4:2:0 가능" : ""))
                        }
                        if let hdmi = cta.hdmi {
                            LabeledContent("HDMI VSDB", value: "물리 주소 \(hdmi.physicalAddress)" + (hdmi.maxTMDSClockMHz.map { ", 최대 TMDS \($0) MHz" } ?? ""))
                        }
                        if let hf = cta.hdmiForum {
                            LabeledContent("HDMI Forum", value: "TMDS \(hf.maxTMDSCharacterRateMHz) MHz, FRL \(hf.maxFRLGbps) Gbps, ALLM \(hf.supportsALLM ? "지원" : "미지원"), DSC 1.2a \(hf.supportsDSC12a ? "지원" : "미지원")")
                        }
                    }
                }
                if let did = edid.displayID {
                    DisclosureGroup("DisplayID 확장 (판 \(did.version))") {
                        LabeledContent("데이터 블록", value: did.dataBlocks.isEmpty ? "없음" : did.dataBlocks.joined(separator: ", "))
                        if let tiled = did.tiledTopology {
                            LabeledContent("타일 배치", value: tiled.summary)
                        }
                        ForEach(did.adaptiveSyncRanges, id: \.self) { range in
                            LabeledContent("Adaptive-Sync", value: "\(range.minHz)-\(range.maxHz) Hz")
                        }
                    }
                }
                DisclosureGroup("원본 (16진)") {
                    Text(HexDump.format(record.data))
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button("파일로 저장", systemImage: "square.and.arrow.down") { save(record) }
                    if let saveError {
                        Text(saveError).foregroundStyle(.red)
                    }
                }
            }
        } else {
            Section("EDID") {
                Text(display.identity.isBuiltin ? "내장 패널은 EDID를 제공하지 않음" : "EDID를 읽을 수 없음")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func capabilities(_ caps: SinkCapabilities) -> some View {
        Section("싱크 능력 (EDID 기준)") {
            LabeledContent("HDR", value: caps.hdrFormats.isEmpty ? "미지원" : caps.hdrFormats.joined(separator: ", "))
            LabeledContent("최대 휘도", value: caps.maxLuminance.map { String(format: "%.0f cd/m²", $0) } ?? "미보고")
            LabeledContent("색 공간", value: caps.colorimetry.isEmpty ? "미보고" : caps.colorimetry.joined(separator: ", "))
            LabeledContent("픽셀 인코딩", value: (["RGB"] + (caps.supportsYCbCr444 ? ["YCbCr 4:4:4"] : []) + (caps.supportsYCbCr422 ? ["YCbCr 4:2:2"] : []) + (caps.supportsYCbCr420 ? ["YCbCr 4:2:0"] : [])).joined(separator: ", "))
            LabeledContent("비트 심도", value: caps.deepColorBits.isEmpty ? "8 bpc" : "8 bpc, " + caps.deepColorBits.map { "\($0) bpc" }.joined(separator: ", "))
            LabeledContent("최대 주사율", value: caps.maxRefreshRate.map { "\($0) Hz" } ?? "미보고")
            LabeledContent("VRR 범위", value: caps.vrrMinHz.map { "\($0)-\(caps.vrrMaxHz ?? 0) Hz (\(caps.vrrSource ?? ""))" } ?? "미보고")
            LabeledContent("최대 TMDS", value: caps.maxTMDSMHz.map { "\($0) MHz" } ?? "미보고")
            LabeledContent("최대 FRL", value: caps.maxFRLGbps.map { "\($0) Gbps" } ?? "미보고")
            LabeledContent("DSC", value: caps.supportsDSC.map { $0 ? "지원" : "미지원" } ?? "EDID 미보고")
            if let w = caps.preferredWidth, let h = caps.preferredHeight, let hz = caps.preferredRefreshRate {
                LabeledContent("원본 해상도", value: "\(w) x \(h), \(DisplaySummary.formatHz(hz)) Hz")
            }
        }
    }

    private func inputDescription(_ edid: EDID) -> String {
        var parts = [edid.isDigital ? "디지털" : "아날로그"]
        if let interface = edid.digitalInterface { parts.append(interface) }
        if let bits = edid.bitsPerColor { parts.append("\(bits) bpc") }
        return parts.joined(separator: ", ")
    }

    private func save(_ record: EDIDRecord) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(display.identity.name).edid.bin"
        panel.allowedContentTypes = [.data]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try record.data.write(to: url)
            saveError = nil
        } catch {
            saveError = "저장 실패: \(error.localizedDescription)"
        }
    }
}
