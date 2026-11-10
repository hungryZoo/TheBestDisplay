import Foundation

/// 내장 패널 백라이트의 휘도. 단위는 밀리 cd/m². (PRD-BRT-008)
///
/// 출처는 프레임버퍼 노드(`IOMobileFramebufferShim`)의 레지스트리 속성. 값은 16.16 고정소수점 cd/m².
/// 백라이트 드라이버 노드(`AppleARMBacklight`)의 `BrightnessMilliNits`는 밝기를 바꿔도 변하지 않아 사용하지 않음 (T52 실측).
public struct BacklightLuminance: Codable, Sendable, Equatable {
    /// 현재 휘도 (`IOMFBBrightnessLevel`).
    public var currentMilliNits: Int
    /// 드라이버가 보고하는 현재 백라이트 상한 (`BLNitsCap`). 밝기 100%에서 현재 휘도와 같은 값.
    public var capMilliNits: Int?
    /// 패널 최대 휘도 (`IOMFBIndicatorNitsCap`).
    public var peakMilliNits: Int?

    public init(currentMilliNits: Int, capMilliNits: Int? = nil, peakMilliNits: Int? = nil) {
        self.currentMilliNits = currentMilliNits
        self.capMilliNits = capMilliNits
        self.peakMilliNits = peakMilliNits
    }

    /// 프레임버퍼 노드 속성 해석. 현재 휘도 속성이 없으면 nil.
    public init?(framebufferProperties: [String: Any]) {
        guard let current = Self.milliNits(fixedPoint: framebufferProperties["IOMFBBrightnessLevel"]) else { return nil }
        self.init(
            currentMilliNits: current,
            capMilliNits: Self.milliNits(fixedPoint: framebufferProperties["BLNitsCap"]).flatMap { $0 > 0 ? $0 : nil },
            peakMilliNits: Self.milliNits(fixedPoint: framebufferProperties["IOMFBIndicatorNitsCap"]).flatMap { $0 > 0 ? $0 : nil }
        )
    }

    /// 16.16 고정소수점 cd/m² 값을 밀리 cd/m²로 변환. 숫자가 아니거나 음수면 nil.
    public static func milliNits(fixedPoint value: Any?) -> Int? {
        guard let raw = (value as? NSNumber)?.int64Value, raw >= 0 else { return nil }
        return Int((Double(raw) / 65536 * 1000).rounded())
    }

    /// 현재 휘도 (cd/m²).
    public var current: Double { Double(currentMilliNits) / 1000 }

    /// 100 미만은 소수 한 자리, 그 이상은 정수로 표기.
    public static func format(_ nits: Double) -> String {
        nits < 100 ? String(format: "%.1f", nits) : String(format: "%.0f", nits)
    }

    /// 예: "170 cd/m² (백라이트 상한 400 cd/m², 패널 최대 1600 cd/m²)"
    public var summary: String {
        var notes: [String] = []
        if let capMilliNits { notes.append("백라이트 상한 \(Self.format(Double(capMilliNits) / 1000)) cd/m²") }
        if let peakMilliNits { notes.append("패널 최대 \(Self.format(Double(peakMilliNits) / 1000)) cd/m²") }
        return "\(Self.format(current)) cd/m²" + (notes.isEmpty ? "" : " (\(notes.joined(separator: ", ")))")
    }
}
