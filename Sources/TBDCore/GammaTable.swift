import Foundation

/// 소프트웨어 색 조정 값. 전달 테이블 하나로 합성. (SRS-CLR-001, PRD-CLR-002, PRD-BRT-003)
public struct ColorAdjustment: Codable, Hashable, Sendable {
    /// 소프트웨어 디밍. 1은 원래 밝기, 0.1이 하한.
    public var dimming: Double = 1
    /// 감마 지수 보정. 1은 변화 없음, 1보다 크면 어두운 영역이 더 어두워짐.
    public var gamma: Double = 1
    /// 대비. 1은 변화 없음. 중간 밝기 0.5를 기준으로 기울기 조절.
    public var contrast: Double = 1
    /// 색온도 (K). 6500이 변화 없음. 낮을수록 따뜻한 색.
    public var temperature: Double = 6500
    public var redGain: Double = 1
    public var greenGain: Double = 1
    public var blueGain: Double = 1
    /// XDR 밝기 업스케일 배율. 1은 끔. EDR 헤드룸이 열린 상태에서 전달 테이블 출력값을 1.0 위로 올림. (PRD-BRT-005)
    public var xdrBoost: Double = 1

    public init() {}

    public static let identity = ColorAdjustment()
    public var isIdentity: Bool { self == .identity }

    public static let dimmingRange = 0.1...1.0
    public static let gammaRange = 0.5...2.0
    public static let contrastRange = 0.5...1.5
    public static let temperatureRange = 2700.0...9300.0
    public static let gainRange = 0.5...1.0
    public static let xdrBoostRange = 1.0...2.0

    /// 허용 범위로 자른 사본.
    public func clamped() -> ColorAdjustment {
        var c = self
        c.dimming = min(max(dimming, Self.dimmingRange.lowerBound), Self.dimmingRange.upperBound)
        c.gamma = min(max(gamma, Self.gammaRange.lowerBound), Self.gammaRange.upperBound)
        c.contrast = min(max(contrast, Self.contrastRange.lowerBound), Self.contrastRange.upperBound)
        c.temperature = min(max(temperature, Self.temperatureRange.lowerBound), Self.temperatureRange.upperBound)
        c.redGain = min(max(redGain, Self.gainRange.lowerBound), Self.gainRange.upperBound)
        c.greenGain = min(max(greenGain, Self.gainRange.lowerBound), Self.gainRange.upperBound)
        c.blueGain = min(max(blueGain, Self.gainRange.lowerBound), Self.gainRange.upperBound)
        c.xdrBoost = min(max(xdrBoost, Self.xdrBoostRange.lowerBound), Self.xdrBoostRange.upperBound)
        return c
    }
}

/// 디스플레이 전달 테이블 (채널별 0-1 값).
public struct GammaTable: Equatable, Sendable {
    public var red: [Float]
    public var green: [Float]
    public var blue: [Float]

    public static let defaultSize = 256

    public init(red: [Float], green: [Float], blue: [Float]) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// 색온도의 채널 배율. 6500 K를 (1, 1, 1)로 정규화한 흑체 근사식 사용.
    /// 최댓값이 1이 되도록 맞춰 어느 채널도 원래보다 밝아지지 않음.
    public static func temperatureMultipliers(_ kelvin: Double) -> (red: Double, green: Double, blue: Double) {
        func raw(_ k: Double) -> (Double, Double, Double) {
            let t = k / 100
            let r = t <= 66 ? 255 : 329.698727446 * pow(t - 60, -0.1332047592)
            let g = t <= 66 ? 99.4708025861 * log(t) - 161.1195681661 : 288.1221695283 * pow(t - 60, -0.0755148492)
            let b = t >= 66 ? 255 : (t <= 19 ? 0 : 138.5177312231 * log(t - 10) - 305.0447927307)
            return (min(max(r, 0), 255), min(max(g, 0), 255), min(max(b, 0), 255))
        }
        let value = raw(kelvin), reference = raw(6500)
        let r = value.0 / reference.0, g = value.1 / reference.1, b = value.2 / reference.2
        let peak = max(r, g, b)
        return peak > 0 ? (r / peak, g / peak, b / peak) : (1, 1, 1)
    }

    /// 조정 값을 전달 테이블로 합성. 적용 순서: 대비, 감마, 채널 배율(색온도와 게인), 디밍.
    public static func make(_ adjustment: ColorAdjustment, size: Int = defaultSize) -> GammaTable {
        let a = adjustment.clamped()
        let count = max(2, size)
        let temp = temperatureMultipliers(a.temperature)
        let gains = (temp.red * a.redGain, temp.green * a.greenGain, temp.blue * a.blueGain)
        func channel(_ gain: Double) -> [Float] {
            (0..<count).map { index in
                var v = Double(index) / Double(count - 1)
                v = (v - 0.5) * a.contrast + 0.5
                v = min(max(v, 0), 1)
                v = pow(v, a.gamma)
                v *= gain * a.dimming
                return Float(min(max(v, 0), 1))
            }
        }
        return GammaTable(red: channel(gains.0), green: channel(gains.1), blue: channel(gains.2))
    }

    /// 단조 증가 여부. 전달 테이블이 역전되면 계조가 뒤집힘.
    public var isMonotonic: Bool {
        [red, green, blue].allSatisfy { channel in zip(channel, channel.dropFirst()).allSatisfy { $0 <= $1 } }
    }
}

/// 밝기 제어 방식. (SRS-BRT-001)
public enum BrightnessMethod: String, Codable, Sendable {
    /// 시스템 밝기 제어 (내장, Apple 디스플레이).
    case native
    case ddc
    /// 전달 테이블 디밍.
    case software

    public var title: String {
        switch self {
        case .native: "시스템 밝기 제어"
        case .ddc: "DDC"
        case .software: "소프트웨어 디밍"
        }
    }
}

public extension GammaTable {
    /// 조정 테이블을 기준 테이블(디스플레이 보정값) 위에 합성: 결과[i] = 기준(조정[i]). 기준 테이블은 선형 보간으로 조회.
    func composed(over baseline: GammaTable) -> GammaTable {
        func lookup(_ table: [Float], _ value: Float) -> Float {
            guard table.count >= 2 else { return value }
            let position = Double(min(max(value, 0), 1)) * Double(table.count - 1)
            let lower = Int(position.rounded(.down))
            let upper = min(lower + 1, table.count - 1)
            let fraction = Float(position - Double(lower))
            return table[lower] + (table[upper] - table[lower]) * fraction
        }
        return GammaTable(
            red: red.map { lookup(baseline.red, $0) },
            green: green.map { lookup(baseline.green, $0) },
            blue: blue.map { lookup(baseline.blue, $0) }
        )
    }

    /// 전 채널에 배율 적용. XDR 밝기 업스케일에서 기준 테이블 합성 뒤 사용하며 결과가 1.0을 넘음.
    func scaled(by factor: Double) -> GammaTable {
        let f = Float(factor)
        return GammaTable(red: red.map { $0 * f }, green: green.map { $0 * f }, blue: blue.map { $0 * f })
    }

    static func linear(size: Int = defaultSize) -> GammaTable {
        let ramp = (0..<max(2, size)).map { Float($0) / Float(max(2, size) - 1) }
        return GammaTable(red: ramp, green: ramp, blue: ramp)
    }
}
