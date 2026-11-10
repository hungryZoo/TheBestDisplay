import Foundation
import TBDCore
import TBDPlatform

/// 명령행용 타이머: 만료 동작을 보관하고 호출자가 제한 시간 뒤 직접 실행.
final class ManualTimer: RevertTimer {
    private(set) var onFire: (() -> Void)?
    func start(seconds: TimeInterval, onFire: @escaping () -> Void) { self.onFire = onFire }
    func stop() { onFire = nil }
    func fire() {
        let action = onFire
        onFire = nil
        action?()
    }
}

/// 표준 입력에서 한 줄이 들어올 때까지 최대 `seconds`초 대기. 줄 입력이 있으면 참.
/// 표준 입력이 닫혀 있으면(EOF) 남은 시간을 기다린 뒤 거짓.
func waitForReturn(seconds: TimeInterval) -> Bool {
    let deadline = Date().addingTimeInterval(seconds)
    var descriptor = pollfd(fd: STDIN_FILENO, events: Int16(POLLIN), revents: 0)
    while true {
        let remaining = deadline.timeIntervalSinceNow
        if remaining <= 0 { return false }
        let ready = poll(&descriptor, 1, Int32(min(remaining, 0.5) * 1000))
        if ready > 0 {
            var byte: UInt8 = 0
            let count = read(STDIN_FILENO, &byte, 1)
            if count == 1 {
                if byte == 0x0A { return true }
            } else {
                // EOF 또는 오류: 확인 없음으로 처리하고 제한 시간까지 대기.
                Thread.sleep(forTimeInterval: max(0, deadline.timeIntervalSinceNow))
                return false
            }
        }
    }
}

/// 자동 복귀 안전장치를 거쳐 화면 변경 수행. (PRD-SAF-001)
/// `assumeYes`이면 확인 대기 없이 즉시 확정.
func performGuardedChange(_ change: RevertCoordinator.Change, timeout: TimeInterval, assumeYes: Bool) {
    if assumeYes {
        do {
            try change.apply()
            try change.commit()
            print("적용 완료: \(change.summary)")
        } catch {
            writeError("오류: \(RevertCoordinatorDescribe(error))")
            exit(.failure)
        }
        return
    }

    let timer = ManualTimer()
    let coordinator = RevertCoordinator(timeout: timeout, timer: timer, store: .standard)
    var outcome: ExitCode = .success
    coordinator.onNotice = { notice in
        switch notice {
        case .awaitingConfirmation(let summary, let timeout):
            print("적용됨: \(summary)")
            print("유지하려면 Return 입력. \(Int(timeout))초 안에 입력이 없으면 이전 설정으로 복귀.")
        case .committed(let summary):
            print("확정: \(summary)")
        case .reverted(let summary):
            print("복귀 완료: \(summary) 취소")
        case .applyFailed(_, let message):
            writeError("오류: 적용 실패: \(message)")
            outcome = .failure
        case .revertFailed(_, let message):
            writeError("오류: 복귀 실패: \(message)")
            outcome = .failure
        case .commitFailed(_, let message):
            writeError("오류: 확정 실패: \(message)")
            outcome = .failure
        case .rejectedBusy, .targetDisconnected:
            break
        }
    }
    coordinator.request(change)
    if coordinator.state == .awaitingConfirmation {
        if waitForReturn(seconds: timeout) {
            coordinator.confirm()
        } else {
            timer.fire()
        }
    }
    if outcome != .success { exit(outcome) }
}

func RevertCoordinatorDescribe(_ error: Error) -> String {
    (error as? LocalizedError)?.errorDescription ?? String(describing: error)
}

/// `--timeout` 옵션 해석. 기본 15초, 허용 범위 1-120초.
func timeoutOption(_ command: ParsedCommand) -> TimeInterval {
    guard let text = command.options["--timeout"] else { return 15 }
    guard let value = Double(text), (1...120).contains(value) else {
        writeError("오류: --timeout 값은 1-120 범위의 초")
        exit(.usage)
    }
    return value
}
