import Foundation

/// 케이블 e-marker의 식별 정보와 신뢰 신호. (PRD-PRT-008)
///
/// e-marker 값은 케이블 제조사가 기록한 자기 신고 값. 여기서는 기록 누락과 값 사이의 불일치만 판정하며,
/// USB-IF 제품 데이터베이스와의 온라인 대조는 수행하지 않음.
public enum CableTrust {
    /// USB 제조사 ID와 이름. 자주 쓰이는 일부만 수록.
    static let vendors: [Int: String] = [
        0x05AC: "Apple", 0x8087: "Intel", 0x050D: "Belkin", 0x291A: "Anker", 0x04E8: "Samsung", 0x18D1: "Google",
        0x045E: "Microsoft", 0x413C: "Dell", 0x03F0: "HP", 0x17EF: "Lenovo", 0x054C: "Sony", 0x0B05: "ASUSTek",
        0x0BDA: "Realtek", 0x2109: "VIA Labs", 0x0451: "Texas Instruments", 0x04B4: "Cypress", 0x1FC9: "NXP",
        0x0483: "STMicroelectronics", 0x046D: "Logitech", 0x2188: "CalDigit",
    ]

    /// 제조사 ID가 기록되지 않은 값인지 (0 또는 0xFFFF).
    public static func hasVendorID(_ cable: CableEMarker) -> Bool {
        cable.vendorID != 0 && cable.vendorID != 0xFFFF
    }

    public static func vendorName(_ vendorID: Int) -> String? { vendors[vendorID] }

    /// 식별 정보 한 줄. 예: "제조사 Apple (0x05AC), 제품 0x7209, USB-IF 인증 ID 12345, 지연 10 ns 미만 (약 1 m)"
    public static func identity(_ cable: CableEMarker) -> String {
        var parts: [String] = []
        if hasVendorID(cable) {
            let hex = String(format: "0x%04X", cable.vendorID)
            parts.append("제조사 " + (vendorName(cable.vendorID).map { "\($0) (\(hex))" } ?? hex))
        } else {
            parts.append("제조사 ID 미기재")
        }
        if cable.productID != 0 { parts.append(String(format: "제품 0x%04X", cable.productID)) }
        parts.append(cable.certificationID != 0 ? "USB-IF 인증 ID \(cable.certificationID)" : "USB-IF 인증 ID 미기재")
        if let latency = cable.latencyName { parts.append("지연 \(latency)") }
        return parts.joined(separator: ", ")
    }

    /// 신뢰 신호: 기록 누락과 값 사이의 불일치. 없으면 빈 배열.
    public static func signals(_ cable: CableEMarker) -> [String] {
        var result: [String] = []
        if !hasVendorID(cable) {
            result.append("제조사 ID가 없어 제조사를 확인할 수 없음")
        }
        if cable.certificationID == 0 {
            result.append("USB-IF 인증 ID가 없어 e-marker로는 인증 여부를 확인할 수 없음")
        }
        if cable.eprCapable, cable.maxVoltage < 50 || cable.currentCode != 2 {
            result.append("EPR 지원 표기와 정격(\(cable.currentName), 최대 \(cable.maxVoltage) V)이 맞지 않음")
        }
        if cable.latencyCode == 0 || cable.latencyCode > 8 {
            result.append("지연 시간 부호(\(cable.latencyCode))가 규격 범위 밖")
        }
        // USB4 Gen 3 이상의 패시브 케이블은 규격의 길이 한도가 약 1 m (지연 10 ns 미만).
        if cable.isPassive, cable.speedCode >= 3, (2...8).contains(cable.latencyCode), let latency = cable.latencyName {
            result.append("패시브 케이블이 \(cable.speedName) 속도와 지연 \(latency)를 함께 표기 (이 속도의 패시브 케이블 길이 한도는 약 1 m)")
        }
        return result
    }
}
