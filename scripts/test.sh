#!/bin/bash
# 전체 테스트 실행. 실제 디스플레이 상태를 읽고 바꾸는 통합 테스트가 서로 영향을 주지 않도록 직렬 실행.
# 로그는 logs/ 아래에 저장. 테스트가 실패하면 0이 아닌 코드로 종료.
set -uo pipefail
cd "$(dirname "$0")/.."
mkdir -p logs

run_tests() {
    LOG="logs/test_$(date +%Y%m%d-%H%M%S).log"
    swift build 2>&1 | tail -1
    swift test --no-parallel > "$LOG" 2>&1
    local status=$?
    grep -E 'error:|✘|recorded an issue|skipped|Test run with|unexpected signal' "$LOG"
    echo "로그: $LOG"
    return $status
}

run_tests
status=$?
# TBDCore의 구조체 배치가 바뀐 뒤 증분 빌드 산출물이 어긋나 테스트 프로세스가 죽는 경우가 있어 (T42, T43 실측)
# 비정상 종료 시 산출물을 정리하고 한 번 더 실행.
if [ $status -ne 0 ] && grep -q 'unexpected signal' "$LOG"; then
    echo "테스트 프로세스 비정상 종료. 빌드 산출물 정리 후 재실행"
    swift package clean
    run_tests
    status=$?
fi
exit $status
