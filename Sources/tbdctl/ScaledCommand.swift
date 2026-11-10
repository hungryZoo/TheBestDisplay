import Foundation
import TBDCore
import TBDPlatform

struct ScaledOutput: Encodable {
    struct Entry: Encodable {
        var width: Int
        var height: Int
        var flags: Int?
        var label: String
    }

    var display: DisplayIdentity
    var path: String
    var fileExists: Bool
    var entries: [Entry]
}

/// `tbdctl scaled <디스플레이> [list]`
/// `tbdctl scaled <디스플레이> add <폭>x<높이>`
/// `tbdctl scaled <디스플레이> remove <폭>x<높이>`
/// (PRD-MOD-007)
func runScaled(_ command: ParsedCommand, json: Bool) {
    let (display, _) = resolveDisplay(command.positionals[0])
    let action = command.positionals.count > 1 ? command.positionals[1].lowercased() : "list"
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

    switch action {
    case "list":
        let exists = FileManager.default.fileExists(atPath: url.path)
        if json {
            printJSON(ScaledOutput(display: id, path: url.path, fileExists: exists, entries: file.entries.map { .init(width: $0.width, height: $0.height, flags: $0.flags, label: $0.label) }))
            return
        }
        print("\(id.name) [id:\(display.id)] 오버라이드 파일: \(url.path) (\(exists ? "있음" : "없음"))")
        if file.entries.isEmpty { print("  등록된 스케일 해상도 없음") }
        for entry in file.entries { print("  \(entry.label)") }

    case "add", "remove":
        guard command.positionals.count > 2, let size = DisplayOverrideFile.parseSize(command.positionals[2]) else {
            writeError("오류: 해상도 형식은 <폭>x<높이> (HiDPI 논리 해상도)")
            exit(.usage)
        }
        do {
            if action == "add" {
                try file.add(logicalWidth: size.width, logicalHeight: size.height)
            } else {
                try file.remove(logicalWidth: size.width, logicalHeight: size.height)
            }
        } catch {
            writeError("오류: \(RevertCoordinator.describe(error))")
            exit(.unsupported)
        }
        do {
            try service.write(file)
            print("\(action == "add" ? "추가" : "삭제") 완료: \(size.width) x \(size.height) HiDPI. 디스플레이 재연결 또는 재시동 후 모드 목록에 반영")
        } catch DisplayOverrideService.ServiceError.needsPrivilege(_, let commands) {
            writeError("관리자 권한 필요. 다음 명령을 차례로 실행한 뒤 디스플레이 재연결 또는 재시동:")
            for line in commands { writeError("  sudo \(line)") }
            exit(.failure)
        } catch {
            writeError("오류: \(RevertCoordinator.describe(error))")
            exit(.failure)
        }

    default:
        writeError("오류: 동작은 list, add, remove 중 하나")
        exit(.usage)
    }
}
