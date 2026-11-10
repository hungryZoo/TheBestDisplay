import Foundation

/// 싱크 타이밍의 서술. 타이밍 ID는 연결마다 바뀔 수 있어 복귀에는 서술 사용.
public struct TimingDescriptor: Codable, Hashable, Sendable {
    public var hActive: Int
    public var vActive: Int
    public var refreshRate: Double
    public var isInterlaced: Bool

    public init(hActive: Int, vActive: Int, refreshRate: Double, isInterlaced: Bool = false) {
        self.hActive = hActive
        self.vActive = vActive
        self.refreshRate = refreshRate
        self.isInterlaced = isInterlaced
    }

    public init(_ timing: TimingElement) {
        self.init(hActive: timing.hActive, vActive: timing.vActive, refreshRate: timing.refreshRate, isInterlaced: timing.isInterlaced)
    }

    /// 목록에서 일치하는 타이밍. 주사율은 0.005 Hz 이내를 같은 값으로 간주 (59.94와 60 구분).
    public func find(in timings: [TimingElement]) -> TimingElement? {
        timings.first { $0.hActive == hActive && $0.vActive == vActive && $0.isInterlaced == isInterlaced && abs($0.refreshRate - refreshRate) < 0.005 && !$0.isVirtual }
    }
}

/// 연결 수준 타이밍 직접 선택의 계획. 시스템 모드 목록에 없는 주사율(59.94 Hz 등)의 타이밍을 고를 때 사용. (PRD-COL-007, SRS-COL-007)
public enum TimingSelection {
    public enum Unavailable: Error, Equatable, LocalizedError {
        case unknownCurrentMode
        case timingNotFound(String)
        case alreadyCurrent
        case noColorMode

        public var errorDescription: String? {
            switch self {
            case .unknownCurrentMode: "현재 타이밍과 색 모드를 확인할 수 없음"
            case .timingNotFound(let text): "일치하는 타이밍 없음: \(text)"
            case .alreadyCurrent: "이미 현재 타이밍"
            case .noColorMode: "대상 타이밍에 선택 가능한 색 모드 없음"
            }
        }
    }

    /// 명령행 지정: `id:<번호>` 또는 `<폭>x<높이>@<주사율>`. 주사율은 0.05 Hz 이내에서 가장 가까운 타이밍.
    public static func resolve(_ text: String, in timings: [TimingElement]) -> TimingElement? {
        let lower = text.lowercased()
        if lower.hasPrefix("id:") {
            guard let id = Int(lower.dropFirst(3)) else { return nil }
            return timings.first { $0.id == id }
        }
        let parts = lower.split(separator: "@").map(String.init)
        guard parts.count == 2, let rate = Double(parts[1]) else { return nil }
        let size = parts[0].split(separator: "x").compactMap { Int($0) }
        guard size.count == 2 else { return nil }
        return timings
            .filter { $0.hActive == size[0] && $0.vActive == size[1] && !$0.isVirtual && !$0.isInterlaced && abs($0.refreshRate - rate) < 0.05 }
            .min { abs($0.refreshRate - rate) < abs($1.refreshRate - rate) }
    }

    /// 대상 타이밍에서 쓸 색 모드 선택.
    /// 순서: 현재와 같은 서술, 같은 전달 함수 가운데 시스템 점수가 높은 것, 그 밖의 형식 가운데 점수가 높은 것. 가상 형식과 안전하지 않은 형식 제외.
    public static func plan(signal: SignalInfo, target: TimingElement) -> Result<ColorElement, Unavailable> {
        guard let currentTiming = signal.currentTiming, let currentColor = signal.currentColor else { return .failure(.unknownCurrentMode) }
        guard target.id != currentTiming.id else { return .failure(.alreadyCurrent) }
        let candidates = target.colorModes.filter { !$0.isVirtual && !target.unsafeColorElementIDs.contains($0.id) }
        guard !candidates.isEmpty else { return .failure(.noColorMode) }
        func key(_ e: ColorElement) -> (Int, Int, Int, Int) {
            (e.descriptor == currentColor.descriptor ? 0 : 1, e.eotf == currentColor.eotf ? 0 : 1, -(e.score ?? 0), e.id)
        }
        return .success(candidates.min { key($0) < key($1) }!)
    }
}
