import Foundation
import TBDCore
import TBDPlatform

/// `tbdctl virtual <폭>x<높이> [--hidpi] [--name <이름>] [--seconds <초>]` (PRD-VRT-001)
/// 가상 디스플레이는 프로세스 수명에 종속이므로 지정 시간(기본 30초) 또는 Return 입력까지 유지한 뒤 삭제.
func runVirtual(_ command: ParsedCommand) {
    guard case .resolution(let width, let height, let rate, _)? = ModeSpec.parse(command.positionals[0]) else {
        writeError("오류: 해상도 형식은 <폭>x<높이>[@<주사율>]")
        exit(.usage)
    }
    var seconds = 30.0
    if let text = command.options["--seconds"] {
        guard let value = Double(text), (1...3600).contains(value) else {
            writeError("오류: --seconds 값은 1-3600 범위의 초")
            exit(.usage)
        }
        seconds = value
    }
    let config = VirtualDisplayConfig(name: command.options["--name"] ?? "tbdctl 가상 디스플레이", width: width, height: height, hiDPI: command.has("--hidpi"), refreshRate: rate ?? 60, hdr: command.has("--hdr"))
    let issues = config.validationIssues()
    guard issues.isEmpty else {
        writeError("오류: \(issues.joined(separator: ", "))")
        exit(.usage)
    }
    do {
        let id = try VirtualDisplayService.shared.create(config)
        print("가상 디스플레이 생성: \(config.name) [id:\(id)] \(config.label)")
        print("\(Int(seconds))초 동안 유지. Return 입력 시 즉시 삭제.")
        _ = waitForReturn(seconds: seconds)
        VirtualDisplayService.shared.destroy(config.id)
        print("가상 디스플레이 삭제")
    } catch {
        writeError("오류: \(RevertCoordinatorDescribe(error))")
        exit(.failure)
    }
}
