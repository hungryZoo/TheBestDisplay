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

    case "ladder":
        // 다단계 스케일 해상도 일괄 등록. 단계 수 기본 5.
        let steps = command.positionals.count > 2 ? Int(command.positionals[2]) ?? 0 : 5
        guard (2...12).contains(steps) else {
            writeError("오류: 단계 수는 2-12")
            exit(.usage)
        }
        let modes = ModeService.modes(for: display.id)
        guard let native = ModeCatalog.nativeModes(modes, nativeWidth: display.pixelWidth, nativeHeight: display.pixelHeight).first else {
            writeError("오류: 패널 원본 해상도를 확인할 수 없음")
            exit(.unsupported)
        }
        let sizes = DisplayOverrideFile.ladder(nativeWidth: native.pixelWidth, nativeHeight: native.pixelHeight, steps: steps)
        print("패널 \(native.pixelWidth) x \(native.pixelHeight) 기준 \(sizes.count)단계: " + sizes.map { "\($0.width)x\($0.height)" }.joined(separator: ", "))
        let added = file.addLadder(nativeWidth: native.pixelWidth, nativeHeight: native.pixelHeight, steps: steps)
        guard added > 0 else {
            print("추가할 항목 없음 (이미 등록됨)")
            return
        }
        do {
            try service.write(file)
            print("\(added)개 추가 완료. 디스플레이 재연결 또는 재시동 후 모드 목록에 반영")
        } catch DisplayOverrideService.ServiceError.needsPrivilege(_, let commands) {
            writeError("관리자 권한 필요. 다음 명령을 차례로 실행한 뒤 디스플레이 재연결 또는 재시동:")
            for line in commands { writeError("  sudo \(line)") }
            exit(.failure)
        } catch {
            writeError("오류: \(RevertCoordinator.describe(error))")
            exit(.failure)
        }

    case "add", "remove":
        guard command.positionals.count > 2, let size = DisplayOverrideFile.parseSize(command.positionals[2]) else {
            writeError("오류: 해상도 형식은 <폭>x<높이> (HiDPI 논리 해상도)")
            exit(.usage)
        }
        do {
            if action == "add" {
                try file.add(logicalWidth: size.width, logicalHeight: size.height)
                // 백킹 크기(논리 해상도의 2배)가 프레임버퍼 소스 한도를 넘으면 안내. (PRD-MOD-014)
                if let notice = ModeService.framebufferLimits(for: display)?.excessNotice(pixelWidth: size.width * 2, pixelHeight: size.height * 2) {
                    writeError("주의: \(notice)")
                }
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
        writeError("오류: 동작은 list, add, remove, ladder 중 하나")
        exit(.usage)
    }
}
