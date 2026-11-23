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
/// 줄 내용이 `revert`이면 기다리지 않고 거짓 (즉시 복귀. MCP 서버의 복귀 요청에 사용).
/// 표준 입력이 닫혀 있으면(EOF) 남은 시간을 기다린 뒤 거짓.
/// 기다리는 동안 `tbdctl resolve`가 남긴 결정 파일도 확인: keep이면 참, revert이면 거짓. (SRS-AGT-003)
func waitForReturn(seconds: TimeInterval) -> Bool {
    let deadline = Date().addingTimeInterval(seconds)
    var descriptor = pollfd(fd: STDIN_FILENO, events: Int16(POLLIN), revents: 0)
    var line: [UInt8] = []
    let decisions = GuardedDecisionStore.standard
    // 이전 실행이 남긴 결정은 이번 변경과 무관.
    decisions.clear()
    var inputClosed = false
    while true {
        let remaining = deadline.timeIntervalSinceNow
        if remaining <= 0 { return false }
        if let decision = decisions.take() { return decision == .keep }
        if inputClosed {
            // 입력이 닫힌 뒤에는 결정 파일만 확인.
            Thread.sleep(forTimeInterval: min(remaining, 0.3))
            continue
        }
        let ready = poll(&descriptor, 1, Int32(min(remaining, 0.5) * 1000))
        if ready > 0 {
            var byte: UInt8 = 0
            let count = read(STDIN_FILENO, &byte, 1)
            if count == 1 {
                if byte == 0x0A {
                    return GuardedInput.keeps(String(decoding: line, as: UTF8.self))
                }
                line.append(byte)
            } else {
                // EOF 또는 오류: 입력으로는 확인을 받을 수 없음. 제한 시간까지 결정 파일을 기다림.
                inputClosed = true
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

/// `tbdctl resolve <keep|revert>` (PRD-AGT-002): 확인을 기다리는 변경을 다른 셸에서 확정하거나 복귀.
/// 변경 명령은 `--timeout`과 함께 백그라운드로 실행해 둔 상태여야 함.
func runResolve(_ command: ParsedCommand) {
    guard let decision = GuardedDecisionStore.Decision(rawValue: command.positionals[0].lowercased()) else {
        writeError("오류: resolve의 인자는 keep 또는 revert")
        exit(.usage)
    }
    let pending = PendingRevertStore.standard
    guard let record = pending.load() else {
        writeError("확인을 기다리는 변경 없음 (제한 시간이 지나 이미 복귀되었을 수 있음)")
        exit(.unsupported)
    }
    do {
        try GuardedDecisionStore.standard.write(decision)
    } catch {
        writeError("오류: 결정 기록 실패: \(error.localizedDescription)")
        exit(.failure)
    }
    // 기다리던 프로세스가 결정을 처리하면 복귀 정보 파일이 사라짐. 재연결을 포함하는 복귀는 15초까지 걸림.
    let deadline = Date().addingTimeInterval(25)
    while Date() < deadline {
        if pending.load() == nil {
            print(decision == .keep ? "유지 확정" : "복귀 완료: \(record.summary)")
            return
        }
        Thread.sleep(forTimeInterval: 0.2)
    }
    GuardedDecisionStore.standard.clear()
    writeError("확인을 기다리는 프로세스가 응답하지 않음. 변경 명령이 이미 끝났다면 `tbdctl revert-pending`으로 복귀하거나 `tbdctl revert-pending --discard`로 현재 설정 유지")
    exit(.failure)
}
