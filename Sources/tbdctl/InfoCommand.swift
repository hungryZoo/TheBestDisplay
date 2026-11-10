import Foundation
import TBDCore
import TBDPlatform

struct InfoOutput: Encodable {
    var display: DisplaySummary
    var edidSource: String?
    var edid: EDID?
    var sinkCapabilities: SinkCapabilities?
}

/// `tbdctl info <디스플레이> [--edid-out <경로>] [--hex] [--json]` (PRD-INF-001-004)
func runInfo(_ command: ParsedCommand, json: Bool) {
    let (display, displays) = resolveDisplay(command.positionals[0])
    let record = EDIDSource.record(for: display, among: displays)

    if let path = command.options["--edid-out"] {
        guard let record else {
            writeError("오류: EDID 없음 (\(display.identity.isBuiltin ? "내장 패널은 EDID 미제공" : "획득 실패"))")
            exit(.unsupported)
        }
        do {
            try record.data.write(to: URL(fileURLWithPath: path))
        } catch {
            writeError("오류: 파일 저장 실패: \(error.localizedDescription)")
            exit(.failure)
        }
    }

    if json {
        printJSON(InfoOutput(display: display, edidSource: record?.source, edid: record?.parsed, sinkCapabilities: record?.parsed.sinkCapabilities))
        return
    }

    let id = display.identity
    print("\(id.name) [id:\(id.displayID)]")
    print("  종류: \(id.isBuiltin ? "내장" : "외장"), 제조사 ID \(String(format: "0x%04X", id.vendorID)), 제품 ID \(String(format: "0x%04X", id.productID)), 일련번호 \(id.serialNumber)")
    print("  UUID: \(id.uuid ?? "없음")")
    print("  현재 모드: \(display.modeDescription), 픽셀 \(display.pixelWidth) x \(display.pixelHeight)")
    if let inches = display.diagonalInches, let ppi = display.pixelsPerInch {
        print("  물리 크기: \(Int(display.physicalWidthMM)) x \(Int(display.physicalHeightMM)) mm, \(String(format: "%.1f", inches)) 인치, \(String(format: "%.0f", ppi)) PPI")
    }
    guard let record else {
        print("  EDID: 없음 (\(id.isBuiltin ? "내장 패널은 EDID 미제공" : "획득 실패"))")
        return
    }
    let edid = record.parsed
    print("  EDID: \(edid.byteCount)바이트, 출처 \(record.source), 판 \(edid.version)")
    for issue in edid.issues { print("    문제: \(issue)") }
    print("    제조사 \(edid.manufacturerID), 제품 코드 \(edid.productCode), 제조 \(edid.manufactureYear)년 \(edid.manufactureWeek)주, 제품명 \(edid.productName ?? "없음")")
    print("    입력: \(edid.isDigital ? "디지털" : "아날로그")\(edid.digitalInterface.map { " \($0)" } ?? "")\(edid.bitsPerColor.map { ", \($0) bpc" } ?? ""), 감마 \(edid.gamma.map { String(format: "%.2f", $0) } ?? "미지정")")
    let caps = edid.sinkCapabilities
    print("  싱크 능력")
    print("    HDR: \(caps.hdrFormats.isEmpty ? "미지원" : caps.hdrFormats.joined(separator: ", "))\(caps.maxLuminance.map { String(format: ", 최대 %.0f cd/m²", $0) } ?? "")")
    print("    색 공간: \(caps.colorimetry.isEmpty ? "미보고" : caps.colorimetry.joined(separator: ", "))")
    print("    최대 주사율: \(caps.maxRefreshRate.map { "\($0) Hz" } ?? "미보고")")
    print("    VRR: \(caps.vrrMinHz.map { "\($0)-\(caps.vrrMaxHz ?? 0) Hz (\(caps.vrrSource ?? ""))" } ?? "미보고")")
    print("    최대 TMDS: \(caps.maxTMDSMHz.map { "\($0) MHz" } ?? "미보고"), 최대 FRL: \(caps.maxFRLGbps.map { "\($0) Gbps" } ?? "미보고")")
    print("    DSC: \(caps.supportsDSC.map { $0 ? "지원" : "미지원" } ?? "EDID 미보고")")
    print("    인코딩: RGB\(caps.supportsYCbCr444 ? ", YCbCr 4:4:4" : "")\(caps.supportsYCbCr422 ? ", YCbCr 4:2:2" : "")\(caps.supportsYCbCr420 ? ", YCbCr 4:2:0" : "")")
    print("  상세 타이밍 \(edid.detailedTimings.count)개")
    for t in edid.detailedTimings {
        print("    \(t.hActive)x\(t.vActive)\(t.interlaced ? "i" : "") \(String(format: "%.2f", t.refreshRate)) Hz, 픽셀 클록 \(String(format: "%.2f", t.pixelClockHz / 1e6)) MHz, 총 \(t.hTotal)x\(t.vTotal) (\(t.source))")
    }
    if let cta = edid.cta {
        print("  CTA-861 판 \(cta.revision): \(cta.dataBlocks.joined(separator: ", "))")
        print("    VIC \(cta.videoCodes.count)개: \(cta.videoCodes.map { "\($0.vic)\($0.isNative ? "*" : "")" }.joined(separator: " "))")
    }
    if let did = edid.displayID {
        print("  DisplayID \(did.version): \(did.dataBlocks.joined(separator: ", "))")
        if let tiled = did.tiledTopology { print("    타일 배치: \(tiled.summary)") }
    }
    if command.has("--hex") {
        print("  원본")
        print(HexDump.format(record.data).split(separator: "\n").map { "    \($0)" }.joined(separator: "\n"))
    }
}
