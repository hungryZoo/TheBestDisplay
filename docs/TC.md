# TC: TheBestDisplay 테스트 문서

- 상위 문서: `docs/PRD.md`, `docs/SRS.md`
- 유형: 단위(`swift test`, 하드웨어 불필요), 통합(실제 디스플레이가 연결된 기기에서 `tbdctl` 또는 테스트 실행), 수동(창 조작)
- 결과 표기: 미실행, 통과, 실패, 보류(검증 장비 없음). 실행하지 않은 테스트의 통과 기록 금지
- 기준 구성: MacBook Pro (Apple M5), macOS 26, 내장 디스플레이 + LG TV SSCR2 (USB-C, Thunderbolt 독 경유)
- 픽스처: `Tests/TBDCoreTests/Fixtures/` (실험 기기에서 수집한 EDID, 프레임버퍼 속성, 링크 데이터, 포트 상태)

## 1. 테스트 표

| ID | 목적 | 관련 ID | 사전 조건 | 절차 및 입력 | 기대 결과 | 유형 | 플랫폼 | 결과 | 이슈 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| TC-APP-001 | 창 앱 실행과 종료 확인 | PRD-APP-001, SRS-ARC-001, SRS-ARC-003, SRS-UI-002 | 앱 번들 빌드 완료 | `scripts/build_app.sh` 실행 후 앱 실행, 메뉴 막대 확인, 창 닫기 | 창 1개 표시, 메뉴 막대 상태 항목 없음, 창 닫기 후 프로세스 종료 | 수동 | macOS 26, Apple Silicon | 미실행 | |
| TC-APP-002 | 사이드바와 탭 구성 확인 | PRD-APP-002, PRD-APP-003, SRS-UI-001 | 디스플레이 2대 온라인 | 앱 실행 후 사이드바 항목과 디스플레이별 탭 확인 | 디스플레이 2대, 연결 진단, 프로파일 항목 표시. 탭 7종 표시 | 수동 | macOS 26, Apple Silicon | 미실행 | |
| TC-APP-003 | 구성 변경 자동 갱신 확인 | PRD-APP-004, SRS-ARC-004 | 앱 실행 중 | 시스템 설정에서 해상도 변경 | 1초 이내 앱 표시값 갱신 | 수동 | macOS 26, Apple Silicon | 미실행 | |
| TC-APP-004 | 누락 심볼 처리 확인 | PRD-APP-005, SRS-ARC-002 | 없음 | 존재하지 않는 심볼 이름으로 조회, 존재하는 심볼 이름으로 조회 | 누락 심볼은 nil과 미가용 판정, 존재 심볼은 가용 판정. 충돌 없음 | 단위 | macOS 26, Apple Silicon | 미실행 | |
| TC-INF-001 | 디스플레이 식별 정보 확인 | PRD-INF-001, SRS-INF-001 | 디스플레이 2대 온라인 | `tbdctl list --json` 결과를 `system_profiler SPDisplaysDataType`와 비교 | 디스플레이 수, 이름, 내장 여부, 해상도 일치 | 통합 | macOS 26, Apple Silicon | 미실행 | |
| TC-INF-002 | EDID 기본 블록 해석 확인 | PRD-INF-002, SRS-INF-002 | LG TV EDID 픽스처 | 픽스처 384바이트 해석 | 제조사 GSM, 제품 코드 49352, 제조 연도 2021, 제품명 LG TV SSCR2, 상세 타이밍 3840x2160 포함 | 단위 | macOS 26, Apple Silicon | 미실행 | |
| TC-INF-003 | EDID 확장 블록과 싱크 능력 해석 확인 | PRD-INF-002, PRD-INF-004, SRS-INF-002 | LG TV EDID 픽스처 | CTA-861 확장과 DisplayID 확장 해석 | HDR 정적 메타데이터(PQ, HLG), BT.2020 색 공간, HDMI VSDB, HF-VSDB 항목 추출. 주사율 범위 24-120 Hz | 단위 | macOS 26, Apple Silicon | 미실행 | |
| TC-INF-004 | 손상 EDID 내성 확인 | SRS-INF-002 | 없음 | 빈 입력, 127바이트, 체크섬 오류, 확장 블록 길이 초과, 무작위 바이트 1,000건 | 충돌 없음. 오류 목록과 부분 결과 반환 | 단위 | macOS 26, Apple Silicon | 미실행 | |
| TC-INF-005 | EDID 원본 획득과 저장 확인 | PRD-INF-003, SRS-INF-003 | 외장 디스플레이 온라인 | `tbdctl info <외장> --edid-out <경로>` | 파일 크기 128의 배수, 머리 8바이트가 `00 ff ff ff ff ff ff 00` | 통합 | macOS 26, Apple Silicon | 미실행 | |
| TC-MOD-001 | 전체 모드 열거 확인 | PRD-MOD-001, PRD-MOD-004, SRS-MOD-001 | 디스플레이 온라인 | `tbdctl modes <디스플레이> --json` | 모드 수가 공개 API 열거 수 이상. 현재 모드 1개 표시. 현재 모드 해상도와 주사율이 시스템 설정과 일치 | 통합 | macOS 26, Apple Silicon | 미실행 | |
| TC-MOD-002 | 모드 묶음, 필터, 기본 목록 판정 확인 | PRD-MOD-002, PRD-MOD-006, SRS-MOD-003 | 모드 목록 픽스처 | 해상도별 묶음, HiDPI 필터, 주사율 필터, 기본 목록 대조 | 묶음 수와 필터 결과가 기대값과 일치. 기본 목록 밖 모드에 표시 | 단위 | macOS 26, Apple Silicon | 미실행 | |
| TC-MOD-003 | 모드 전환과 자동 복귀 확인 | PRD-MOD-003, PRD-SAF-001, SRS-MOD-002 | 외장 디스플레이 온라인 | 현재와 다른 해상도 모드로 전환 후 확인 없이 대기. 재전환 후 확인 | 전환 직후 현재 모드 변경. 제한 시간 뒤 원래 모드 복귀. 확인 시 유지 | 통합 | macOS 26, Apple Silicon | 미실행 | |
| TC-MOD-004 | 주사율 단독 전환 확인 | PRD-MOD-005, SRS-MOD-002 | 복수 주사율 지원 디스플레이 | 같은 해상도의 60 Hz 모드로 전환 후 복귀 | 해상도 유지, 주사율만 변경 | 통합 | macOS 26, Apple Silicon | 미실행 | |
| TC-COL-001 | 타이밍 요소와 색 요소 해석 확인 | PRD-COL-002, PRD-COL-005, SRS-COL-001 | 프레임버퍼 속성 픽스처 | 픽스처 해석 | 타이밍 58개, 색 요소 37개. 타이밍 ID 96은 3840x2160, 120 Hz, 색 모드 17개. 색 ID 122는 YCbCr 4:2:2, 12 bpc, PQ, Limited | 단위 | macOS 26, Apple Silicon | 미실행 | |
| TC-COL-002 | 현재 신호 형식 조회 확인 | PRD-COL-001, SRS-COL-002 | 외장 디스플레이 온라인 | `tbdctl signal <외장> --json` 결과를 `ioreg`의 `DPTimingModeId`와 비교 | 타이밍 ID 일치. 인코딩, 비트 심도, 레인지, EOTF가 해당 색 요소 값과 일치 | 통합 | macOS 26, Apple Silicon | 미실행 | |
| TC-COL-003 | 링크 데이터 구조체 해석 확인 | SRS-COL-002 | 링크 데이터 픽스처 (0x110바이트) | 픽스처 해석 | 12 bpc, YCbCr 4:2:2, Limited, PQ, 3840x2160, 총 3968x2250, 120 Hz, 픽셀 클록 1,071,360,000 Hz | 단위 | macOS 26, Apple Silicon | 미실행 | |
| TC-COL-004 | 색 모드 전환과 자동 복귀 확인 | PRD-COL-003, PRD-SAF-001, SRS-COL-003 | 외장 디스플레이 온라인, 색 모드 2개 이상 | 다른 색 모드로 전환 후 확인 없이 대기 | 전환 직후 현재 색 ID 변경. 제한 시간 뒤 원래 색 ID 복귀. API 거부 시 오류 코드 표시 | 통합 | macOS 26, Apple Silicon | 미실행 | |
| TC-COL-005 | DSC 판정 확인 | PRD-COL-004, PRD-LNK-003, SRS-COL-004 | 합성 픽스처 (DSC 지원 색 요소, DSC 필수 목록 포함)와 실측 픽스처 | DSC 판정 실행 | 합성 픽스처는 DSC 필요 모드 식별. 실측 픽스처는 싱크 DSC 미지원 판정 | 단위 | macOS 26, Apple Silicon | 미실행 | |
| TC-HDR-001 | HDR 상태와 정보 조회 확인 | PRD-HDR-001, PRD-HDR-003, SRS-HDR-001 | HDR 지원 외장 디스플레이 온라인 | `tbdctl signal <외장> --json`의 HDR 항목 확인 | 지원 여부와 활성 상태가 시스템 설정과 일치. 지원 EOTF 표시 | 통합 | macOS 26, Apple Silicon | 미실행 | |
| TC-HDR-002 | HDR 전환과 자동 복귀 확인 | PRD-HDR-002, PRD-SAF-001, SRS-HDR-001 | HDR 지원 외장 디스플레이 온라인 | HDR 상태 반전 후 확인 없이 대기 | 전환 직후 상태 변경. 제한 시간 뒤 원래 상태 복귀 | 통합 | macOS 26, Apple Silicon | 미실행 | |
| TC-LNK-001 | 링크 정보 조회 확인 | PRD-LNK-001, SRS-LNK-001 | 외장 디스플레이 온라인 | `tbdctl link <외장> --json` 결과를 `ioreg -r -c IOPortTransportStateDisplayPort`와 비교 | 링크 속도, 레인 수, 터널링, HPD 값 일치 | 통합 | macOS 26, Apple Silicon | 미실행 | |
| TC-LNK-002 | 대역폭 계산 확인 | PRD-LNK-002, SRS-LNK-002 | 없음 | 픽셀 클록 1,071.36 MHz에 대해 YCbCr 4:2:2 12 bpc, RGB 10 bpc, RGB 8 bpc 계산. HBR3 4레인, UHBR10 4레인, FRL 48 Gbps 가용 대역폭 계산 | 25.71, 32.14, 25.71 Gbps. 가용 25.92, 38.79, 42.67 Gbps (소수 둘째 자리 반올림) | 단위 | macOS 26, Apple Silicon | 미실행 | |
| TC-LNK-003 | HDMI 링크 정보 확인 | PRD-LNK-004, SRS-LNK-003 | HDMI 직결 디스플레이 | `tbdctl link <외장> --json` | 전송 방식 HDMI, TMDS 또는 FRL 속도 표시 | 통합 | macOS 26, Apple Silicon | 미실행 | |
| TC-LNK-004 | DPCD 해석과 실패 허용 확인 | PRD-LNK-005, SRS-LNK-004 | DPCD 픽스처 (내장 패널 실측) | 픽스처 해석. 읽기 실패 입력(nil) 처리 | DPCD 1.4, 최대 속도 HBR3, 최대 4레인 해석. nil 입력 시 해당 항목 없음으로 표시하고 충돌 없음 | 단위 | macOS 26, Apple Silicon | 미실행 | |
| TC-PRT-001 | 포트와 케이블 정보 조회 확인 | PRD-PRT-001, PRD-PRT-002, SRS-PRT-001 | 독 경유 외장 디스플레이 온라인 | `tbdctl ports --json` 결과를 `ioreg`와 비교 | USB-C 3개, HDMI 1개, MagSafe 1개. 활성 전송과 독 모델명 일치 | 통합 | macOS 26, Apple Silicon | 미실행 | |
| TC-PRT-002 | 연결 경로 조립 확인 | PRD-PRT-003, SRS-PRT-002 | 스냅샷 픽스처 | 연결 경로 조립 | USB-C 4번 포트, CIO(Parade PS9010), DisplayPort(HBR3, 4레인, 터널링), LG TV SSCR2 순서의 경로 1개 | 단위 | macOS 26, Apple Silicon | 미실행 | |
| TC-DGN-001 | 미출력 진단 규칙 확인 | PRD-DGN-001, PRD-DGN-003, SRS-DGN-001 | 합성 스냅샷 6종 (연결 없음, HPD 없음, EDID 없음, 링크 없음, 프레임버퍼 미할당, 정상) | 진단 실행 | 스냅샷별 첫 실패 단계와 발견 코드가 기대값과 일치. 각 발견 항목에 조치 문구 존재 | 단위 | macOS 26, Apple Silicon | 미실행 | |
| TC-DGN-002 | 모드 제한 진단 확인 | PRD-DGN-002, PRD-DGN-003, SRS-DGN-001 | 실측 스냅샷 픽스처 | 3840x2160 120 Hz에서 RGB 10 bpc 선택 불가 사유 조회 | 대역폭 초과 발견(필요 32.14 Gbps, 가용 25.92 Gbps)과 DSC 미지원 발견 | 단위 | macOS 26, Apple Silicon | 미실행 | |
| TC-DGN-003 | 시스템 제약 점검 확인 | PRD-DGN-006, SRS-DGN-001 | 합성 스냅샷 (외장 디스플레이 수 한도 도달) | 진단 실행 | 한도 도달 발견 항목 생성 | 단위 | macOS 26, Apple Silicon | 미실행 | |
| TC-DGN-004 | 이벤트 기록 확인 | PRD-DGN-004, SRS-DGN-002 | 스냅샷 2개 (모드 변경 전후, 연결 전후) | 스냅샷 차이로 이벤트 생성. 1,001건 추가 | 모드 변경, 연결, 해제 이벤트 생성. 보관 수 1,000건 유지 | 단위 | macOS 26, Apple Silicon | 미실행 | |
| TC-DGN-005 | 진단 보고서 내보내기 확인 | PRD-DGN-005, SRS-DGN-003 | 스냅샷 픽스처 | JSON과 텍스트 직렬화. 일련번호 가림 옵션 적용. `tbdctl report <경로>` 실행 | JSON 재해석 가능. 가림 적용 시 일련번호 미포함. 파일 생성 | 단위 | macOS 26, Apple Silicon | 미실행 | |
| TC-BRT-001 | 내장 디스플레이 밝기 제어 확인 | PRD-BRT-001, SRS-BRT-001 | 내장 디스플레이 온라인 | 밝기 조회, 0.1 낮춰 설정, 재조회, 원래 값 복원 | 재조회 값이 설정값과 0.02 이내 일치. 복원 완료 | 통합 | macOS 26, Apple Silicon | 미실행 | |
| TC-BRT-002 | 전달 테이블 합성과 소프트웨어 디밍 확인 | PRD-BRT-003, PRD-CLR-002, SRS-CLR-001 | 없음 | 디밍 0.5, 색온도, 게인, 대비, 감마 조합으로 테이블 합성. 항등 설정 합성 | 항등 설정은 선형 테이블. 디밍 0.5는 최댓값 0.5. 단조 증가 유지. 값 범위 0-1 | 단위 | macOS 26, Apple Silicon | 미실행 | |
| TC-BRT-003 | 자동 밝기 전환 확인 | PRD-BRT-004, SRS-BRT-001 | 내장 디스플레이 온라인 | 자동 밝기 상태 조회, 반전, 재조회, 복원 | 재조회 값이 반전값과 일치. 복원 완료 | 통합 | macOS 26, Apple Silicon | 미실행 | |
| TC-DDC-001 | DDC 패킷 구성과 응답 해석 확인 | PRD-DDC-003, SRS-DDC-001 | 없음 | VCP 0x10 읽기 요청 패킷 생성, 쓰기 패킷 생성, 정상 응답과 체크섬 오류 응답 해석 | 요청 바이트열과 체크섬이 기대값과 일치. 정상 응답에서 현재값과 최댓값 추출. 오류 응답 거부 | 단위 | macOS 26, Apple Silicon | 미실행 | |
| TC-DDC-002 | DDC 미응답 탐지 확인 | PRD-DDC-001, SRS-DDC-001 | DDC 미응답 디스플레이 (LG TV) 온라인 | `tbdctl ddc <외장> probe` | 미응답 판정과 사유 문구 출력. 종료 코드 3 | 통합 | macOS 26, Apple Silicon | 미실행 | |
| TC-DDC-003 | DDC 제어 확인 | PRD-DDC-002, PRD-BRT-002, SRS-DDC-001 | DDC 지원 모니터 온라인 | 밝기, 대비, 볼륨 읽기와 쓰기 후 복원 | 재조회 값이 설정값과 일치 | 통합 | macOS 26, Apple Silicon | 미실행 | |
| TC-CLR-001 | 색 프로파일 열거와 지정 확인 | PRD-CLR-001, SRS-CLR-002 | 디스플레이 온라인 | 프로파일 목록 조회, 다른 프로파일 지정, 재조회, 복원 | 목록 1개 이상. 재조회 값이 지정값과 일치. 복원 완료 | 통합 | macOS 26, Apple Silicon | 미실행 | |
| TC-CLR-002 | Night Shift와 True Tone 제어 확인 | PRD-CLR-003, PRD-CLR-004, SRS-CLR-003 | 내장 디스플레이 온라인 | 각 상태 조회, 반전, 재조회, 복원 | 재조회 값이 반전값과 일치. 복원 완료 | 통합 | macOS 26, Apple Silicon | 미실행 | |
| TC-ARR-001 | 회전 확인 | PRD-ARR-001, SRS-ARR-002 | 회전 지원 외장 디스플레이 온라인 | 90도 회전 후 확인 없이 대기 | 회전 직후 `CGDisplayRotation` 값 90. 제한 시간 뒤 0 복귀 | 통합 | macOS 26, Apple Silicon | 미실행 | |
| TC-ARR-002 | 미러링 확인 | PRD-ARR-002, SRS-ARR-001 | 디스플레이 2대 온라인 | 미러 설정 후 확인 없이 대기 | 설정 직후 `CGDisplayIsInMirrorSet` 참. 제한 시간 뒤 해제 | 통합 | macOS 26, Apple Silicon | 미실행 | |
| TC-ARR-003 | 메인 지정과 위치 편집 확인 | PRD-ARR-003, PRD-ARR-004, SRS-ARR-001 | 디스플레이 2대 온라인 | 메인 디스플레이 교체, 원점 좌표 변경, 복원 | 교체 후 `CGMainDisplayID` 변경. 좌표 조회값이 입력값과 일치. 복원 완료 | 통합 | macOS 26, Apple Silicon | 미실행 | |
| TC-ARR-004 | 연결 해제, 재연결, 보호 확인 | PRD-ARR-005, PRD-SAF-003, SRS-ARR-003 | 디스플레이 2대 온라인 | 외장 디스플레이 연결 해제, 남은 1대 해제 시도, 재연결 | 해제 후 온라인 목록 1대. 마지막 1대 해제 거부. 재연결 후 2대 | 통합 | macOS 26, Apple Silicon | 미실행 | |
| TC-ARR-005 | 언더스캔 확인 | PRD-ARR-006, SRS-ARR-004 | 언더스캔 지원 디스플레이 온라인 | 언더스캔 값 조회, 변경, 재조회, 복원 | 재조회 값이 설정값과 일치. 미지원 디스플레이는 비활성 표시 | 통합 | macOS 26, Apple Silicon | 미실행 | |
| TC-VRT-001 | 가상 디스플레이 생성, 삭제, 복원 확인 | PRD-VRT-001, PRD-VRT-003, SRS-VRT-001 | 없음 | 1920x1080 HiDPI 가상 디스플레이 생성, 온라인 목록 확인, 삭제, 구성 저장 후 재실행 | 생성 후 온라인 목록 1대 증가. 삭제 후 원복. 재실행 시 저장 구성 복원 | 통합 | macOS 26, Apple Silicon | 미실행 | |
| TC-VRT-002 | HiDPI 스케일링 확인 | PRD-VRT-002, SRS-VRT-002 | 외장 디스플레이 온라인 | 논리 해상도 2560x1440 HiDPI 스케일링 적용, 해제 | 적용 후 외장 디스플레이가 가상 디스플레이의 미러. 해제 후 미러 없음과 가상 디스플레이 삭제 | 통합 | macOS 26, Apple Silicon | 미실행 | |
| TC-PRF-001 | 프로파일 직렬화와 디스플레이 대응 확인 | PRD-PRF-001, PRD-PRF-003, SRS-PRF-001 | 없음 | 프로파일 JSON 왕복 변환. UUID 일치, UUID 불일치와 제품 정보 일치, 전부 불일치 3종 대응 | 왕복 후 동일. 대응 결과가 UUID 우선 규칙과 일치 | 단위 | macOS 26, Apple Silicon | 미실행 | |
| TC-PRF-002 | 프로파일 적용 확인 | PRD-PRF-002, SRS-PRF-002 | 디스플레이 2대 온라인, 저장 프로파일 1개 | 구성 변경 후 프로파일 적용 | 저장 시점 구성 복원. 항목별 결과 표시 | 통합 | macOS 26, Apple Silicon | 미실행 | |
| TC-SAF-001 | 자동 복귀 상태 기계 확인 | PRD-SAF-001, SRS-SAF-001 | 없음 | 가짜 시계와 가짜 적용기로 PRD 3절 전이 9종 실행. 확인 대기 중 새 요청 | 전이 결과가 표와 일치. 타이머 만료 시 복귀 1회 호출. 새 요청 거부 | 단위 | macOS 26, Apple Silicon | 미실행 | |
| TC-SAF-002 | 복귀 정보 파일 확인 | PRD-SAF-002, SRS-SAF-002 | 임시 폴더 | 기록, 조회, 삭제. 손상 파일 조회 | 기록 후 조회값 동일. 삭제 후 없음. 손상 파일은 없음으로 처리 | 단위 | macOS 26, Apple Silicon | 미실행 | |
| TC-CLI-001 | 조회 명령 확인 | PRD-CLI-001, SRS-CLI-001 | 디스플레이 온라인 | `list`, `info`, `modes`, `signal`, `link`, `ports`, `diagnose`를 `--json`으로 실행 | 전 명령 종료 코드 0. 출력이 유효한 JSON | 통합 | macOS 26, Apple Silicon | 미실행 | |
| TC-CLI-002 | 설정 명령 확인 | PRD-CLI-002, SRS-CLI-001 | 외장 디스플레이 온라인 | `set-mode`, `set-color`, `hdr`, `brightness`로 변경 후 복원 | 변경 후 조회값이 설정값과 일치. 복원 완료 | 통합 | macOS 26, Apple Silicon | 미실행 | |
| TC-CLI-003 | 인자 해석과 종료 코드 확인 | PRD-CLI-003, SRS-CLI-001 | 없음 | 알 수 없는 명령, 인자 누락, 없는 디스플레이 지정, 정상 명령 해석 | 사용법 오류 2, 대상 없음 3, 정상 해석 결과 일치 | 단위 | macOS 26, Apple Silicon | 미실행 | |

## 2. 선행 검증 대응 표

- 선행 실험(`docs/research/spikes.md`)은 기술 가정 확인용이며 아래 TC의 통과 근거로 쓰지 않음

| 실험 | 확인한 가정 | 대응 TC |
| --- | --- | --- |
| S1, S1-2 | 전체 모드 열거, VRR과 ProMotion 판정 | TC-MOD-001 |
| S2 | HDR 상태 조회 | TC-HDR-001 |
| S3 | IORegistry 링크 정보 조회 | TC-LNK-001 |
| S4 | 현재 타이밍 ID와 색 ID 조회 | TC-COL-002 |
| S5 | IOAVService EDID 획득, DDC 미응답 | TC-INF-005, TC-DDC-002 |
| S6 | 밝기 조회 | TC-BRT-001 |
| S7 | 가상 디스플레이 클래스 존재 | TC-VRT-001 |
| L1 | 링크 데이터 구조체 오프셋 | TC-COL-003 |
| L2 | DPCD 읽기와 터널링 경로 실패 | TC-LNK-004 |

## 3. 검증 장비 의존 TC

| 필요 장비 | 대상 TC | 실험 기기 보유 |
| --- | --- | --- |
| HDMI 직결 디스플레이 | TC-LNK-003 | 케이블 변경 시 가능 (사용자 참여) |
| DDC 지원 모니터 | TC-DDC-003 | 없음 |
| 언더스캔 지원 디스플레이 | TC-ARR-005 | 미확인 |
