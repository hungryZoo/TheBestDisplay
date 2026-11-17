import Foundation
import TBDCore
import TBDPlatform

struct OverrideOutput: Encodable {
    var display: DisplayIdentity
    var path: String
    var fileExists: Bool
    var productName: String?
    var defaultResolutionWidth: Int?
    var defaultResolutionHeight: Int?
    var isTV: Bool?
}

/// `tbdctl override <디스플레이> [show]`
/// `tbdctl override <디스플레이> name <이름|reset>`
/// `tbdctl override <디스플레이> default <폭>x<높이|reset>`
/// `tbdctl override <디스플레이> tv <on|off|reset>`
/// 오버라이드 파일의 이름, 기본 해상도, TV 역할 키. 저장에 관리자 권한 필요, 디스플레이 재연결 또는 `tbdctl reinit` 뒤 반영. (PRD-MOD-016)
func runOverride(_ command: ParsedCommand, json: Bool) {
    let (display, _) = resolveDisplay(command.positionals[0])
    let action = command.positionals.count > 1 ? command.positionals[1].lowercased() : "show"
    let service = DisplayOverrideService()
    let id = display.identity
    let url = service.url(vendorID: id.vendorID, productID: id.productID)
    var file: DisplayOverrideFile
    do {
        file = try service.read(vendorID: id.vendorID, productID: id.productID)
    } catch {
        writeError("오류: \(RevertCoordinator.describe(error))")
        exit(.failure)
    }

    func show() {
        let exists = FileManager.default.fileExists(atPath: url.path)
        if json {
            printJSON(OverrideOutput(display: id, path: url.path, fileExists: exists, productName: file.productName, defaultResolutionWidth: file.defaultResolution?.width, defaultResolutionHeight: file.defaultResolution?.height, isTV: file.isTV))
            return
        }
        print("\(id.name) [id:\(display.id)] 오버라이드 파일: \(url.path) (\(exists ? "있음" : "없음"))")
        for line in file.keySummary { print("  \(line)") }
    }

    guard action != "show" else {
        show()
        return
    }
    guard command.positionals.count > 2 else {
        writeError("오류: 값 필요. 사용: override <디스플레이> name <이름|reset> | default <폭>x<높이|reset> | tv <on|off|reset>")
        exit(.usage)
    }
    let value = command.positionals[2]
    let reset = value.lowercased() == "reset"
    do {
        switch action {
        case "name":
            try file.setProductName(reset ? nil : value)
        case "default":
            if reset {
                file.defaultResolution = nil
            } else {
                guard let size = DisplayOverrideFile.parseSize(value) else {
                    writeError("오류: 해상도 형식은 <폭>x<높이> (논리 해상도)")
                    exit(.usage)
                }
                try file.setDefaultResolution(width: size.width, height: size.height)
                // 모드 목록에 없는 해상도는 기본 모드로 선택되지 않으므로 알림.
                if !ModeService.modes(for: display.id).contains(where: { $0.width == size.width && $0.height == size.height }) {
                    writeError("주의: 현재 모드 목록에 논리 해상도 \(size.width) x \(size.height) 없음")
                }
            }
        case "tv":
            switch value.lowercased() {
            case "on": file.isTV = true
            case "off": file.isTV = false
            case "reset": file.isTV = nil
            default:
                writeError("오류: tv 값은 on, off, reset 중 하나")
                exit(.usage)
            }
        default:
            writeError("오류: 두 번째 인자는 show, name, default, tv 중 하나")
            exit(.usage)
        }
    } catch {
        writeError("오류: \(RevertCoordinator.describe(error))")
        exit(.usage)
    }
    do {
        try service.write(file)
        print("저장 완료. 디스플레이 재연결 또는 `tbdctl reinit` 뒤 반영")
        for line in file.keySummary { print("  \(line)") }
    } catch DisplayOverrideService.ServiceError.needsPrivilege(_, let commands) {
        writeError("관리자 권한 필요. 다음 명령을 차례로 실행한 뒤 디스플레이 재연결 또는 `tbdctl reinit`:")
        for line in commands { writeError("  sudo \(line)") }
        exit(.failure)
    } catch {
        writeError("오류: \(RevertCoordinator.describe(error))")
        exit(.failure)
    }
}
