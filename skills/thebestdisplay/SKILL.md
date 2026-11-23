---
name: thebestdisplay
description: Diagnose and fix monitor problems on a Mac with TheBestDisplay's tbdctl CLI (or its MCP tools) instead of screenshots or computer use - no picture, display not detected, wrong colors or blurry text, flicker, wrong resolution or refresh rate, HDR, cable/dock/port questions, disconnecting or reconnecting a display. Use when the user reports a display, monitor or TV problem on macOS or asks to change display settings (모니터 화면이 안 나옴, 인식 안 됨, 색이 이상함, 깜빡임, 해상도, 주사율, HDR, 연결 해제).
---

# TheBestDisplay로 디스플레이 문제 진단과 조치

화면 캡처와 앱 조작 대신 `tbdctl` 명령의 글자 출력으로 진단. 명령 1회 출력은 0.3-4 KB.

## 1. 실행 경로

```bash
command -v tbdctl || ls /Applications/TheBestDisplay.app/Contents/MacOS/tbdctl
```

- 둘 다 없으면 설치 안내: `brew install hungryZoo/tap/thebestdisplay`
- MCP 도구(`display_diagnose`, `display_query`, `display_change`, `display_change_resolve`, `display_recover`)가 세션에 있으면 같은 절차를 도구로 수행. 아래 명령과 1대1 대응
- 지원 환경: macOS 15 이상, Apple Silicon

## 2. 진단 절차 (3단계)

- (1) 전체 상태: `tbdctl list`, `tbdctl diagnose`. 포트 점검 6단계(물리 연결, HPD, EDID, 링크, 프레임버퍼, 온라인) 중 실패 단계와 발견 항목의 조치 확인
- (2) 증상별 조회: 3절 표의 명령 1-2개만 실행. `help` 탐색 불필요
- (3) 조치: 4절 규칙대로 적용하고 사용자에게 화면 상태를 물은 뒤 확정

## 3. 증상별 조회와 조치

| 증상 | 조회 | 확인할 내용 | 조치 |
| --- | --- | --- | --- |
| 인식 안 됨 | `diagnose`, `ports` | 실패한 점검 단계, 케이블과 독 경로 | `redetect`, `reconnect`, 케이블과 포트 교체 안내 |
| 연결은 되는데 화면 없음 | `diagnose`, `signal <이름>` | 전 단계 통과 여부, 주사율과 비트 심도, 픽셀 클록 | 주사율 낮춤 `set-mode <이름> <폭>x<높이>@60`, 심도 낮춤 `set-color <이름> rgb:8`, `reinit <이름>` |
| 색 이상, 글자 번짐 | `signal <이름>` | YCbCr 4:2:2 또는 4:2:0, Limited 범위, HDR 불일치 | `set-color <이름> rgb` 또는 `rgb:8:full`, `hdr <이름> off` |
| 깜빡임, 끊김 | `link <이름>`, `ports` | 링크 속도와 레인 수, 대역폭 사용률, 케이블 등급 | 주사율 또는 심도 낮춤, 케이블 교체 안내 |
| 해상도, 주사율 | `modes <이름>` | 제공 모드 목록 (HiDPI 포함) | `set-mode <이름> <폭>x<높이>[@<주사율>][:hidpi]` |
| HDR | `hdr <이름>`, `signal <이름>` | 지원 EOTF, 현재 상태 | `hdr <이름> on` 또는 `off` |
| 화면 방향 | `arrangement` | 회전, 배치, 미러 | `rotate <이름> <0, 90, 180, 270>` |
| 화면을 잠시 끄기 | `list` | 온라인 디스플레이 수 | `disconnect <이름>`, 되돌리기 `reconnect <이름>` |
| 기능이 막힘 | `capabilities` | 이 macOS 판에서 가용한 기능 | 5절 제약 안내 |

- 색 모드 형식: `<rgb|ycbcr444|ycbcr422|ycbcr420>[:<bpc>][:<full|limited>][:<sdr|pq|hlg>]`. 생략 항목은 현재 값 유지
- `signal` 출력의 "시스템 제공" 표시가 있는 색 모드만 macOS 27에서 전환 가능
- 원인 추정은 출력의 수치(픽셀 클록, 대역폭 사용률, 링크 속도)를 근거로 제시. 근거가 없으면 추정이라고 밝힘

## 4. 변경 규칙 (필수)

- 대상은 이름으로 지정 (`"LG TV"`, `Legion`). `id:<번호>`와 순번 사용 금지: 재연결 때마다 ID가 바뀜
- 변경 전에 무엇을 바꾸는지 사용자에게 알림. 에이전트는 화면을 볼 수 없으므로 결과는 사용자에게 질문
- `--yes` 사용 금지 (자동 복귀를 건너뜀). 아래 2단계 형태 사용

```bash
tbdctl set-mode "Legion" 1920x1080@60 --timeout 120 < /dev/null > /tmp/tbd-change.log 2>&1 &
```

- 위 명령은 백그라운드로 실행 (적용 뒤 120초 동안 확인 대기, `--timeout` 범위 1-120초). 적용 여부는 `cat /tmp/tbd-change.log`와 `tbdctl signal <이름>`으로 확인
- 사용자에게 화면이 정상인지 질문한 뒤 유지 또는 복귀

```bash
tbdctl resolve keep
```

```bash
tbdctl resolve revert
```

- 답이 없으면 제한 시간 뒤 자동 복귀. 그 뒤의 `resolve`는 "확인을 기다리는 변경 없음"으로 끝남
- 한 번에 변경 1건. 마지막 남은 디스플레이의 연결 해제는 거부됨
- 복구 수단: `tbdctl reconnect` (해제한 디스플레이 전부 재연결), `tbdctl reinit <이름>` (재초기화), `tbdctl revert-pending` (확인 없이 끝난 변경 복귀), 케이블 재연결 안내

## 5. 제약

- macOS 27: 색 모드는 시스템 출력 모드 목록의 형식만 전환 가능하고 색 공간은 시스템이 선택. 타이밍 직접 선택(`set-timing`)과 DSC 전환(`dsc`)은 시스템이 거부
- 관리자 권한이 필요한 명령(`override`, `scaled`의 쓰기)은 실행하지 않고 사용자에게 명령을 안내
- 실험적 값 탐색 금지: 목록(`modes`, `signal`)에 있는 값만 지정
- 그 밖의 명령(밝기, DDC, EDID, 프로파일, 가상 디스플레이)은 `tbdctl help`로 확인. `--json`은 조회 명령에서 사용 가능하나 출력이 길어 필요한 때만 사용
