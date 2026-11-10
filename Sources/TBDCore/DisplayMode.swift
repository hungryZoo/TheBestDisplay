import Foundation

/// 디스플레이 모드 1개. (PRD-MOD-001)
public struct DisplayMode: Codable, Hashable, Sendable, Identifiable {
    /// 윈도우 서버의 모드 번호. 모드 목록이 재구성되면 바뀔 수 있으므로 저장용 식별에는 `descriptor` 사용.
    public var modeNumber: Int32
    /// 논리 해상도 (포인트).
    public var width: Int
    public var height: Int
    /// 백킹 해상도 (픽셀).
    public var pixelWidth: Int
    public var pixelHeight: Int
    public var scale: Double
    public var refreshRate: Double
    public var bitsPerSample: Int
    public var flags: UInt32
    public var isVRR: Bool
    public var isProMotion: Bool
    /// 시스템 설정의 해상도 목록에 표시되는 모드인지. (PRD-MOD-006)
    public var isInSystemDefaultList: Bool
    /// 패널 원본 해상도 모드 (시스템 판정).
    public var isNative: Bool = false
    /// 시스템 기본 모드.
    public var isDefault: Bool = false

    public var id: Int32 { modeNumber }
    public var isHiDPI: Bool { scale >= 2 }

    public init(modeNumber: Int32, width: Int, height: Int, pixelWidth: Int, pixelHeight: Int, scale: Double, refreshRate: Double, bitsPerSample: Int = 8, flags: UInt32 = 0, isVRR: Bool = false, isProMotion: Bool = false, isInSystemDefaultList: Bool = true) {
        self.modeNumber = modeNumber
        self.width = width
        self.height = height
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.scale = scale
        self.refreshRate = refreshRate
        self.bitsPerSample = bitsPerSample
        self.flags = flags
        self.isVRR = isVRR
        self.isProMotion = isProMotion
        self.isInSystemDefaultList = isInSystemDefaultList
    }

    /// 윈도우 서버 모드 서술 구조체의 길이. (spikes 문서 S1, platform-apis 문서 1.2절)
    public static let descriptionLength = 212

    /// 212바이트 모드 서술 구조체 해석. 길이가 다르면 nil.
    /// 오프셋: 0x00 모드 번호, 0x04 플래그, 0x08 논리 폭, 0x0C 논리 높이, 0x1C 샘플당 비트, 0x24 정수 주사율,
    /// 0xBC 주사율(16.16 고정소수점), 0xC8 픽셀 폭, 0xCC 픽셀 높이, 0xD0 배율(float).
    public static func decode(_ bytes: [UInt8]) -> DisplayMode? {
        guard bytes.count == descriptionLength else { return nil }
        func u32(_ offset: Int) -> UInt32 {
            UInt32(bytes[offset]) | UInt32(bytes[offset + 1]) << 8 | UInt32(bytes[offset + 2]) << 16 | UInt32(bytes[offset + 3]) << 24
        }
        let width = Int(u32(0x08)), height = Int(u32(0x0C))
        guard width > 0, height > 0 else { return nil }
        let scale = Double(Float(bitPattern: u32(0xD0)))
        let fixedRate = Double(u32(0xBC)) / 65536
        let pixelWidth = Int(u32(0xC8)), pixelHeight = Int(u32(0xCC))
        let effectiveScale = scale > 0 ? scale : 1
        return DisplayMode(
            modeNumber: Int32(bitPattern: u32(0x00)),
            width: width, height: height,
            pixelWidth: pixelWidth > 0 ? pixelWidth : Int(Double(width) * effectiveScale),
            pixelHeight: pixelHeight > 0 ? pixelHeight : Int(Double(height) * effectiveScale),
            scale: effectiveScale,
            refreshRate: fixedRate > 0 ? fixedRate : Double(u32(0x24)),
            bitsPerSample: Int(u32(0x1C)),
            flags: u32(0x04)
        )
    }

    public var descriptor: ModeDescriptor {
        ModeDescriptor(width: width, height: height, isHiDPI: isHiDPI, refreshRate: refreshRate, isVRR: isVRR)
    }

    /// 예: "2304 x 1296 HiDPI, 120 Hz"
    public var label: String {
        "\(width) x \(height)\(isHiDPI ? " HiDPI" : ""), \(DisplaySummary.formatHz(refreshRate)) Hz\(isVRR ? " (가변)" : "")"
    }

    /// 약분한 종횡비. 예: "16:9". 흔한 근사 비율은 대표 이름으로 묶음.
    public var aspectRatio: String {
        let ratio = Double(width) / Double(height)
        let named: [(Double, String)] = [(16.0 / 9, "16:9"), (16.0 / 10, "16:10"), (4.0 / 3, "4:3"), (5.0 / 4, "5:4"), (21.0 / 9, "21:9"), (43.0 / 18, "21:9"), (32.0 / 9, "32:9"), (3.0 / 2, "3:2"), (256.0 / 135, "17:9")]
        if let match = named.first(where: { abs($0.0 - ratio) < 0.02 }) { return match.1 }
        func gcd(_ a: Int, _ b: Int) -> Int { b == 0 ? a : gcd(b, a % b) }
        let g = gcd(width, height)
        return "\(width / g):\(height / g)"
    }
}

/// 모드 번호에 의존하지 않는 모드 식별. 저장, 복귀, 명령행 지정에 사용.
public struct ModeDescriptor: Codable, Hashable, Sendable {
    public var width: Int
    public var height: Int
    public var isHiDPI: Bool
    public var refreshRate: Double
    public var isVRR: Bool

    public init(width: Int, height: Int, isHiDPI: Bool, refreshRate: Double, isVRR: Bool = false) {
        self.width = width
        self.height = height
        self.isHiDPI = isHiDPI
        self.refreshRate = refreshRate
        self.isVRR = isVRR
    }

    /// 목록에서 일치하는 모드. 주사율은 0.01 Hz 이내를 같은 값으로 간주.
    public func find(in modes: [DisplayMode]) -> DisplayMode? {
        let candidates = modes.filter { $0.width == width && $0.height == height && $0.isHiDPI == isHiDPI && abs($0.refreshRate - refreshRate) < 0.01 }
        return candidates.first { $0.isVRR == isVRR } ?? candidates.first
    }
}

/// 명령행의 모드 지정. 형식: `<폭>x<높이>[@<주사율>][:hidpi|:lodpi]` 또는 `mode:<번호>`.
public enum ModeSpec: Equatable, Sendable {
    case number(Int32)
    case resolution(width: Int, height: Int, refreshRate: Double?, hiDPI: Bool?)

    public enum ResolveError: Error, Equatable, Sendable {
        case notFound(String)

        public var message: String {
            switch self {
            case .notFound(let text): "일치하는 모드 없음: \(text)"
            }
        }
    }

    public static func parse(_ text: String) -> ModeSpec? {
        let lower = text.lowercased()
        if lower.hasPrefix("mode:") {
            return Int32(lower.dropFirst(5)).map { .number($0) }
        }
        var body = lower
        var hiDPI: Bool?
        if body.hasSuffix(":hidpi") {
            hiDPI = true
            body.removeLast(6)
        } else if body.hasSuffix(":lodpi") {
            hiDPI = false
            body.removeLast(6)
        }
        var rate: Double?
        if let at = body.firstIndex(of: "@") {
            guard let value = Double(body[body.index(after: at)...]), value > 0 else { return nil }
            rate = value
            body = String(body[..<at])
        }
        let parts = body.split(separator: "x")
        guard parts.count == 2, let w = Int(parts[0]), let h = Int(parts[1]), w > 0, h > 0 else { return nil }
        return .resolution(width: w, height: h, refreshRate: rate, hiDPI: hiDPI)
    }

    /// 지정과 일치하는 모드 선택. 생략한 항목은 현재 모드의 값 우선, 없으면 HiDPI와 높은 주사율 우선.
    public func resolve(in modes: [DisplayMode], current: DisplayMode?) throws -> DisplayMode {
        switch self {
        case .number(let number):
            guard let mode = modes.first(where: { $0.modeNumber == number }) else { throw ResolveError.notFound("mode:\(number)") }
            return mode
        case .resolution(let width, let height, let refreshRate, let hiDPI):
            var candidates = modes.filter { $0.width == width && $0.height == height }
            if let hiDPI { candidates = candidates.filter { $0.isHiDPI == hiDPI } }
            if let refreshRate { candidates = candidates.filter { abs($0.refreshRate - refreshRate) < 0.5 } }
            let wantedRate = refreshRate ?? current?.refreshRate
            let best = candidates.max { a, b in
                func score(_ m: DisplayMode) -> (Int, Int, Double, Int) {
                    let rateMatch = wantedRate.map { abs(m.refreshRate - $0) < 0.5 ? 1 : 0 } ?? 0
                    return (m.isHiDPI ? 1 : 0, rateMatch, m.refreshRate, m.isVRR == (current?.isVRR ?? false) ? 1 : 0)
                }
                return score(a) < score(b)
            }
            guard let best else {
                throw ResolveError.notFound("\(width)x\(height)" + (refreshRate.map { "@\(DisplaySummary.formatHz($0))" } ?? "") + (hiDPI.map { $0 ? ":hidpi" : ":lodpi" } ?? ""))
            }
            return best
        }
    }
}
