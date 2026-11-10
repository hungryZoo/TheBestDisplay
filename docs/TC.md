# TC: TheBestDisplay 테스트 문서

- 상위 문서: `docs/PRD.md`, `docs/SRS.md`
- 유형: 단위(`swift test`, 하드웨어 불필요), 통합(실제 디스플레이가 연결된 기기에서 `tbdctl` 또는 테스트 실행), 수동(창 조작)
- 결과 표기: 미실행, 통과, 실패, 보류(검증 장비 없음). 실행하지 않은 테스트의 통과 기록 금지
- 기준 구성: MacBook Pro (Apple M5), macOS 26, 내장 디스플레이 + LG TV SSCR2 (USB-C, Thunderbolt 독 경유)
- 픽스처: `Tests/TBDCoreTests/Fixtures/` (실험 기기에서 수집한 EDID, 프레임버퍼 속성, 링크 데이터, 포트 상태)

## 1. 테스트 표

| ID | 목적 | 관련 ID | 사전 조건 | 절차 및 입력 | 기대 결과 | 유형 | 플랫폼 | 결과 | 이슈 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| TC-APP-001 | 창 앱 실행과 종료 확인 | PRD-APP-001, SRS-ARC-001, SRS-ARC-003, SRS-UI-002 | 앱 번들 빌드 완료 | `scripts/build_app.sh` 실행 후 앱 실행, `scripts/window_probe.swift`로 상태 항목 창 수 확인, 창 닫기 | 창 1개 표시, 메뉴 막대 상태 항목 없음, 창 닫기 후 프로세스 종료 | 수동 | macOS 26, Apple Silicon | 통과 | |
| TC-APP-002 | 사이드바와 탭 구성 확인 | PRD-APP-002, PRD-APP-003, SRS-UI-001 | 디스플레이 2대 온라인 | 앱 실행 후 사이드바 항목과 디스플레이별 탭 확인 | 디스플레이 2대, 연결 진단, 프로파일 항목 표시. 탭 7종 표시 | 수동 | macOS 26, Apple Silicon | 통과 | |
| TC-APP-003 | 구성 변경 자동 갱신 확인 | PRD-APP-004, SRS-ARC-004 | 앱 실행 중 | `tbdctl set-mode`로 주사율 변경. 변경 감지 시각에서 0.9초 뒤 앱 창 캡처 | 캡처 시점에 사이드바와 개요 탭이 새 주사율 표시 | 수동 | macOS 26, Apple Silicon | 통과 | |
| TC-APP-004 | 누락 심볼 처리 확인 | PRD-APP-005, SRS-ARC-002 | 없음 | 존재하지 않는 심볼 이름으로 조회, 존재하는 심볼 이름으로 조회 | 누락 심볼은 nil과 미가용 판정, 존재 심볼은 가용 판정. 충돌 없음 | 단위 | macOS 26, Apple Silicon | 통과 | |
| TC-INF-001 | 디스플레이 식별 정보 확인 | PRD-INF-001, SRS-INF-001 | 디스플레이 2대 온라인 | `swift test`의 TC-INF-001 묶음: `DisplayCatalog` 결과를 `system_profiler SPDisplaysDataType -json`과 비교 | 디스플레이 수, 이름, 내장 여부, 해상도 일치 | 통합 | macOS 26, Apple Silicon | 통과 | |
| TC-INF-002 | EDID 기본 블록 해석 확인 | PRD-INF-002, SRS-INF-002 | LG TV EDID 픽스처 | 픽스처 384바이트 해석 | 제조사 GSM, 제품 코드 49352, 제조 연도 2021, 제품명 LG TV SSCR2, 상세 타이밍 3840x2160 포함 | 단위 | macOS 26, Apple Silicon | 통과 | |
| TC-INF-003 | EDID 확장 블록과 싱크 능력 해석 확인 | PRD-INF-002, PRD-INF-004, SRS-INF-002 | LG TV EDID 픽스처 (DP 경로 수신본, HDMI 제조사 블록 없음), HDMI VSDB와 HF-VSDB를 넣은 합성 CTA 블록 | 픽스처의 CTA-861 확장과 DisplayID 확장 해석. 합성 블록 해석 | 픽스처: VIC 24개, HDR 정적 메타데이터(PQ, HLG), BT.2020 색 공간, YCbCr 4:2:0 가능 VIC 7개, DisplayID 상세 타이밍 3840x2160 120 Hz(픽셀 클록 1,071.36 MHz). 합성: 최대 TMDS 600 MHz, FRL 48 Gbps, VRR 48-120 Hz, DSC 1.2a, 최대 휘도 993.4 cd/m² | 단위 | macOS 26, Apple Silicon | 통과 | |
| TC-INF-004 | 손상 EDID 내성 확인 | SRS-INF-002 | 없음 | 빈 입력, 127바이트, 체크섬 오류, 확장 블록 길이 초과, 무작위 바이트 1,000건 | 충돌 없음. 오류 목록과 부분 결과 반환 | 단위 | macOS 26, Apple Silicon | 통과 | |
| TC-INF-005 | EDID 원본 획득과 저장 확인 | PRD-INF-003, SRS-INF-003 | 외장 디스플레이 온라인 | `swift test`의 TC-INF-005 묶음. `tbdctl info external --edid-out <경로>` 후 픽스처와 `cmp`. 내장 디스플레이에 같은 옵션 지정 | 크기 128의 배수, 머리 8바이트가 `00 ff ff ff ff ff ff 00`, 제조사와 제품 코드가 CoreGraphics 값과 일치. 저장 파일이 픽스처와 동일. 내장 디스플레이는 종료 코드 3 | 통합 | macOS 26, Apple Silicon | 통과 | |
| TC-MOD-001 | 전체 모드 열거 확인 | PRD-MOD-001, PRD-MOD-004, SRS-MOD-001 | 디스플레이 온라인 | `swift test`의 TC-MOD-001 묶음. `tbdctl modes <디스플레이>` | 모드 수가 공개 API 열거 수 이상, 모드 번호 중복 없음. 현재 모드 1개이며 해상도와 주사율이 CoreGraphics 보고값과 일치. 원본 모드 1개 이상 | 통합 | macOS 26, Apple Silicon | 통과 | |
| TC-MOD-002 | 모드 묶음, 필터, 기본 목록 판정 확인 | PRD-MOD-002, PRD-MOD-006, SRS-MOD-003 | 모드 목록 픽스처 | 해상도별 묶음, HiDPI 필터, 주사율 필터, 기본 목록 대조 | 묶음 수와 필터 결과가 기대값과 일치. 기본 목록 밖 모드에 표시 | 단위 | macOS 26, Apple Silicon | 통과 | |
| TC-MOD-003 | 모드 전환과 자동 복귀 확인 | PRD-MOD-003, PRD-SAF-001, SRS-MOD-002 | 외장 디스플레이 온라인. 사용자에게 사전 알림 | `tbdctl set-mode external 1344x756@120:hidpi --timeout 6`(시스템 설정 목록 밖 모드)을 표준 입력 없이 실행. Return 입력으로 확정하는 전환 1회. 창 앱의 해상도 탭에서 전환 후 복귀 선택 | 전환 직후 현재 모드 변경과 복귀 정보 파일 생성. 제한 시간 뒤 원래 모드 복귀와 파일 삭제. 확인 시 유지. 전 과정에서 디스플레이 온라인 유지 | 통합 | macOS 26, Apple Silicon | 통과 | 첫 시도의 SkyLight 경로는 TV 미출력 유발, MonitorPanel 경로로 통과 (ADR-0005) |
| TC-MOD-004 | 주사율 단독 전환 확인 | PRD-MOD-005, SRS-MOD-002 | 복수 주사율 지원 디스플레이. 사용자에게 사전 알림 | `tbdctl set-mode external 2304x1296@60:hidpi --timeout 6`을 표준 입력 없이 실행 | 해상도 유지, 주사율만 60 Hz로 변경. 제한 시간 뒤 120 Hz 복귀 | 통합 | macOS 26, Apple Silicon | 통과 | |
| TC-COL-001 | 타이밍 요소와 색 요소 해석 확인 | PRD-COL-002, PRD-COL-005, SRS-COL-001 | 프레임버퍼 속성 픽스처 | 픽스처 해석 | 타이밍 58개, 색 요소 37개. 타이밍 ID 96은 3840x2160, 120 Hz, 색 모드 17개(가상 형식 제외 15개). 색 ID 122는 YCbCr 4:2:2, 12 bpc, PQ, Limited. RGB는 8 bpc SDR 2개만 선택 가능 | 단위 | macOS 26, Apple Silicon | 통과 | |
| TC-COL-002 | 현재 신호 형식 조회 확인 | PRD-COL-001, SRS-COL-002 | 외장 디스플레이 온라인 | `swift test`의 TC-COL-002 묶음: 신호 조회 결과를 프레임버퍼 노드의 `DPTimingModeId`, 링크 데이터와 비교 | 타이밍 ID 일치. 링크 데이터의 인코딩, 비트 심도, 레인지, EOTF, 타이밍, 픽셀 클록이 현재 색 모드와 타이밍 요소 값에 일치 | 통합 | macOS 26, Apple Silicon | 통과 | |
| TC-COL-003 | 링크 데이터 구조체 해석 확인 | SRS-COL-002 | 링크 데이터 픽스처 (0x110바이트) | 픽스처 해석 | 12 bpc, YCbCr 4:2:2, Limited, PQ, 3840x2160, 총 3968x2250, 120 Hz, 픽셀 클록 1,071,360,000 Hz | 단위 | macOS 26, Apple Silicon | 통과 | |
| TC-COL-004 | 색 모드 전환과 자동 복귀 확인 | PRD-COL-003, PRD-SAF-001, SRS-COL-003 | 외장 디스플레이 온라인, 색 모드 2개 이상. 사용자에게 사전 알림 | `tbdctl set-color external ycbcr422:12:pq --timeout 6`을 표준 입력 없이 실행 | 전환 직후 현재 색 ID와 링크 데이터의 비트 심도 변경. 제한 시간 뒤 원래 색 모드 복귀와 복귀 정보 파일 삭제. 디스플레이 온라인 유지 | 통합 | macOS 26, Apple Silicon | 통과 | 창 앱의 적용 버튼은 같은 변경 묶음을 쓰며 화면 표시만 확인 |
| TC-COL-005 | DSC 판정 확인 | PRD-COL-004, PRD-LNK-003, SRS-COL-004 | 합성 픽스처 (DSC 지원 색 요소, DSC 필수 목록 포함)와 실측 픽스처 | DSC 판정 실행 | 합성 픽스처는 DSC 필요 모드 식별. 실측 픽스처는 싱크 DSC 미지원 판정 | 단위 | macOS 26, Apple Silicon | 통과 | |
| TC-COL-006 | DSC 전환 계획 확인 | PRD-COL-006, SRS-COL-006 | 합성 픽스처 (DSC 사용 모드 3개, 미사용 모드 4개, PQ 형식 포함)와 실측 픽스처 | 켜기와 끄기 계획 산출 | 끄기는 같은 전달 함수의 미사용 모드 중 점수가 가장 높은 것, 켜기는 사용 모드 선택. 이미 요청 상태이거나 후보가 없으면 사유와 함께 거부. 실측 픽스처는 켜기 불가 | 단위 | macOS 26, Apple Silicon | 통과 | |
| TC-COL-007 | DSC 전환 실행 확인 | PRD-COL-006, PRD-CLI-002, SRS-COL-006 | DSC 지원 디스플레이 온라인 | `tbdctl dsc <외장> off`, 확인 없이 대기 후 `tbdctl dsc <외장>` | 전환 직후 DSC 미사용, 제한 시간 뒤 DSC 사용으로 복귀 | 통합 | macOS 26, Apple Silicon | 보류 | DSC 지원 디스플레이 필요. DSC 미지원 구성의 조회와 거부(종료 코드 3)는 내장 디스플레이로 확인 |
| TC-HDR-001 | HDR 상태와 정보 조회 확인 | PRD-HDR-001, PRD-HDR-003, SRS-HDR-001 | HDR 지원 외장 디스플레이 온라인 | `swift test`의 TC-HDR-001 묶음: `HDRService` 결과를 `MPDisplay`의 `hasHDRModes`, `preferHDRModes`, 링크 데이터의 EOTF와 비교. `tbdctl hdr external` | 지원 여부와 활성 상태가 시스템 설정 판정과 일치. 지원 EOTF 표시. 링크 데이터의 EOTF가 HDR 상태와 일치 | 통합 | macOS 26, Apple Silicon | 통과 | |
| TC-HDR-002 | HDR 전환과 자동 복귀 확인 | PRD-HDR-002, PRD-SAF-001, SRS-HDR-001 | HDR 지원 외장 디스플레이 온라인. 사용자에게 사전 알림 | `tbdctl hdr external off --timeout 6`을 표준 입력 없이 실행. `--yes`로 끄기, 색 모드 전환 시험, `--yes`로 켜기 | 전환 직후 HDR 상태와 링크 데이터의 EOTF 변경. 제한 시간 뒤 원래 상태 복귀와 복귀 정보 파일 삭제. 디스플레이 온라인 유지 | 통합 | macOS 26, Apple Silicon | 통과 | |
| TC-LNK-001 | 링크 정보 조회 확인 | PRD-LNK-001, SRS-LNK-001 | 외장 디스플레이 온라인 | `swift test`의 TC-LNK-001 묶음: 픽스처 해석과, 실제 조회 결과를 `IOPortTransportStateDisplayPort` 원시 속성과 비교 | 링크 속도, 레인 수, 터널링, HPD 값 일치. 제품명이 디스플레이 이름과 일치. 필요 대역폭이 유효 대역폭 이내 | 통합 | macOS 26, Apple Silicon | 통과 | |
| TC-LNK-002 | 대역폭 계산 확인 | PRD-LNK-002, SRS-LNK-002 | 없음 | 픽셀 클록 1,071.36 MHz에 대해 YCbCr 4:2:2 12 bpc, RGB 10 bpc, RGB 8 bpc 계산. HBR3 4레인, UHBR10 4레인, FRL 48 Gbps 가용 대역폭 계산 | 25.71, 32.14, 25.71 Gbps. 가용 25.92, 38.79, 42.67 Gbps (소수 둘째 자리 반올림). 실측 픽스처의 링크 보고에서 사용률 99.2%, RGB 10 bpc는 대역폭 초과 판정 | 단위 | macOS 26, Apple Silicon | 통과 | |
| TC-LNK-003 | HDMI 링크 정보 확인 | PRD-LNK-004, SRS-LNK-003 | HDMI 직결 디스플레이 | `tbdctl link <외장> --json` | 전송 방식 HDMI, TMDS 또는 FRL 속도 표시 | 통합 | macOS 26, Apple Silicon | 보류 | HDMI 직결 구성 필요. TMDS 문자 속도와 FRL 유효 대역폭 계산은 단위 테스트 통과 |
| TC-LNK-004 | DPCD 해석과 실패 허용 확인 | PRD-LNK-005, SRS-LNK-004 | DPCD 픽스처 (내장 패널 실측) | 픽스처 해석. 읽기 실패 입력(nil) 처리 | DPCD 1.4, 최대 속도 HBR3, 최대 4레인 해석. nil 입력 시 해당 항목 없음으로 표시하고 충돌 없음 | 단위 | macOS 26, Apple Silicon | 통과 | |
| TC-PRT-001 | 포트와 케이블 정보 조회 확인 | PRD-PRT-001, PRD-PRT-002, SRS-PRT-001 | 독 경유 외장 디스플레이 온라인 | `swift test`의 TC-PRT-001 묶음: 픽스처 해석과, 실제 조회 결과를 포트 컨트롤러 노드의 `PortDescription`과 비교. `tbdctl ports` | 픽스처: USB-C 3개, HDMI 1개, MagSafe 1개, 독 Parade Technologies PS9010, 케이블 USB4 Gen 4와 5 A와 EPR. 실제 조회: 포트 목록이 레지스트리와 일치, 외장 디스플레이마다 경로 1개 도달 | 통합 | macOS 26, Apple Silicon | 통과 | |
| TC-PRT-002 | 연결 경로 조립 확인 | PRD-PRT-003, SRS-PRT-002 | 정상 상태와 사고 시점(T04)의 IORegistry 픽스처 | 연결 경로 조립 | 정상 픽스처: USB-C 4번 포트, 케이블, Parade Technologies PS9010, HBR3 x 4(터널링), LG TV SSCR2 순서의 경로 1개. 사고 시점 픽스처: 영상 링크 단계에서 끊김(HPD 감지, 링크 없음). 링크는 있으나 온라인 목록에 없는 경우 디스플레이 단계에서 끊김 | 단위 | macOS 26, Apple Silicon | 통과 | |
| TC-DGN-001 | 미출력 진단 규칙 확인 | PRD-DGN-001, PRD-DGN-003, SRS-DGN-001 | 합성 스냅샷 6종 (연결 없음, HPD 없음, EDID 없음, 링크 없음, 프레임버퍼 미할당, 정상) | 진단 실행 | 스냅샷별 첫 실패 단계와 발견 부호가 기대값과 일치. 각 발견 항목에 조치 문구 존재. T04 사고 시점 픽스처는 HPD 통과 뒤 단계에서 실패. 실제 구성(`swift test`의 TC-DGN-001 실측 묶음)은 외장 디스플레이 포트 전 단계 통과 | 단위 | macOS 26, Apple Silicon | 통과 | |
| TC-DGN-002 | 모드 제한 진단 확인 | PRD-DGN-002, PRD-DGN-003, SRS-DGN-001 | 실측 스냅샷 픽스처 | 3840x2160 120 Hz에서 RGB 10 bpc 선택 불가 사유 조회 | 대역폭 초과 발견(필요 32.14 Gbps, 유효 25.92 Gbps, 원인에 DSC 미지원과 HBR3 4레인)과 크로마 서브샘플링 주의(HDR 끄기 제안) | 단위 | macOS 26, Apple Silicon | 통과 | |
| TC-DGN-003 | 시스템 제약 점검 확인 | PRD-DGN-006, SRS-DGN-001 | 합성 스냅샷 (외장 디스플레이 수 한도 도달) | 진단 실행 | 한도 도달 발견 항목 생성 | 단위 | macOS 26, Apple Silicon | 통과 | |
| TC-DGN-004 | 이벤트 기록 확인 | PRD-DGN-004, SRS-DGN-002 | 스냅샷 2개 (모드 변경 전후, 연결 전후) | 스냅샷 차이로 이벤트 생성. 1,001건 추가 | 모드 변경, 연결, 해제 이벤트 생성. 보관 수 1,000건 유지 | 단위 | macOS 26, Apple Silicon | 통과 | |
| TC-DGN-005 | 진단 보고서 내보내기 확인 | PRD-DGN-005, SRS-DGN-003 | 스냅샷 픽스처 | JSON과 텍스트 직렬화. 일련번호 가림 옵션 적용. `tbdctl report <경로>` 실행 | JSON 왕복 후 동일. 가림 적용 시 일련번호와 UUID 미포함, EDID 일련번호 바이트 0. 텍스트 보고서에 5개 구역 포함. 파일 생성 | 단위 | macOS 26, Apple Silicon | 통과 | |
| TC-BRT-001 | 내장 디스플레이 밝기 제어 확인 | PRD-BRT-001, SRS-BRT-001 | 내장 디스플레이 온라인. 사용자에게 사전 알림 | `swift test`의 TC-BRT-001 묶음: 밝기 조회, 0.1 바꿔 설정, 재조회, 원래 값 복원. `tbdctl brightness builtin 72` | 재조회 값이 설정값과 0.02 이내 일치. 복원 완료 | 통합 | macOS 26, Apple Silicon | 통과 | |
| TC-BRT-002 | 전달 테이블 합성과 소프트웨어 디밍 확인 | PRD-BRT-003, PRD-CLR-002, SRS-CLR-001 | 없음 | 디밍 0.5, 색온도, 게인, 대비, 감마 조합으로 테이블 합성. 항등 설정 합성 | 항등 설정은 선형 테이블. 디밍 0.5는 최댓값 0.5. 단조 증가 유지. 값 범위 0-1. 실측(`swift test`의 TC-BRT-002 실측 묶음): 디밍 0.8 적용 시 테이블 최댓값이 기준의 0.8배, 재적용 요청에 겹침 없음, 항등 적용 시 기준 테이블 복원 | 단위 | macOS 26, Apple Silicon | 통과 | |
| TC-BRT-003 | 자동 밝기 전환 확인 | PRD-BRT-004, SRS-BRT-001 | 내장 디스플레이 온라인 | 자동 밝기 상태 조회, 반전, 재조회, 복원 | 재조회 값이 반전값과 일치. 복원 완료 | 통합 | macOS 26, Apple Silicon | 통과 | |
| TC-DDC-001 | DDC 패킷 구성과 응답 해석 확인 | PRD-DDC-003, SRS-DDC-001 | 없음 | VCP 0x10 읽기 요청 패킷 생성, 쓰기 패킷 생성, 정상 응답과 체크섬 오류 응답 해석 | 요청 바이트열과 체크섬이 기대값과 일치. 정상 응답에서 현재값과 최댓값 추출. 오류 응답 거부 | 단위 | macOS 26, Apple Silicon | 통과 | |
| TC-DDC-002 | DDC 미응답 탐지 확인 | PRD-DDC-001, SRS-DDC-001 | DDC 미응답 디스플레이 (LG TV) 온라인 | `tbdctl ddc <외장> probe` | 미응답 판정과 사유 문구 출력. 종료 코드 3 | 통합 | macOS 26, Apple Silicon | 미실행 | LG TV 분리 상태. 재연결 후 실행 |
| TC-DDC-003 | DDC 제어 확인 | PRD-DDC-002, PRD-BRT-002, SRS-DDC-001 | DDC 지원 모니터 온라인 | 밝기, 대비, 볼륨 읽기와 쓰기 후 복원 | 재조회 값이 설정값과 일치 | 통합 | macOS 26, Apple Silicon | 보류 | DDC 지원 모니터 필요 |
| TC-CLR-001 | 색 프로파일 열거와 지정 확인 | PRD-CLR-001, SRS-CLR-002 | 디스플레이 온라인. 사용자에게 사전 알림 | `swift test`의 TC-CLR-001 묶음: 프로파일 목록 조회, sRGB 프로파일 지정, 재조회, 원래 프로파일 복원 | 목록 1개 이상이며 경로 중복 없음. 재조회 값이 지정값과 일치. 복원 완료 | 통합 | macOS 26, Apple Silicon | 통과 | |
| TC-CLR-002 | Night Shift와 True Tone 제어 확인 | PRD-CLR-003, PRD-CLR-004, SRS-CLR-003 | 내장 디스플레이 온라인. 사용자에게 사전 알림 | `swift test`의 TC-CLR-002 묶음: Night Shift 켜짐 상태와 강도, True Tone 상태를 각각 조회, 변경, 재조회, 복원 | 재조회 값이 변경값과 일치. 복원 완료 | 통합 | macOS 26, Apple Silicon | 통과 | |
| TC-ARR-001 | 회전 확인 | PRD-ARR-001, SRS-ARR-002 | 회전 지원 외장 디스플레이 온라인 | 90도 회전 후 확인 없이 대기 | 회전 직후 `CGDisplayRotation` 값 90. 제한 시간 뒤 0 복귀 | 통합 | macOS 26, Apple Silicon | 미실행 | 회전 지원 외장 디스플레이 필요. LG TV 재연결 후 실행 |
| TC-ARR-002 | 미러링 확인 | PRD-ARR-002, SRS-ARR-001 | 디스플레이 2대 온라인 (가상 디스플레이를 두 번째 디스플레이로 사용 가능). 사용자에게 사전 알림 | `tbdctl mirror <대상> <원본> --timeout 5`를 표준 입력 없이 실행 | 설정 직후 대상이 원본의 미러로 조회. 제한 시간 뒤 해제 | 통합 | macOS 26, Apple Silicon | 통과 | 가상 디스플레이(1920x1080 HiDPI)를 두 번째 디스플레이로 사용해 실측 (T13) |
| TC-ARR-003 | 메인 지정과 위치 편집 확인 | PRD-ARR-003, PRD-ARR-004, SRS-ARR-001 | 디스플레이 2대 온라인 (가상 디스플레이를 두 번째 디스플레이로 사용 가능). 사용자에게 사전 알림 | `tbdctl main`으로 메인 교체와 원복, `tbdctl move`로 좌표 변경과 원복, 맞닿지 않는 좌표 요청 | 교체 후 메인 디스플레이 변경. 좌표 조회값이 입력값과 일치. 떨어진 좌표는 맞닿는 위치로 보정. 복원 완료 | 통합 | macOS 26, Apple Silicon | 통과 | 가상 디스플레이(1920x1080 HiDPI)를 두 번째 디스플레이로 사용해 실측 (T13) |
| TC-ARR-004 | 연결 해제, 재연결, 보호 확인 | PRD-ARR-005, PRD-SAF-003, SRS-ARR-003 | 디스플레이 2대 온라인 (가상 디스플레이를 두 번째 디스플레이로 사용 가능). 사용자에게 사전 알림 | `tbdctl disconnect <대상> --timeout 5`를 표준 입력 없이 실행. 디스플레이 1대 구성에서 `tbdctl disconnect` | 해제 후 온라인 목록 1대. 제한 시간 뒤 자동 재연결로 2대. 마지막 1대 해제는 종료 코드 3으로 거부 | 통합 | macOS 26, Apple Silicon | 통과 | 가상 디스플레이(1920x1080 HiDPI)를 두 번째 디스플레이로 사용해 실측 (T13) |
| TC-ARR-005 | 언더스캔 확인 | PRD-ARR-006, SRS-ARR-004 | 언더스캔 지원 디스플레이 온라인 | 언더스캔 값 조회, 변경, 재조회, 복원 | 재조회 값이 설정값과 일치. 미지원 디스플레이는 비활성 표시 | 통합 | macOS 26, Apple Silicon | 미실행 | 언더스캔 지원 디스플레이 필요. LG TV 재연결 후 확인 |
| TC-VRT-001 | 가상 디스플레이 생성, 삭제, 복원 확인 | PRD-VRT-001, PRD-VRT-003, SRS-VRT-001 | 사용자에게 사전 알림 | `swift test`의 TC-VRT-001 묶음: 1920x1080 HiDPI 가상 디스플레이 생성, 온라인 목록 확인, 삭제. 창 앱에서 추가, 켜기, 끄기, 삭제. 실행 시 복원을 켠 구성으로 앱 재실행 | 생성 후 온라인 목록 1대 증가, 백킹 3840x2160, 식별 정보 일치. 삭제 후 원복. 저장 구성이 재실행 뒤 목록에 표시되고 실행 시 복원 대상은 자동 생성. 앱 종료 시 가상 디스플레이 제거 | 통합 | macOS 26, Apple Silicon | 통과 | |
| TC-VRT-002 | HiDPI 스케일링 확인 | PRD-VRT-002, SRS-VRT-002 | 외장 디스플레이 온라인 | 논리 해상도 2560x1440 HiDPI 스케일링 적용, 해제 | 적용 후 외장 디스플레이가 가상 디스플레이의 미러. 해제 후 미러 없음과 가상 디스플레이 삭제 | 통합 | macOS 26, Apple Silicon | 미실행 | 스케일링 계획의 단위 테스트는 통과. 실제 디스플레이 대상 적용은 LG TV 재연결 후 실행 |
| TC-PRF-001 | 프로파일 직렬화와 디스플레이 대응 확인 | PRD-PRF-001, PRD-PRF-003, SRS-PRF-001 | 없음 | 프로파일 JSON 왕복 변환. 추가, 이름 중복, 이름 변경, 삭제, 손상 파일, 상위 판 번호. UUID 일치, UUID 불일치와 제품 정보 일치, 전부 불일치 3종 대응 | 왕복 후 동일. 중복과 빈 이름 거부. 대응 결과가 UUID 우선 규칙과 일치 | 단위 | macOS 26, Apple Silicon | 통과 | |
| TC-PRF-002 | 프로파일 적용 확인 | PRD-PRF-002, SRS-PRF-002 | 디스플레이 2대 온라인 (가상 디스플레이를 두 번째 디스플레이로 사용 가능). 사용자에게 사전 알림 | `tbdctl profile save` 후 해상도와 위치 변경. `profile apply --timeout 5`를 표준 입력 없이 실행, 이어서 `profile apply --yes`. 적용 계획의 단위 테스트 | 적용 시 차이가 있는 단계만 수행하고 단계별 결과 표시. 확인 없으면 적용 전 구성으로 복귀. 확정 적용 뒤 저장 시점 구성 복원. 같은 구성에서는 변경 없음 | 통합 | macOS 26, Apple Silicon | 통과 | 가상 디스플레이(1920x1080 HiDPI)를 두 번째 디스플레이로 사용해 모드와 배치 단계 실측. 색 모드, HDR, 회전 단계는 계획 단위 테스트로만 확인 |
| TC-SAF-001 | 자동 복귀 상태 기계 확인 | PRD-SAF-001, SRS-SAF-001 | 없음 | 가짜 시계와 가짜 적용기로 PRD 3절 전이 9종 실행. 확인 대기 중 새 요청 | 전이 결과가 표와 일치. 타이머 만료 시 복귀 1회 호출. 새 요청 거부 | 단위 | macOS 26, Apple Silicon | 통과 | |
| TC-SAF-002 | 복귀 정보 파일 확인 | PRD-SAF-002, SRS-SAF-002 | 임시 폴더 | 기록, 조회, 삭제. 손상 파일 조회 | 기록 후 조회값 동일. 삭제 후 없음. 손상 파일은 없음으로 처리 | 단위 | macOS 26, Apple Silicon | 통과 | |
| TC-CLI-001 | 조회 명령 확인 | PRD-CLI-001, SRS-CLI-001 | 디스플레이 온라인 | `swift test`의 TC-CLI-001 묶음: `list`, `capabilities`, `info`, `modes`, `signal`, `link`, `hdr`, `ports`, `diagnose`를 `--json`으로 실행, `report` 저장 | 전 명령 종료 코드 0. 출력이 유효한 JSON. 사용법 오류는 2, 대상 없음은 3 | 통합 | macOS 26, Apple Silicon | 통과 | |
| TC-CLI-002 | 설정 명령 확인 | PRD-CLI-002, SRS-CLI-001 | 외장 디스플레이 온라인 | `set-mode`, `set-color`, `hdr`, `brightness`로 변경 후 복원 | 변경 후 조회값이 설정값과 일치. 복원 완료 | 통합 | macOS 26, Apple Silicon | 통과 | set-mode, set-color, hdr(T04-T06), brightness(T10) 실측 |
| TC-CLI-003 | 인자 해석과 종료 코드 확인 | PRD-CLI-003, SRS-CLI-001 | 없음 | 알 수 없는 명령, 인자 누락, 없는 디스플레이 지정, 정상 명령 해석 | 사용법 오류 2, 대상 없음 3, 정상 해석 결과 일치 | 단위 | macOS 26, Apple Silicon | 통과 | |
| TC-EDO-001 | EDID 검증과 편집 확인 | PRD-EDO-001, PRD-EDO-002, SRS-EDO-001 | 실측 EDID 픽스처와 HDMI 합성 픽스처 (HF-VSDB, HDR, Dolby Vision, 4:2:0 블록 포함) | 검증, 편집 7종 적용 후 재해석 | 손상 EDID는 문제 목록 반환. 편집본은 검증 통과, 대상 선언만 제거, 상세 타이밍과 식별 정보 유지. 실측 EDID는 HDMI 선언이 없어 DSC 편집 변경 없음 | 단위 | macOS 26, Apple Silicon | 통과 | |
| TC-EDO-002 | `edid` 명령의 파일 처리와 거부 확인 | PRD-EDO-001, PRD-EDO-002, PRD-CLI-002, SRS-EDO-001 | EDID 픽스처 파일 | `tbdctl edid builtin check <파일>`, `patch remove-hdr,remove-ycbcr,remove-dsc --in <파일> --out <파일>`, 내장 디스플레이 대상 `patch --apply`와 `reset` | 검증 통과와 능력 요약 출력, 편집 전후 비교 출력, 저장한 편집본의 검증 통과. 내장 디스플레이 대상 적용과 해제는 종료 코드 3 | 통합 | macOS 26, Apple Silicon | 통과 | 수동 실행 |
| TC-EDO-003 | 가상 EDID 적용과 자동 복귀 확인 | PRD-EDO-003, SRS-EDO-002 | 외장 디스플레이 온라인 | `tbdctl edid <외장> patch remove-hdr --apply` 후 확인 없이 대기, 이어서 `tbdctl hdr <외장>` | 적용 직후 HDR 미지원 표시, 제한 시간 뒤 원본 EDID 복귀와 HDR 지원 표시 | 통합 | macOS 26, Apple Silicon | 미실행 | LG TV 분리 상태. 재연결 후 실행 (화면 변경 시험, U-01 절차) |
| TC-EDO-004 | 디스플레이 재감지 확인 | PRD-EDO-004, SRS-EDO-002 | 디스플레이 온라인 | `tbdctl redetect` 후 `tbdctl list` | 종료 코드 0. 디스플레이 목록과 현재 모드 유지 | 통합 | macOS 26, Apple Silicon | 통과 | 내장 디스플레이만 온라인인 상태에서 실행 |
| TC-EDO-005 | 사용자 정의 타이밍 계산과 주입 확인 | PRD-EDO-005, SRS-EDO-003 | 실측 EDID 픽스처와 HDMI 합성 픽스처 | CVT 계산, 서술자 부호화와 재해석, EDID 추가 | 1920x1080 60 Hz 1판은 138.50 MHz와 총 2080 x 1111, 3840x2160 60 Hz 2판은 522.614 MHz와 총 3920 x 2222. 추가 뒤 검증 통과와 기존 타이밍 유지. 655.35 MHz 초과 타이밍은 DisplayID 확장에 기록, 확장이 없으면 새 블록 생성 | 단위 | macOS 26, Apple Silicon | 통과 | |
| TC-EDO-006 | 사용자 정의 타이밍 적용 확인 | PRD-EDO-005, PRD-EDO-003, SRS-EDO-003 | 외장 디스플레이 온라인 | `tbdctl edid <외장> timing 2560x1440@100 --apply` 후 `tbdctl modes <외장>` | 모드 목록에 2560 x 1440 100 Hz 출현. 확인 없이 대기하면 원본 EDID 복귀 | 통합 | macOS 26, Apple Silicon | 미실행 | LG TV 분리 상태. 재연결 후 실행 (화면 변경 시험, U-01 절차). 파일 입력의 계산과 저장은 수동 실행으로 확인 |

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
