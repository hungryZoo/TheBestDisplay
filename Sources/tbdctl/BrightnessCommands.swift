import Foundation
import TBDCore
import TBDPlatform

struct BrightnessOutput: Encodable {
    var display: DisplayIdentity
    var method: BrightnessMethod
    /// 0-100. 조회 불가 시 nil.
    var percent: Double?
    var autoBrightnessAvailable: Bool
    var autoBrightnessEnabled: Bool?
}

/// `tbdctl brightness <디스플레이> [0-100] [--json]` (PRD-BRT-001, PRD-BRT-002, PRD-CLI-002)
/// 소프트웨어 디밍은 프로세스 수명 동안만 유지되므로 명령행에서는 제공하지 않음.
func runBrightness(_ command: ParsedCommand, json: Bool) {
    let (display, _) = resolveDisplay(command.positionals[0])
    let probe = BrightnessService.supportsNative(display) ? nil : DDCService.probe(for: display)
    let method = BrightnessService.method(for: display, ddc: probe)

    func current() -> Double? {
        switch method {
        case .native: BrightnessService.nativeBrightness(display.id)
        case .ddc: probe?.values[VCPCode.brightness.rawValue].flatMap { $0.count == 2 && $0[1] > 0 ? Double($0[0]) / Double($0[1]) : nil }
        case .software: nil
        }
    }

    guard command.positionals.count > 1 else {
        let value = current()
        if json {
            printJSON(BrightnessOutput(display: display.identity, method: method, percent: value.map { ($0 * 1000).rounded() / 10 }, autoBrightnessAvailable: BrightnessService.hasAutoBrightness(display.id), autoBrightnessEnabled: BrightnessService.autoBrightnessEnabled(display.id)))
            return
        }
        print("\(display.identity.name) [id:\(display.id)] 밝기 제어 방식: \(method.title)")
        if let value {
            print("  밝기: \(String(format: "%.1f", value * 100))%")
        } else {
            print("  밝기: 하드웨어 밝기 값을 읽을 수 없음" + (probe.map { " (\($0.reason))" } ?? ""))
        }
        if BrightnessService.hasAutoBrightness(display.id) {
            print("  자동 밝기: \(BrightnessService.autoBrightnessEnabled(display.id).map { $0 ? "켜짐" : "꺼짐" } ?? "미확인")")
        }
        return
    }

    guard let percent = Double(command.positionals[1]), (0...100).contains(percent) else {
        writeError("오류: 밝기 값은 0-100")
        exit(.usage)
    }
    do {
        switch method {
        case .native:
            try BrightnessService.setNativeBrightness(percent / 100, on: display.id)
        case .ddc:
            let maximum = probe?.values[VCPCode.brightness.rawValue]?.last ?? 100
            try BrightnessService.setDDCBrightness(percent / 100, for: display, maximum: maximum)
        case .software:
            writeError("오류: 이 디스플레이는 하드웨어 밝기 제어 불가. \(probe?.reason ?? ""). 소프트웨어 디밍은 창 앱의 밝기 탭에서 사용")
            exit(.unsupported)
        }
    } catch {
        writeError("오류: \(RevertCoordinatorDescribe(error))")
        exit(.failure)
    }
    print("밝기 \(String(format: "%.0f", percent))% 설정 (\(method.title))")
}

/// `tbdctl ddc <디스플레이> probe | get <코드> | set <코드> <값>` (PRD-DDC-001-003)
/// 코드는 이름(brightness, contrast, volume, mute, input, power) 또는 숫자(0x10).
func runDDC(_ command: ParsedCommand, json: Bool) {
    let (display, _) = resolveDisplay(command.positionals[0])
    let action = command.positionals[1].lowercased()

    if action == "probe" {
        let probe = DDCService.probe(for: display)
        if json {
            printJSON(probe)
        } else {
            print("\(display.identity.name) [id:\(display.id)] DDC: \(probe.reason)")
            for (code, values) in probe.values.sorted(by: { $0.key < $1.key }) where values.count == 2 {
                let name = VCPCode(rawValue: code)?.title ?? "VCP"
                print("  \(name) (0x\(String(format: "%02X", code))): 현재 \(values[0]), 최대 \(values[1])")
            }
        }
        if probe.status != .supported { exit(.unsupported) }
        return
    }

    guard action == "get" || action == "set" else {
        writeError("오류: 두 번째 인자는 probe, get, set 중 하나")
        exit(.usage)
    }
    guard command.positionals.count > 2, let code = VCPCode.parse(command.positionals[2]) else {
        writeError("오류: VCP 코드는 이름(brightness, contrast, volume, mute, input, power) 또는 숫자(예: 0x10)")
        exit(.usage)
    }
    guard !display.identity.isBuiltin, let service = SignalService.avService(for: display) else {
        writeError("오류: \(DDCProbe(status: display.identity.isBuiltin ? .notApplicable : .noChannel).reason)")
        exit(.unsupported)
    }
    if action == "get" {
        guard let reply = DDCService.read(code, service: service) else {
            writeError("오류: 응답 없음 또는 미지원 코드 (0x\(String(format: "%02X", code)))")
            exit(.unsupported)
        }
        if json {
            printJSON(["code": Int(code), "current": Int(reply.current), "maximum": Int(reply.maximum)])
        } else {
            print("VCP 0x\(String(format: "%02X", code)): 현재 \(reply.current), 최대 \(reply.maximum)")
        }
        return
    }
    guard command.positionals.count > 3, let value = UInt16(command.positionals[3]) else {
        writeError("오류: set은 값(0-65535) 필요")
        exit(.usage)
    }
    guard DDCService.write(code, value: value, service: service) else {
        writeError("오류: DDC 쓰기 실패")
        exit(.failure)
    }
    print("VCP 0x\(String(format: "%02X", code)) = \(value) 쓰기 완료")
}
