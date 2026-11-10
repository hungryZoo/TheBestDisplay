import Foundation
import TBDCore
import TBDPlatform

/// `tbdctl favorites <디스플레이> [list | add <모드> | remove <모드>] [--json]` (PRD-MOD-010)
/// 모드를 생략한 add는 현재 모드를 등록. 전환은 `tbdctl set-mode`에 목록의 표기를 그대로 사용.
func runFavorites(_ command: ParsedCommand, json: Bool) {
    let (display, _) = resolveDisplay(command.positionals[0])
    let action = command.positionals.count > 1 ? command.positionals[1].lowercased() : "list"
    let store = ModeFavoritesStore.standard
    let modes = ModeService.modes(for: display.id)
    let current = ModeService.currentMode(for: display.id, in: modes)

    func spec(_ d: ModeDescriptor) -> String {
        "\(d.width)x\(d.height)@\(DisplaySummary.formatHz(d.refreshRate)):\(d.isHiDPI ? "hidpi" : "lodpi")"
    }

    switch action {
    case "list":
        let favorites = store.favorites(for: display.identity)
        if json {
            struct Item: Encodable { var mode: ModeDescriptor; var spec: String; var available: Bool; var isCurrent: Bool }
            printJSON(favorites.map { Item(mode: $0, spec: spec($0), available: $0.find(in: modes) != nil, isCurrent: $0.find(in: modes)?.modeNumber == current?.modeNumber) })
            return
        }
        print("\(display.identity.name) [id:\(display.id)] 즐겨찾기 모드 \(favorites.count)개")
        for favorite in favorites {
            let match = favorite.find(in: modes)
            let tag = match == nil ? "  [현재 목록에 없음]" : match?.modeNumber == current?.modeNumber ? "  [현재]" : ""
            print("  \(spec(favorite))\(tag)")
        }
    case "add", "remove":
        let target: DisplayMode
        if command.positionals.count > 2 {
            guard let parsed = ModeSpec.parse(command.positionals[2]) else {
                writeError("오류: 모드 형식은 <폭>x<높이>[@<주사율>][:hidpi|:lodpi] 또는 mode:<번호>")
                exit(.usage)
            }
            do {
                target = try parsed.resolve(in: modes, current: current)
            } catch {
                writeError("오류: 일치하는 모드 없음: \(command.positionals[2])")
                exit(.unsupported)
            }
        } else if let current {
            target = current
        } else {
            writeError("오류: 현재 모드를 확인할 수 없음")
            exit(.unsupported)
        }
        do {
            let changed = action == "add" ? try store.add(target.descriptor, for: display.identity) : try store.remove(target.descriptor, for: display.identity)
            print(changed ? "\(action == "add" ? "즐겨찾기 추가" : "즐겨찾기 삭제"): \(spec(target.descriptor))" : (action == "add" ? "이미 즐겨찾기에 있음" : "즐겨찾기에 없음") + ": \(spec(target.descriptor))")
        } catch {
            writeError("오류: \(RevertCoordinator.describe(error))")
            exit(.failure)
        }
    default:
        writeError("오류: 동작은 list, add, remove 중 하나")
        exit(.usage)
    }
}
