import Foundation

/// DDC/CI 패킷 구성과 응답 해석. 전송은 I2C 주소 0x37, 오프셋 0x51 기준. (SRS-DDC-001)
public enum DDCPacket {
    /// 호스트 주소(쓰기)와 디스플레이 주소의 체크섬 초깃값.
    static let hostWriteAddress: UInt8 = 0x6E
    static let sourceAddress: UInt8 = 0x51
    static let replyChecksumSeed: UInt8 = 0x50

    /// VCP 값 읽기 요청. 예: 밝기(0x10)는 `82 01 10 AC`.
    public static func getRequest(_ code: UInt8) -> [UInt8] {
        seal([0x82, 0x01, code])
    }

    /// VCP 값 쓰기 요청.
    public static func setRequest(_ code: UInt8, value: UInt16) -> [UInt8] {
        seal([0x84, 0x03, code, UInt8(value >> 8), UInt8(value & 0xFF)])
    }

    static func seal(_ payload: [UInt8]) -> [UInt8] {
        payload + [payload.reduce(hostWriteAddress ^ sourceAddress) { $0 ^ $1 }]
    }

    public struct Reply: Equatable, Sendable {
        public var code: UInt8
        public var current: UInt16
        public var maximum: UInt16
    }

    public enum ReplyError: Error, Equatable, Sendable {
        case tooShort
        case checksumMismatch
        case notVCPReply
        /// 디스플레이가 해당 VCP 코드를 지원하지 않음.
        case unsupportedCode
    }

    /// 읽기 요청의 응답 11바이트 해석: `6E 88 02 결과 코드 유형 최댓값(2) 현재값(2) 체크섬`.
    public static func parseReply(_ bytes: [UInt8], expecting code: UInt8? = nil) -> Result<Reply, ReplyError> {
        guard bytes.count >= 11 else { return .failure(.tooShort) }
        let checksum = bytes[0..<10].reduce(replyChecksumSeed) { $0 ^ $1 }
        guard checksum == bytes[10] else { return .failure(.checksumMismatch) }
        guard bytes[2] == 0x02 else { return .failure(.notVCPReply) }
        guard bytes[3] == 0x00 else { return .failure(.unsupportedCode) }
        if let code, bytes[4] != code { return .failure(.notVCPReply) }
        return .success(Reply(code: bytes[4], current: UInt16(bytes[8]) << 8 | UInt16(bytes[9]), maximum: UInt16(bytes[6]) << 8 | UInt16(bytes[7])))
    }
}

/// 자주 쓰는 VCP 코드. (PRD-DDC-002)
public enum VCPCode: UInt8, CaseIterable, Codable, Sendable {
    case brightness = 0x10
    case contrast = 0x12
    case inputSource = 0x60
    case volume = 0x62
    case mute = 0x8D
    case powerMode = 0xD6

    public var title: String {
        switch self {
        case .brightness: "밝기"
        case .contrast: "대비"
        case .inputSource: "입력 소스"
        case .volume: "볼륨"
        case .mute: "음소거"
        case .powerMode: "전원 모드"
        }
    }

    /// 연속 값(슬라이더)인지 선택 값인지.
    public var isContinuous: Bool {
        switch self {
        case .brightness, .contrast, .volume: true
        case .inputSource, .mute, .powerMode: false
        }
    }

    /// 선택 값의 이름. MCCS 규격의 표준 값.
    public var options: [(value: UInt16, name: String)] {
        switch self {
        case .inputSource:
            [(0x0F, "DisplayPort 1"), (0x10, "DisplayPort 2"), (0x11, "HDMI 1"), (0x12, "HDMI 2"), (0x1B, "USB-C"), (0x01, "VGA 1"), (0x03, "DVI 1")]
        case .mute:
            [(1, "음소거"), (2, "음소거 해제")]
        case .powerMode:
            [(1, "켜짐"), (4, "대기"), (5, "꺼짐")]
        default:
            []
        }
    }

    public static func parse(_ text: String) -> UInt8? {
        let lower = text.lowercased()
        let names: [String: VCPCode] = ["brightness": .brightness, "contrast": .contrast, "input": .inputSource, "volume": .volume, "mute": .mute, "power": .powerMode]
        if let named = names[lower] { return named.rawValue }
        if lower.hasPrefix("0x") { return UInt8(lower.dropFirst(2), radix: 16) }
        return UInt8(lower)
    }
}

/// 디스플레이의 DDC 지원 판정 결과. (PRD-DDC-001)
public struct DDCProbe: Codable, Hashable, Sendable {
    public enum Status: String, Codable, Sendable {
        case supported
        /// 요청은 전송되었으나 응답 없음.
        case noResponse
        /// 내장 패널 등 DDC 대상이 아님.
        case notApplicable
        /// I2C 통로를 열 수 없음.
        case noChannel
    }

    public var status: Status
    /// 응답한 VCP 코드와 현재값, 최댓값.
    public var values: [UInt8: [UInt16]]

    public init(status: Status, values: [UInt8: [UInt16]] = [:]) {
        self.status = status
        self.values = values
    }

    public var reason: String {
        switch status {
        case .supported: "DDC 응답 확인"
        case .noResponse: "DDC 요청에 응답 없음. TV와 일부 모니터는 DDC/CI를 지원하지 않거나 설정에서 꺼져 있음. 독, 허브, 변환 어댑터가 DDC 신호를 전달하지 않는 경우도 있음"
        case .notApplicable: "내장 디스플레이는 DDC 대상이 아님. 시스템 밝기 제어 사용"
        case .noChannel: "이 디스플레이의 I2C 통로를 찾을 수 없음"
        }
    }
}
