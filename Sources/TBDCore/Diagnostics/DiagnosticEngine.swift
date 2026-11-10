import Foundation

/// 진단 발견 항목. (PRD-DGN-002, PRD-DGN-003)
public struct Finding: Codable, Hashable, Sendable, Identifiable {
    public enum Severity: String, Codable, Sendable, Comparable {
        case info, warning, error

        private var rank: Int { self == .error ? 2 : self == .warning ? 1 : 0 }
        public static func < (a: Severity, b: Severity) -> Bool { a.rank < b.rank }

        public var label: String {
            switch self {
            case .info: "정보"
            case .warning: "주의"
            case .error: "문제"
            }
        }
    }

    /// 규칙 식별 부호. 예: "LINK.BANDWIDTH_LIMIT"
    public var code: String
    public var severity: Severity
    /// 대상: 디스플레이 이름 또는 포트 이름. 시스템 전체면 nil.
    public var subject: String?
    public var title: String
    /// 근거 수치를 포함한 설명.
    public var detail: String
    /// 조치 안내.
    public var remedy: String

    public var id: String { "\(code)|\(subject ?? "")" }

    public init(code: String, severity: Severity, subject: String?, title: String, detail: String, remedy: String) {
        self.code = code
        self.severity = severity
        self.subject = subject
        self.title = title
        self.detail = detail
        self.remedy = remedy
    }
}

/// 포트 1개의 미출력 점검 결과. (PRD-DGN-001)
public struct PortDiagnosis: Codable, Hashable, Sendable, Identifiable {
    public enum Stage: String, Codable, CaseIterable, Sendable {
        case physical, hpd, edid, link, framebuffer, online

        public var title: String {
            switch self {
            case .physical: "물리 연결 감지"
            case .hpd: "HPD"
            case .edid: "EDID 수신"
            case .link: "링크 수립"
            case .framebuffer: "프레임버퍼 할당"
            case .online: "온라인 등록"
            }
        }
    }

    public enum Result: String, Codable, Sendable { case pass, fail, skipped }

    public struct Check: Codable, Hashable, Sendable, Identifiable {
        public var stage: Stage
        public var result: Result
        public var detail: String
        public var id: String { stage.rawValue }
    }

    public var port: PortKey
    public var checks: [Check]

    public var id: String { "\(port.type)-\(port.number)" }
    public var firstFailure: Stage? { checks.first { $0.result == .fail }?.stage }
    public var isFullyPassed: Bool { checks.allSatisfy { $0.result == .pass } }
    /// 포트에 아무것도 연결되지 않아 점검 대상이 아닌 경우.
    public var isIdle: Bool { checks.first?.result != .pass }
}

/// 진단 결과 묶음.
public struct DiagnosticResult: Codable, Hashable, Sendable {
    public var findings: [Finding]
    public var portDiagnoses: [PortDiagnosis]

    public init(findings: [Finding], portDiagnoses: [PortDiagnosis]) {
        self.findings = findings
        self.portDiagnoses = portDiagnoses
    }

    public var worstSeverity: Finding.Severity? { findings.map(\.severity).max() }
}

/// 진단 규칙 엔진. 순수 함수. (SRS-DGN-001)
public enum DiagnosticEngine {
    public static func evaluate(_ snapshot: DiagnosticSnapshot) -> DiagnosticResult {
        let diagnoses = snapshot.paths.filter { $0.port.supportsDisplay }.map { diagnose($0, snapshot: snapshot) }
        var findings: [Finding] = []
        for (path, diagnosis) in zip(snapshot.paths.filter { $0.port.supportsDisplay }, diagnoses) {
            findings += portFindings(path: path, diagnosis: diagnosis, snapshot: snapshot)
        }
        for display in snapshot.displays {
            findings += displayFindings(display, snapshot: snapshot)
        }
        findings += systemFindings(snapshot, diagnoses: diagnoses)
        // 심각한 항목 먼저, 같은 심각도는 발견 순서 유지.
        let ordered = findings.enumerated().sorted { a, b in
            a.element.severity != b.element.severity ? a.element.severity > b.element.severity : a.offset < b.offset
        }.map(\.element)
        return DiagnosticResult(findings: ordered, portDiagnoses: diagnoses)
    }

    // MARK: - 미출력 점검 (PRD-DGN-001)

    static func diagnose(_ path: ConnectionPath, snapshot: DiagnosticSnapshot) -> PortDiagnosis {
        typealias Check = PortDiagnosis.Check
        var checks: [Check] = []
        var failed = false
        func add(_ stage: PortDiagnosis.Stage, _ passed: Bool, pass: String, fail: String) {
            if failed {
                checks.append(Check(stage: stage, result: .skipped, detail: "앞 단계 미통과로 생략"))
            } else {
                checks.append(Check(stage: stage, result: passed ? .pass : .fail, detail: passed ? pass : fail))
                if !passed { failed = true }
            }
        }
        let dp = path.dp
        let physical = path.port.connectionActive || path.port.hpdAsserted == true || dp?.hpdAsserted == true
        add(.physical, physical, pass: "연결 감지" + (path.port.partnerManufacturer.map { " (상대 장치: \($0))" } ?? ""), fail: "연결된 장치 없음")
        let hpd = dp?.hpdAsserted == true || path.port.hpdAsserted == true
        add(.hpd, hpd, pass: "디스플레이 연결 신호 감지" + (dp.map { " (\($0.hpdDescription))" } ?? ""), fail: "디스플레이 연결 신호 없음")
        let edidBytes = dp?.edid?.count ?? 0
        add(.edid, edidBytes >= 128, pass: "\(edidBytes)바이트 수신" + (dp?.productName.map { " (\($0))" } ?? ""), fail: "EDID 미수신")
        add(.link, dp?.hasLink == true && dp?.isActive == true, pass: dp.map { "\($0.linkRateDescription), 레인 \($0.laneCount)개" } ?? "", fail: "DisplayPort 링크 미수립 (\(dp?.linkRateDescription ?? "전송 상태 없음"))")
        // 프레임버퍼 할당: 같은 제품 정보를 가진 외장 프레임버퍼 노드 존재. 대응 정보가 없으면 외장 프레임버퍼 수로 판단.
        let externalFramebuffers = snapshot.attachedFramebuffers.filter(\.isExternal)
        let attached = path.reachesDisplay || externalFramebuffers.contains { fb in
            if let id = dp?.productID, let fbID = fb.productID { return id == fbID }
            return fb.productName != nil && fb.productName == dp?.productName
        }
        add(.framebuffer, attached, pass: "디스플레이 파이프 할당됨", fail: "링크는 수립되었으나 디스플레이 파이프 미할당")
        add(.online, path.reachesDisplay, pass: path.displayName.map { "\($0) 온라인" } ?? "온라인", fail: "시스템의 온라인 디스플레이 목록에 없음")
        return PortDiagnosis(port: path.port.key, checks: checks)
    }

    static func portFindings(path: ConnectionPath, diagnosis: PortDiagnosis, snapshot: DiagnosticSnapshot) -> [Finding] {
        var findings: [Finding] = []
        let subject = path.port.key.label
        guard !diagnosis.isIdle else { return [] }

        if let cable = path.cable, !cable.supportsHighSpeedData {
            findings.append(Finding(
                code: "CABLE.USB2_ONLY", severity: .error, subject: subject,
                title: "영상 신호를 실을 수 없는 케이블",
                detail: "케이블 e-marker의 속도 등급이 \(cable.speedName). 고속 레인이 없어 DisplayPort 신호 전달 불가",
                remedy: "영상 출력을 지원하는 USB-C 케이블(USB 3.2 이상, Thunderbolt, DisplayPort 대체 모드 지원)로 교체"
            ))
        }

        switch diagnosis.firstFailure {
        case .hpd?:
            let videoCapablePartner = path.cio?.isActive == true || path.port.transportsActive.contains("DisplayPort")
            if path.cio?.isActive == true {
                let supportsTunnel = path.cio?.tunneledTransportsSupported.contains("DisplayPort") ?? false
                findings.append(Finding(
                    code: "LINK.DOCK_NO_DISPLAY", severity: .warning, subject: subject,
                    title: "독에서 디스플레이가 감지되지 않음",
                    detail: "\(path.cio?.deviceName ?? "Thunderbolt 또는 USB4 장치") 연결은 정상(\(path.cio?.generationName ?? ""))이나 DisplayPort 터널이 열리지 않음" + (supportsTunnel ? "" : ". 이 장치는 DisplayPort 터널 지원을 알리지 않음"),
                    remedy: "독과 디스플레이 사이의 케이블, 디스플레이 전원과 입력 선택 확인. 독의 영상 포트를 바꿔 연결"
                ))
            } else if !videoCapablePartner {
                findings.append(Finding(
                    code: "PORT.NO_VIDEO_SIGNAL", severity: .info, subject: subject,
                    title: "영상 출력이 없는 연결",
                    detail: "장치는 연결되었으나 영상 연결 신호(HPD)가 없음. 활성 전송: \(path.port.transportsActive.isEmpty ? "없음" : path.port.transportsActive.joined(separator: ", "))",
                    remedy: "디스플레이를 연결한 포트라면 케이블이 영상 출력을 지원하는지, 디스플레이 전원과 입력 선택이 맞는지 확인. 충전기나 저장 장치라면 조치 불필요"
                ))
            }
        case .edid?:
            findings.append(Finding(
                code: "LINK.NO_EDID", severity: .error, subject: subject,
                title: "디스플레이 정보(EDID)를 받지 못함",
                detail: "디스플레이 연결 신호는 감지되었으나 EDID 미수신. 시스템이 지원 해상도를 알 수 없어 화면을 구성하지 못함",
                remedy: "케이블 재연결, 다른 케이블이나 포트 사용. 변환 어댑터나 KVM 경유라면 직결로 비교"
            ))
        case .link?:
            let viaDock = path.cio?.isActive == true
            findings.append(Finding(
                code: "LINK.HPD_NO_LINK", severity: .error, subject: subject,
                title: "디스플레이는 감지되었으나 영상 링크가 수립되지 않음",
                detail: "HPD \(path.dp?.hpdDescription ?? "감지"), 링크 상태 \(path.dp?.linkRateDescription ?? "없음"), 싱크 수 \(path.dp?.sinkCount ?? 0)" + (viaDock ? ". \(path.cio?.deviceName ?? "독") 경유" : ""),
                remedy: "케이블을 뽑았다가 다시 연결. 해결되지 않으면 디스플레이 전원을 껐다 켜고 입력 선택 확인" + (viaDock ? ", 독 전원 재인가" : "") + ". 반복되면 다른 케이블이나 포트로 비교"
            ))
        case .framebuffer?:
            var detail = "링크 \(path.dp?.linkRateDescription ?? "")는 수립되었으나 디스플레이 파이프가 할당되지 않음"
            var remedy = "케이블 재연결 또는 디스플레이 절전 후 깨우기"
            if let limit = snapshot.system.estimatedExternalDisplayLimit, snapshot.externalDisplayCount >= limit {
                detail += ". 현재 외장 디스플레이 \(snapshot.externalDisplayCount)대로 \(snapshot.system.chipName)의 한도 추정치 \(limit)대에 도달"
                remedy = "다른 외장 디스플레이 연결을 해제한 뒤 재연결"
            }
            findings.append(Finding(code: "DISPLAY.NO_PIPE", severity: .error, subject: subject, title: "디스플레이가 화면 구성에 포함되지 않음", detail: detail, remedy: remedy))
        case .online?:
            findings.append(Finding(
                code: "DISPLAY.NOT_ONLINE", severity: .error, subject: subject,
                title: "연결된 디스플레이가 시스템에서 비활성 상태",
                detail: "\(path.dp?.productName ?? "디스플레이")의 링크와 디스플레이 파이프는 준비되었으나 온라인 디스플레이 목록에 없음. 논리적으로 연결 해제되었거나 시스템이 비활성화한 상태",
                remedy: "케이블 재연결. 이 앱에서 연결 해제한 디스플레이라면 배치 탭의 재연결 사용"
            ))
        default:
            break
        }
        return findings
    }

    // MARK: - 모드 제한과 신호 품질 (PRD-DGN-002)

    static func displayFindings(_ display: DisplayDiagnostics, snapshot: DiagnosticSnapshot) -> [Finding] {
        guard !display.summary.identity.isBuiltin else { return [] }
        var findings: [Finding] = []
        let subject = display.summary.identity.name
        let link = display.link
        let state = link?.state
        let path = snapshot.paths.first { $0.displayID == display.id }
        let viaDock = path?.cio?.isActive == true
        let dockName = path?.cio?.deviceName ?? "독"

        // 대역폭 초과로 선택할 수 없는 색 형식.
        if let link, let available = link.availableGbps {
            let exceeded = link.colorModeBudgets.filter { $0.verdict == .exceedsBandwidth }
            if !exceeded.isEmpty {
                // 사용자가 가장 원할 만한 형식 순서: 현재 전달 함수의 RGB, 비트 심도 낮은 것부터.
                let currentEOTF = display.signal?.linkData?.eotf ?? display.signal?.currentColor?.eotf ?? .sdr
                let ranked = exceeded.sorted { a, b in
                    (a.descriptor.eotf == currentEOTF ? 0 : 1, a.descriptor.pixelEncoding.isRGB ? 0 : 1, a.descriptor.dynamicRange.rawValue, a.requiredGbps) < (b.descriptor.eotf == currentEOTF ? 0 : 1, b.descriptor.pixelEncoding.isRGB ? 0 : 1, b.descriptor.dynamicRange.rawValue, b.requiredGbps)
                }
                let examples = ranked.prefix(3).map { String(format: "%@ (필요 %.2f Gbps)", $0.descriptor.label, $0.requiredGbps) }.joined(separator: ", ")
                let timing = display.signal?.currentTiming?.label ?? "현재 타이밍"
                var causes: [String] = []
                var remedies: [String] = ["주사율 또는 해상도를 낮추면 선택 가능한 형식이 늘어남"]
                if let state, state.laneCount < state.maxLaneCount {
                    causes.append("레인 \(state.laneCount)개만 영상에 사용 (최대 \(state.maxLaneCount)개)")
                    remedies.append("USB 데이터와 영상을 나누어 쓰는 연결이면 영상 전용(4레인) 케이블이나 포트 사용")
                }
                if display.dsc?.sinkSupportsDSC == false {
                    causes.append("수신 측이 DSC 압축 미지원")
                }
                if let rate = state?.laneRateGbps {
                    causes.append("링크 속도 \(DPTransportState.rateName(rate)) x \(state?.laneCount ?? 0)레인")
                }
                if viaDock {
                    remedies.append("\(dockName) 경유 연결. 디스플레이를 Mac에 직접 연결하거나 더 높은 영상 대역폭을 지원하는 독으로 비교")
                }
                findings.append(Finding(
                    code: "LINK.BANDWIDTH_LIMIT", severity: .info, subject: subject,
                    title: "대역폭 한계로 선택할 수 없는 색 형식 \(exceeded.count)개",
                    detail: "\(timing)에서 유효 대역폭 \(String(format: "%.2f", available)) Gbps 초과: \(examples)" + (causes.isEmpty ? "" : ". 원인: " + causes.joined(separator: ", ")),
                    remedy: remedies.joined(separator: ". ")
                ))
            }
            if let utilization = link.utilization, utilization > 1.0, link.dscActive != true {
                findings.append(Finding(
                    code: "LINK.OVER_BUDGET", severity: .warning, subject: subject,
                    title: "현재 모드의 계산상 필요 대역폭이 유효 대역폭 초과",
                    detail: String(format: "필요 %.2f Gbps, 유효 %.2f Gbps. 링크 정보가 실제와 다르거나 압축이 쓰이고 있을 가능성", link.requiredGbps ?? 0, available),
                    remedy: "화면 깜박임이나 끊김이 있으면 주사율이나 비트 심도를 낮춤"
                ))
            }
        }

        // 크로마 서브샘플링.
        let encoding = display.signal?.linkData?.pixelEncoding ?? display.signal?.currentColor?.pixelEncoding
        if let encoding, encoding.componentsPerPixel < 3 {
            let selectable = display.signal?.selectableColorModes ?? []
            let currentEOTF = display.signal?.linkData?.eotf ?? display.signal?.currentColor?.eotf ?? .sdr
            let fullChromaSameEOTF = selectable.contains { $0.pixelEncoding.componentsPerPixel == 3 && $0.eotf == currentEOTF }
            let fullChromaSDR = selectable.contains { $0.pixelEncoding.componentsPerPixel == 3 && !$0.eotf.isHDR }
            var remedy: String
            if fullChromaSameEOTF {
                remedy = "색 모드 탭에서 RGB 또는 YCbCr 4:4:4 형식 선택 가능"
            } else if fullChromaSDR, currentEOTF.isHDR {
                remedy = "현재 타이밍의 HDR 형식은 서브샘플링만 제공. HDR을 끄면 RGB 또는 YCbCr 4:4:4 형식 선택 가능. HDR을 유지하려면 주사율을 낮춤"
            } else {
                remedy = "현재 타이밍에서는 서브샘플링 형식만 제공. 주사율 또는 해상도를 낮추면 RGB 형식 선택 가능"
            }
            findings.append(Finding(
                code: "SIGNAL.CHROMA_SUBSAMPLED", severity: .warning, subject: subject,
                title: "색 정보가 줄어든 신호(\(encoding.name))로 출력 중",
                detail: "크로마 서브샘플링은 색 해상도를 절반 이하로 줄여 작은 글자와 가는 선의 색 번짐 유발. 영상 재생에는 영향이 작고 문서와 코드 작업에서 차이가 큼",
                remedy: remedy
            ))
        }

        // 레인 축소.
        if let state, state.hasLink, state.laneCount < state.maxLaneCount {
            findings.append(Finding(
                code: "LINK.LANES_REDUCED", severity: .info, subject: subject,
                title: "영상 레인 \(state.laneCount)개 사용 (최대 \(state.maxLaneCount)개)",
                detail: "USB-C의 고속 레인 4개 중 일부가 USB 데이터에 할당되면 영상 대역폭이 절반으로 감소",
                remedy: "최대 해상도와 주사율이 필요하면 영상에 4레인을 쓰는 케이블, 어댑터, 독 설정 사용"
            ))
        }

        // 링크가 수신 측 최대 속도보다 낮게 수립.
        if let state, let rate = state.laneRateGbps, let sinkMax = display.dpcd?.maxLaneRateGbps, rate + 0.05 < sinkMax {
            findings.append(Finding(
                code: "LINK.RATE_BELOW_SINK_MAX", severity: .warning, subject: subject,
                title: "링크 속도가 수신 측 최대보다 낮음",
                detail: "현재 \(DPTransportState.rateName(rate)), 수신 측 최대 \(DPTransportState.rateName(sinkMax)). 링크 훈련이 낮은 속도로 내려갔을 가능성",
                remedy: "케이블 품질이나 길이가 원인일 수 있음. 짧은 인증 케이블로 교체하거나 다른 포트로 비교"
            ))
        }

        // 레인 상태 불량.
        if let dpcd = display.dpcd, !dpcd.laneStatus.isEmpty, dpcd.laneStatus.contains(where: { !$0.isGood }) {
            let bad = dpcd.laneStatus.filter { !$0.isGood }.map { "레인 \($0.lane)" }.joined(separator: ", ")
            findings.append(Finding(
                code: "LINK.LANE_STATUS_BAD", severity: .error, subject: subject,
                title: "일부 레인의 링크 훈련 미완료",
                detail: "\(bad)의 클록 복구, 채널 등화, 심볼 잠금 중 일부가 완료되지 않음",
                remedy: "케이블 재연결 또는 교체. 화면 깜박임, 끊김, 노이즈의 원인"
            ))
        }

        // DSC 사용 안내.
        if display.dsc?.isActive == true {
            findings.append(Finding(
                code: "DSC.ACTIVE", severity: .info, subject: subject,
                title: "DSC 압축 사용 중",
                detail: "현재 모드는 링크 대역폭에 맞추기 위해 DSC 압축 사용. 시각적 무손실을 목표로 한 압축",
                remedy: "압축 없는 출력이 필요하면 색 모드 탭에서 DSC 미사용 형식 선택 (주사율이나 비트 심도가 낮아질 수 있음)"
            ))
        }

        // 대역폭 여유가 거의 없음.
        if let utilization = link?.utilization, utilization > 0.95, utilization <= 1.0 {
            findings.append(Finding(
                code: "LINK.NEAR_CAPACITY", severity: .info, subject: subject,
                title: String(format: "링크 대역폭 사용률 %.1f%%", utilization * 100),
                detail: String(format: "현재 모드 %.2f Gbps, 유효 %.2f Gbps. 이 링크에서 낼 수 있는 최대에 가까운 형식", link?.requiredGbps ?? 0, link?.availableGbps ?? 0),
                remedy: "조치 불필요. 현재 타이밍에서 이보다 대역폭이 큰 형식은 선택 불가"
            ))
        }

        // EDID 문제.
        if let issues = display.edid?.issues, !issues.isEmpty {
            findings.append(Finding(
                code: "EDID.ISSUES", severity: .warning, subject: subject,
                title: "EDID 해석 중 문제 \(issues.count)건",
                detail: issues.joined(separator: ", "),
                remedy: "해상도 목록이 비정상이면 케이블이나 어댑터 교체로 비교. 시스템이 일련번호를 가린 EDID를 제공해 체크섬이 어긋나는 경우는 동작에 영향 없음"
            ))
        }
        return findings
    }

    // MARK: - 시스템 제약 (PRD-DGN-006)

    static func systemFindings(_ snapshot: DiagnosticSnapshot, diagnoses: [PortDiagnosis]) -> [Finding] {
        var findings: [Finding] = []
        if let limit = snapshot.system.estimatedExternalDisplayLimit, snapshot.externalDisplayCount >= limit {
            let blocked = diagnoses.contains { $0.firstFailure == .framebuffer || $0.firstFailure == .online }
            findings.append(Finding(
                code: "SYSTEM.EXTERNAL_LIMIT", severity: blocked ? .warning : .info, subject: nil,
                title: "외장 디스플레이 수가 칩 한도 추정치에 도달",
                detail: "\(snapshot.system.chipName)의 외장 디스플레이 한도 추정치 \(limit)대, 현재 \(snapshot.externalDisplayCount)대. 추가로 연결한 디스플레이는 화면이 나오지 않을 수 있음",
                remedy: "추가 디스플레이가 필요하면 기존 외장 디스플레이 1대를 분리. DisplayLink 방식 어댑터는 이 한도와 별개로 동작"
            ))
        }
        if snapshot.system.lidClosed == true {
            findings.append(Finding(
                code: "SYSTEM.LID_CLOSED", severity: .info, subject: nil,
                title: "덮개가 닫힌 상태",
                detail: "내장 디스플레이는 꺼지고 외장 디스플레이만 사용. 외장 디스플레이가 모두 끊기면 Mac이 잠자기에 들어감",
                remedy: "덮개를 닫고 쓰려면 전원 어댑터, 외장 키보드와 마우스 연결 유지"
            ))
        }
        return findings
    }
}
