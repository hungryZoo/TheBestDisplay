import Foundation

/// DSC 켜기와 끄기 계획. (SRS-COL-006, PRD-COL-006)
///
/// macOS에는 DSC를 직접 켜고 끄는 비권한 API가 없음. 타이밍 요소의 `DSCRequiredColorElementIDs`가
/// 색 모드별 DSC 사용 여부를 정하므로, 현재 타이밍을 유지한 채 DSC 사용 색 모드와 미사용 색 모드 사이를 전환.
public enum DSCControl {
    public enum Unavailable: Error, Equatable, LocalizedError {
        /// 현재 타이밍 또는 색 모드를 확인할 수 없음.
        case unknownCurrentMode
        /// 이미 요청한 상태.
        case alreadyInState(enabled: Bool)
        /// 요청한 상태의 색 모드가 없음.
        case noCandidate(enable: Bool, reason: String)

        public var errorDescription: String? {
            switch self {
            case .unknownCurrentMode: "현재 타이밍과 색 모드를 확인할 수 없음"
            case .alreadyInState(let enabled): "이미 DSC \(enabled ? "사용" : "미사용") 상태"
            case .noCandidate(_, let reason): reason
            }
        }
    }

    /// 현재 타이밍에서 DSC 상태별 후보 색 모드. 가상 형식과 안전하지 않은 형식 제외.
    public static func candidates(signal: SignalInfo, usingDSC: Bool) -> [ColorElement] {
        guard let timing = signal.currentTiming else { return [] }
        return signal.selectableColorModes.filter {
            timing.requiresDSC($0.id) == usingDSC && !timing.unsafeColorElementIDs.contains($0.id)
        }
    }

    /// 요청한 DSC 상태로 전환할 때 선택할 색 모드.
    /// 선택 순서: (1) 현재와 같은 전달 함수만 대상 (HDR 상태 유지), (2) 현재와 같은 서술, (3) 시스템 점수가 높은 것,
    /// (4) 같은 픽셀 인코딩, (5) 비트 심도 차이가 작은 것, (6) 같은 레인지.
    public static func plan(signal: SignalInfo, enable: Bool) -> Result<ColorElement, Unavailable> {
        guard let timing = signal.currentTiming, let current = signal.currentColor else {
            return .failure(.unknownCurrentMode)
        }
        if timing.requiresDSC(current.id) == enable {
            return .failure(.alreadyInState(enabled: enable))
        }
        let all = candidates(signal: signal, usingDSC: enable)
        let sameEOTF = all.filter { $0.eotf == current.eotf }
        guard !sameEOTF.isEmpty else {
            return .failure(.noCandidate(enable: enable, reason: refusalReason(signal: signal, timing: timing, current: current, enable: enable, anyEOTFCount: all.count)))
        }
        func key(_ e: ColorElement) -> (Int, Int, Int, Int, Int, Int) {
            (
                e.descriptor == current.descriptor ? 0 : 1,
                -(e.score ?? 0),
                e.pixelEncoding == current.pixelEncoding ? 0 : 1,
                abs(e.bitsPerComponent - current.bitsPerComponent),
                e.dynamicRange == current.dynamicRange ? 0 : 1,
                e.id
            )
        }
        return .success(sameEOTF.min { key($0) < key($1) }!)
    }

    static func refusalReason(signal: SignalInfo, timing: TimingElement, current: ColorElement, enable: Bool, anyEOTFCount: Int) -> String {
        if anyEOTFCount > 0 {
            return "현재 전달 함수(\(current.eotf.name))에서 DSC \(enable ? "사용" : "미사용") 색 모드 없음. HDR 상태를 바꾸면 후보 \(anyEOTFCount)개 선택 가능"
        }
        if enable {
            let anyDSC = signal.timings.contains { !$0.dscRequiredColorElementIDs.isEmpty }
            return anyDSC
                ? "현재 타이밍(\(timing.label))에는 DSC 사용 색 모드 없음. DSC 사용 타이밍은 더 높은 해상도 또는 주사율에 존재"
                : "시스템이 이 연결에 DSC 사용 색 모드를 제공하지 않음 (싱크 또는 중간 장치의 DSC 미지원)"
        }
        let freeElsewhere = signal.timings.contains { t in
            t.colorModes.contains { !$0.isVirtual && !t.requiresDSC($0.id) }
        }
        return freeElsewhere
            ? "현재 타이밍(\(timing.label))의 색 모드는 모두 DSC 필요. 해상도 또는 주사율을 낮추면 DSC 미사용 모드 선택 가능"
            : "이 연결의 모든 모드가 DSC 필요"
    }

    /// 전환 가능 여부 요약. 화면 버튼의 활성 상태에 사용.
    public static func availability(signal: SignalInfo) -> (canEnable: Bool, canDisable: Bool) {
        func ok(_ enable: Bool) -> Bool {
            if case .success = plan(signal: signal, enable: enable) { return true }
            return false
        }
        return (ok(true), ok(false))
    }
}
