# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
# TC 문서의 결과 열 갱신. 실행한 테스트만 기록.
# 실행: uv run scripts/tc_result.py TC-APP-001=통과 TC-APP-003=미실행:사유

# %% 인자와 문서 로드
import re
import sys
from pathlib import Path

path = Path(__file__).resolve().parent.parent / "docs" / "TC.md"
updates = {}
for arg in sys.argv[1:]:
    tc_id, _, value = arg.partition("=")
    result, _, issue = value.partition(":")
    updates[tc_id] = (result, issue)

# %% 표 행 갱신 (열: ID, 목적, 관련 ID, 사전 조건, 절차, 기대 결과, 유형, 플랫폼, 결과, 이슈)
split = re.compile(r"(?<!\\)\|")
lines = path.read_text(encoding="utf-8").splitlines()
done = set()
for i, line in enumerate(lines):
    cells = split.split(line)
    if len(cells) != 12:
        continue
    tc_id = cells[1].strip()
    if tc_id in updates:
        result, issue = updates[tc_id]
        cells[9] = f" {result} "
        cells[10] = f" {issue} " if issue else " "
        lines[i] = "|".join(cells)
        done.add(tc_id)
path.write_text("\n".join(lines) + "\n", encoding="utf-8")

# %% 결과 출력
missing = sorted(set(updates) - done)
print(f"갱신 {len(done)}건" + (f", 미발견 {missing}" if missing else ""))
sys.exit(1 if missing else 0)
