#!/bin/bash
# 전체 테스트 실행. 실제 디스플레이 상태를 읽고 바꾸는 통합 테스트가 서로 영향을 주지 않도록 직렬 실행.
# 로그는 logs/ 아래에 저장.
set -uo pipefail
cd "$(dirname "$0")/.."
mkdir -p logs
LOG="logs/test_$(date +%Y%m%d-%H%M%S).log"
swift build 2>&1 | tail -1
swift test --no-parallel 2>&1 | tee "$LOG" | grep -E 'error:|✘|recorded an issue|skipped|Test run with'
echo "로그: $LOG"
