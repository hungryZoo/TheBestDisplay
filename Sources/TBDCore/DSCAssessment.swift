import Foundation

/// DSC(Display Stream Compression) 판정. (SRS-COL-004, PRD-COL-004, PRD-LNK-003)
public struct DSCAssessment: Codable, Hashable, Sendable {
    /// 소스(Mac의 DP 송신기) 지원. 확인 불가 시 nil.
    public var sourceSupportsDSC: Bool?
    /// 싱크 지원. 근거 자료가 없으면 nil.
    public var sinkSupportsDSC: Bool?
    /// 현재 모드의 DSC 사용 여부. 현재 타이밍과 색 모드를 알 수 없으면 nil.
    public var isActive: Bool?
    /// 현재 타이밍에서 DSC가 필요한 색 모드 수.
    public var dscRequiredModeCount: Int
    /// 현재 타이밍에서 DSC 없이 선택 가능한 색 모드 수.
    public var dscFreeModeCount: Int

    public var summary: String {
        switch (isActive, sinkSupportsDSC) {
        case (true?, _): "현재 모드는 DSC 압축 사용"
        case (false?, true?): "현재 모드는 DSC 미사용 (싱크는 DSC 지원)"
        case (false?, false?): "현재 모드는 DSC 미사용 (싱크가 DSC 미지원)"
        case (false?, nil): "현재 모드는 DSC 미사용"
        case (nil, _): "DSC 사용 여부 확인 불가"
        }
    }

    /// - Parameters:
    ///   - edidSupportsDSC: EDID의 DSC 선언 (HDMI Forum 블록). 미보고 시 nil.
    ///   - sourceSupportsDSC: 송신기 노드의 `SupportsDSC`.
    public static func assess(signal: SignalInfo, edidSupportsDSC: Bool?, sourceSupportsDSC: Bool?) -> DSCAssessment {
        let allElements = signal.sinkColorElements + signal.timings.flatMap(\.colorModes)
        let sink: Bool?
        if allElements.contains(where: \.supportsDSC) || signal.timings.contains(where: { !$0.dscRequiredColorElementIDs.isEmpty }) {
            sink = true
        } else if let edidSupportsDSC {
            sink = edidSupportsDSC
        } else {
            // 색 요소가 있는데 전부 DSC 미지원이면 싱크 미지원으로 판정. 자료가 없으면 미확인.
            sink = allElements.isEmpty ? nil : false
        }
        let timing = signal.currentTiming
        let selectable = signal.selectableColorModes
        let required = selectable.filter { timing?.requiresDSC($0.id) ?? false }
        var active: Bool?
        if let timing, let color = signal.currentColorID {
            // 1차 근거: 현재 색 ID가 현재 타이밍의 DSC 필수 목록에 포함되는지.
            active = timing.requiresDSC(color)
        }
        return DSCAssessment(
            sourceSupportsDSC: sourceSupportsDSC,
            sinkSupportsDSC: sink,
            isActive: active,
            dscRequiredModeCount: required.count,
            dscFreeModeCount: selectable.count - required.count
        )
    }
}
