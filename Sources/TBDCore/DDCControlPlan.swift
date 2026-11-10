import Foundation

/// DDC 제어 항목 1개. capabilities가 알린 VCP 코드에서 구성. (PRD-DDC-005)
public struct DDCControl: Codable, Hashable, Sendable, Identifiable {
    public struct Option: Codable, Hashable, Sendable {
        public var value: UInt8
        public var name: String

        public init(value: UInt8, name: String) {
            self.value = value
            self.name = name
        }
    }

    public var code: UInt8
    public var title: String
    /// 연속 값(조절 막대)이면 빈 배열, 선택 값이면 선택 항목.
    public var options: [Option]
    /// 이 Mac의 화면 출력이 끊길 수 있는 제어 (입력 소스, 전원 모드).
    public var isDisruptive: Bool

    public var id: UInt8 { code }
    public var isContinuous: Bool { options.isEmpty }
    public var codeLabel: String { String(format: "0x%02X", code) }
}

/// capabilities 기반 제어 구성. MCCS 2.x 규격의 표준 코드만 제어 항목으로 만들고 나머지는 목록으로만 알림. (PRD-DDC-005)
public enum DDCControlPlan {
    struct Entry {
        var code: UInt8
        var title: String
        /// nil이면 연속 값. 값이 있으면 선택 값과 표준 이름.
        var options: [(UInt8, String)]?
        var isDisruptive = false
    }

    /// 표시 순서: 화질 연속 값, 색 연속 값, 음향, 선택 값.
    static let catalog: [Entry] = [
        Entry(code: 0x12, title: "대비"),
        Entry(code: 0x13, title: "백라이트"),
        Entry(code: 0x87, title: "선명도"),
        Entry(code: 0x8A, title: "채도"),
        Entry(code: 0x90, title: "색조"),
        Entry(code: 0x16, title: "게인 (빨강)"),
        Entry(code: 0x18, title: "게인 (초록)"),
        Entry(code: 0x1A, title: "게인 (파랑)"),
        Entry(code: 0x6C, title: "블랙 레벨 (빨강)"),
        Entry(code: 0x6E, title: "블랙 레벨 (초록)"),
        Entry(code: 0x70, title: "블랙 레벨 (파랑)"),
        Entry(code: 0x62, title: "볼륨"),
        Entry(code: 0x8D, title: "음소거", options: [(0x01, "음소거"), (0x02, "음소거 해제")]),
        Entry(code: 0x14, title: "색 프리셋", options: [
            (0x01, "sRGB"), (0x02, "디스플레이 기본"), (0x03, "4000 K"), (0x04, "5000 K"), (0x05, "6500 K"), (0x06, "7500 K"),
            (0x07, "8200 K"), (0x08, "9300 K"), (0x09, "10000 K"), (0x0A, "11500 K"), (0x0B, "사용자 1"), (0x0C, "사용자 2"), (0x0D, "사용자 3"),
        ]),
        Entry(code: 0xDC, title: "화면 모드", options: [
            (0x00, "표준"), (0x01, "문서 작업"), (0x02, "혼합"), (0x03, "영화"), (0x04, "사용자 정의"), (0x05, "게임"), (0x06, "스포츠"),
            (0x07, "전문가"), (0x08, "표준 (중간 전력)"), (0x09, "표준 (저전력)"), (0x0A, "시연"), (0xF0, "동적 명암비"),
        ]),
        Entry(code: 0x60, title: "입력 소스", options: [
            (0x01, "VGA 1"), (0x02, "VGA 2"), (0x03, "DVI 1"), (0x04, "DVI 2"), (0x05, "컴포지트 1"), (0x06, "컴포지트 2"),
            (0x07, "S-Video 1"), (0x08, "S-Video 2"), (0x09, "튜너 1"), (0x0A, "튜너 2"), (0x0B, "튜너 3"),
            (0x0C, "컴포넌트 1"), (0x0D, "컴포넌트 2"), (0x0E, "컴포넌트 3"),
            (0x0F, "DisplayPort 1"), (0x10, "DisplayPort 2"), (0x11, "HDMI 1"), (0x12, "HDMI 2"),
        ], isDisruptive: true),
        Entry(code: 0xD6, title: "전원 모드", options: [
            (0x01, "켜짐"), (0x02, "대기"), (0x03, "일시 중단"), (0x04, "꺼짐 (소프트)"), (0x05, "꺼짐 (전원)"),
        ], isDisruptive: true),
    ]

    /// 밝기(0x10)는 밝기 조절 막대가 담당하므로 제어 항목에서 제외.
    static let handledElsewhere: Set<UInt8> = [0x10]

    /// 표준 코드의 이름. 목록에 없으면 nil.
    public static func title(for code: UInt8) -> String? {
        if code == 0x10 { return "밝기" }
        return catalog.first { $0.code == code }?.title
    }

    /// capabilities가 알린 코드에서 제어 항목 구성.
    /// 선택 값 코드는 capabilities가 선택값을 알리면 그 값만, 알리지 않으면 표준 값 전체를 항목으로 둠.
    /// capabilities의 선택값 중 표준 이름이 없는 값은 "값 0xNN"으로 표기 (제조사 정의 값).
    public static func controls(for capabilities: DDCCapabilities) -> [DDCControl] {
        catalog.compactMap { entry -> DDCControl? in
            guard capabilities.supports(entry.code) else { return nil }
            guard let standard = entry.options else {
                return DDCControl(code: entry.code, title: entry.title, options: [], isDisruptive: entry.isDisruptive)
            }
            let options: [DDCControl.Option]
            if let listed = capabilities.vcpValues[entry.code], !listed.isEmpty {
                options = listed.map { value in
                    DDCControl.Option(value: value, name: standard.first { $0.0 == value }?.1 ?? String(format: "값 0x%02X", value))
                }
            } else {
                options = standard.map { DDCControl.Option(value: $0.0, name: $0.1) }
            }
            return DDCControl(code: entry.code, title: entry.title, options: options, isDisruptive: entry.isDisruptive)
        }
    }

    /// capabilities가 알렸지만 제어 항목으로 만들지 않은 코드 (제조사 정의 코드, 읽기 전용 코드 등). 임의 VCP 입력으로 접근.
    public static func otherCodes(in capabilities: DDCCapabilities) -> [UInt8] {
        let known = Set(catalog.map(\.code)).union(handledElsewhere)
        return capabilities.vcpCodes.filter { !known.contains($0) }
    }

    /// 사람이 읽는 요약 행. 명령 출력용.
    public static func describe(_ control: DDCControl) -> String {
        let kind = control.isContinuous ? "조절 막대" : "선택: " + control.options.map { "\($0.name)(\(String(format: "%02X", $0.value)))" }.joined(separator: ", ")
        return "\(control.codeLabel) \(control.title): \(kind)" + (control.isDisruptive ? " [화면 출력이 끊길 수 있음]" : "")
    }
}
