import Foundation

/// 사용자 정의 상세 타이밍. EDID에 넣어 가상 EDID로 적용. (PRD-EDO-005, SRS-EDO-003)
public struct DetailedTimingSpec: Hashable, Sendable, Codable {
    public var hActive: Int, hFrontPorch: Int, hSyncWidth: Int, hBackPorch: Int
    public var vActive: Int, vFrontPorch: Int, vSyncWidth: Int, vBackPorch: Int
    public var pixelClockHz: Int
    public var hSyncPositive: Bool
    public var vSyncPositive: Bool

    public init(hActive: Int, hFrontPorch: Int, hSyncWidth: Int, hBackPorch: Int, vActive: Int, vFrontPorch: Int, vSyncWidth: Int, vBackPorch: Int, pixelClockHz: Int, hSyncPositive: Bool = true, vSyncPositive: Bool = false) {
        self.hActive = hActive
        self.hFrontPorch = hFrontPorch
        self.hSyncWidth = hSyncWidth
        self.hBackPorch = hBackPorch
        self.vActive = vActive
        self.vFrontPorch = vFrontPorch
        self.vSyncWidth = vSyncWidth
        self.vBackPorch = vBackPorch
        self.pixelClockHz = pixelClockHz
        self.hSyncPositive = hSyncPositive
        self.vSyncPositive = vSyncPositive
    }

    public var hBlank: Int { hFrontPorch + hSyncWidth + hBackPorch }
    public var vBlank: Int { vFrontPorch + vSyncWidth + vBackPorch }
    public var hTotal: Int { hActive + hBlank }
    public var vTotal: Int { vActive + vBlank }
    public var refreshRate: Double { Double(pixelClockHz) / Double(hTotal * vTotal) }

    /// 예: "2560 x 1440, 100 Hz, 409.07 MHz"
    public var label: String {
        "\(hActive) x \(vActive), \(DisplaySummary.formatHz(refreshRate)) Hz, \(String(format: "%.2f", Double(pixelClockHz) / 1e6)) MHz"
    }

    /// 값 범위 점검. 문제가 없으면 빈 배열.
    public var issues: [String] {
        var issues: [String] = []
        if !(64...65536).contains(hActive) || !(64...65536).contains(vActive) { issues.append("활성 해상도 범위 밖") }
        if hFrontPorch < 1 || hSyncWidth < 1 || hBackPorch < 0 { issues.append("수평 블랭킹 값 오류") }
        if vFrontPorch < 1 || vSyncWidth < 1 || vBackPorch < 0 { issues.append("수직 블랭킹 값 오류") }
        if pixelClockHz < 10_000 { issues.append("픽셀 클록이 10 kHz 미만") }
        if issues.isEmpty, !(1.0...1000.0).contains(refreshRate) { issues.append("주사율 범위 밖") }
        return issues
    }

    /// EDID 18바이트 상세 타이밍 서술자로 표현 가능한지: 픽셀 클록 655.35 MHz 이하, 활성과 블랭킹 4095 이하,
    /// 수평 프런트 포치와 동기 폭 1023 이하, 수직 프런트 포치와 동기 폭 63 이하.
    public var fitsDescriptor: Bool {
        pixelClockHz <= 655_350_000 && hActive <= 4095 && vActive <= 4095 && hBlank <= 4095 && vBlank <= 4095
            && hFrontPorch <= 1023 && hSyncWidth <= 1023 && vFrontPorch <= 63 && vSyncWidth <= 63
    }

    /// EDID 18바이트 상세 타이밍 서술자. 픽셀 클록은 10 kHz 단위로 내림.
    public func descriptor(widthMM: Int = 0, heightMM: Int = 0) throws -> [UInt8] {
        guard issues.isEmpty else { throw EDIDEditError.invalid(issues) }
        guard fitsDescriptor else { throw EDIDEditError.overflow("18바이트 서술자의 표현 범위 초과 (\(label))") }
        let clock = pixelClockHz / 10_000
        var d = [UInt8](repeating: 0, count: 18)
        d[0] = UInt8(clock & 0xFF)
        d[1] = UInt8(clock >> 8)
        d[2] = UInt8(hActive & 0xFF)
        d[3] = UInt8(hBlank & 0xFF)
        d[4] = UInt8((hActive >> 8) << 4 | (hBlank >> 8))
        d[5] = UInt8(vActive & 0xFF)
        d[6] = UInt8(vBlank & 0xFF)
        d[7] = UInt8((vActive >> 8) << 4 | (vBlank >> 8))
        d[8] = UInt8(hFrontPorch & 0xFF)
        d[9] = UInt8(hSyncWidth & 0xFF)
        d[10] = UInt8((vFrontPorch & 0xF) << 4 | (vSyncWidth & 0xF))
        d[11] = UInt8((hFrontPorch >> 8) << 6 | (hSyncWidth >> 8) << 4 | (vFrontPorch >> 4) << 2 | (vSyncWidth >> 4))
        let w = min(max(widthMM, 0), 4095), h = min(max(heightMM, 0), 4095)
        d[12] = UInt8(w & 0xFF)
        d[13] = UInt8(h & 0xFF)
        d[14] = UInt8((w >> 8) << 4 | (h >> 8))
        // 디지털 분리 동기 (비트 4-3 = 11), 비트 2 수직 극성, 비트 1 수평 극성.
        d[17] = 0x18 | (vSyncPositive ? 0x04 : 0) | (hSyncPositive ? 0x02 : 0)
        return d
    }

    /// DisplayID 20바이트 상세 타이밍 (1.x Type I, 2.x Type VII). 픽셀 클록 단위는 1.x에서 10 kHz, 2.x에서 1 kHz.
    public func displayIDTiming(preferred: Bool, version2: Bool) throws -> [UInt8] {
        guard issues.isEmpty else { throw EDIDEditError.invalid(issues) }
        let clock = pixelClockHz / (version2 ? 1_000 : 10_000) - 1
        guard clock >= 0, clock <= 0xFFFFFF, hActive <= 65536, vActive <= 65536, hBlank <= 65536, vBlank <= 65536,
              hFrontPorch <= 32768, hSyncWidth <= 65536, vFrontPorch <= 32768, vSyncWidth <= 65536
        else { throw EDIDEditError.overflow("DisplayID 상세 타이밍의 표현 범위 초과 (\(label))") }
        func le16(_ value: Int) -> [UInt8] { [UInt8(value & 0xFF), UInt8((value >> 8) & 0xFF)] }
        var d: [UInt8] = [UInt8(clock & 0xFF), UInt8((clock >> 8) & 0xFF), UInt8((clock >> 16) & 0xFF)]
        // 옵션: 비트 7 선호, 비트 3-0 종횡비 (8 = 미지정).
        d.append((preferred ? 0x80 : 0) | Self.aspectCode(hActive, vActive))
        d += le16(hActive - 1) + le16(hBlank - 1)
        d += le16((hFrontPorch - 1) | (hSyncPositive ? 0x8000 : 0)) + le16(hSyncWidth - 1)
        d += le16(vActive - 1) + le16(vBlank - 1)
        d += le16((vFrontPorch - 1) | (vSyncPositive ? 0x8000 : 0)) + le16(vSyncWidth - 1)
        return d
    }

    static func aspectCode(_ w: Int, _ h: Int) -> UInt8 {
        let table: [(Int, Int, UInt8)] = [(1, 1, 0), (5, 4, 1), (4, 3, 2), (15, 9, 3), (16, 9, 4), (16, 10, 5), (64, 27, 6), (256, 135, 7)]
        return table.first { w * $0.1 == h * $0.0 }?.2 ?? 8
    }

    // MARK: - CVT 축소 블랭킹

    public enum Formula: String, Codable, Sendable, CaseIterable {
        /// CVT 축소 블랭킹 1판: 수평 블랭킹 160, 클록 단계 0.25 MHz.
        case reducedBlanking = "rb"
        /// CVT 축소 블랭킹 2판: 수평 블랭킹 80, 클록 단계 0.001 MHz.
        case reducedBlanking2 = "rb2"

        public var title: String { self == .reducedBlanking ? "CVT-RB" : "CVT-RB2" }
    }

    /// VESA CVT의 축소 블랭킹 타이밍 계산.
    /// - 공통: 최소 수직 블랭킹 시간 460 µs, 최소 수직 백 포치 6라인.
    /// - 1판: 수평 프런트 포치 48, 동기 32, 백 포치 80. 수직 프런트 포치 3, 수직 동기 폭은 종횡비별(4:3은 4, 16:9는 5, 16:10은 6, 5:4와 15:9는 7, 그 외 10). 수평 활성은 8의 배수로 내림.
    /// - 2판: 수평 프런트 포치 8, 동기 32, 백 포치 40. 수직 동기 8, 백 포치 6 고정, 프런트 포치는 나머지.
    public static func cvt(width: Int, height: Int, refreshRate: Double, formula: Formula) -> DetailedTimingSpec? {
        guard width >= 64, height >= 64, refreshRate >= 1, refreshRate <= 1000 else { return nil }
        let minVBlankMicroseconds = 460.0
        let minVBackPorch = 6
        let hActive = formula == .reducedBlanking ? width / 8 * 8 : width
        let hPeriodEstimate = (1_000_000.0 / refreshRate - minVBlankMicroseconds) / Double(height)
        guard hPeriodEstimate > 0 else { return nil }
        let vbiLines = Int(minVBlankMicroseconds / hPeriodEstimate) + 1

        switch formula {
        case .reducedBlanking:
            let vSync: Int
            switch (width * 3 == height * 4, width * 9 == height * 16, width * 10 == height * 16, width * 4 == height * 5 || width * 9 == height * 15) {
            case (true, _, _, _): vSync = 4
            case (_, true, _, _): vSync = 5
            case (_, _, true, _): vSync = 6
            case (_, _, _, true): vSync = 7
            default: vSync = 10
            }
            let vFront = 3
            let vbi = max(vbiLines, vFront + vSync + minVBackPorch)
            let hTotal = hActive + 160
            let vTotal = height + vbi
            let step = 250_000.0
            let clock = (refreshRate * Double(vTotal) * Double(hTotal) / step).rounded(.down) * step
            return DetailedTimingSpec(
                hActive: hActive, hFrontPorch: 48, hSyncWidth: 32, hBackPorch: 80,
                vActive: height, vFrontPorch: vFront, vSyncWidth: vSync, vBackPorch: vbi - vFront - vSync,
                pixelClockHz: Int(clock), hSyncPositive: true, vSyncPositive: false
            )
        case .reducedBlanking2:
            let vSync = 8
            let vbi = max(vbiLines, 1 + vSync + minVBackPorch)
            let hTotal = hActive + 80
            let vTotal = height + vbi
            let step = 1_000.0
            let clock = (refreshRate * Double(vTotal) * Double(hTotal) / step).rounded(.down) * step
            return DetailedTimingSpec(
                hActive: hActive, hFrontPorch: 8, hSyncWidth: 32, hBackPorch: 40,
                vActive: height, vFrontPorch: vbi - vSync - minVBackPorch, vSyncWidth: vSync, vBackPorch: minVBackPorch,
                pixelClockHz: Int(clock), hSyncPositive: true, vSyncPositive: false
            )
        }
    }

    /// 명령행 표기.
    /// - `<폭>x<높이>@<주사율>[:rb|:rb2]`: CVT 축소 블랭킹 계산. 기본은 rb2.
    /// - `raw:<수평 활성>,<프런트 포치>,<동기>,<백 포치>,<수직 활성>,<프런트 포치>,<동기>,<백 포치>,<픽셀 클록 kHz>[,+h|-h][,+v|-v]`
    public static func parse(_ text: String) -> DetailedTimingSpec? {
        let lower = text.lowercased()
        if lower.hasPrefix("raw:") {
            let parts = lower.dropFirst(4).split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            let numbers = parts.prefix(9).compactMap { Int($0) }
            guard numbers.count == 9, parts.count <= 11 else { return nil }
            var spec = DetailedTimingSpec(
                hActive: numbers[0], hFrontPorch: numbers[1], hSyncWidth: numbers[2], hBackPorch: numbers[3],
                vActive: numbers[4], vFrontPorch: numbers[5], vSyncWidth: numbers[6], vBackPorch: numbers[7],
                pixelClockHz: numbers[8] * 1000
            )
            for flag in parts.dropFirst(9) {
                switch flag {
                case "+h": spec.hSyncPositive = true
                case "-h": spec.hSyncPositive = false
                case "+v": spec.vSyncPositive = true
                case "-v": spec.vSyncPositive = false
                default: return nil
                }
            }
            return spec.issues.isEmpty ? spec : nil
        }
        let sections = lower.split(separator: ":").map(String.init)
        guard let first = sections.first, sections.count <= 2 else { return nil }
        let formula: Formula
        if sections.count == 2 {
            guard let parsed = Formula(rawValue: sections[1]) else { return nil }
            formula = parsed
        } else {
            formula = .reducedBlanking2
        }
        let sizeAndRate = first.split(separator: "@").map(String.init)
        guard sizeAndRate.count == 2, let rate = Double(sizeAndRate[1]) else { return nil }
        let size = sizeAndRate[0].split(separator: "x").compactMap { Int($0) }
        guard size.count == 2 else { return nil }
        return cvt(width: size[0], height: size[1], refreshRate: rate, formula: formula)
    }
}
