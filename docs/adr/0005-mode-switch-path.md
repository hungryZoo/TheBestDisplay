# ADR-0005: 모드 전환 경로는 MonitorPanel 우선, SkyLight 직접 호출은 명시 지정 시에만

- 상태: 채택
- 관련: SRS-MOD-002, PRD-MOD-003, PRD-MOD-005, MRD-RSK-006, E-08

## 맥락

- T04 시험에서 `CGBeginDisplayConfiguration`, `SLSConfigureDisplayMode`, `CGCompleteDisplayConfiguration(.forSession)` 순서로 LG TV(USB-C 4번 포트, Thunderbolt 독 경유)의 주사율을 120 Hz에서 60 Hz로 전환
- 전환 값은 시스템 설정 파일에 저장되었으나 2.5초 이내에 TV가 온라인 목록에서 사라짐. 프레임버퍼 노드에서 디스플레이 정보가 제거되었고, 이후 DP 링크도 내려감 (HPD High, 싱크 수 0, No Link)
- 디스플레이 절전 후 깨우기, `SLSConfigureDisplayEnabled`(오류 1001), `IOAVControllerForceHotPlugDetect`(반환 0)로 복구되지 않았고 케이블 재연결로 복구
- 같은 전환(60 Hz에서 120 Hz, 120 Hz에서 60 Hz, 해상도 변경, 시스템 설정 목록 밖 모드)을 `MPDisplay`의 `setModeNumber:`로 수행하면 6회 모두 디스플레이 온라인 유지

## 결정

- 모드 전환 기본 경로 순서: (1) MonitorPanel의 `MPDisplay setModeNumber:`, (2) 공개 API `CGConfigureDisplayWithDisplayMode`
- `SLSConfigureDisplayMode` 직접 호출은 기본 순서에서 제외. 명령행의 `--method skyLight` 명시 지정 시에만 사용
- 시스템이 오류 코드로 거부한 전환은 다른 경로로 재시도하지 않음. 경로 자체를 쓸 수 없는 경우에만 다음 경로 시도
- 복귀와 확정 전에 대상 디스플레이의 온라인 여부 확인. 사라졌으면 복귀 정보 파일을 유지하고 재연결 안내

## 근거

- `MPDisplay`는 시스템 설정의 디스플레이 패널이 쓰는 구현이며 실측에서 안정 동작
- `MPDisplay`의 `allModes`는 윈도우 서버 모드 319개 전체를 포함하므로 숨은 모드 전환 범위 손실 없음

## 결과

- MonitorPanel 경로는 세션 한정 적용 구분이 없어 적용 즉시 시스템 설정에 저장. 자동 복귀는 이전 모드 재적용으로 수행
- SkyLight 경로의 실패 원인(세션 한정 옵션, 호출 순서, 독 경유 구성 중 무엇인지)은 미확인. 재현 시험은 디스플레이 재연결이 필요하므로 보류

## 대안

- SkyLight 경로 유지와 원인 분석: 재현마다 재연결 필요, 사용자 부담
- 공개 API 단독: 공개 목록에 없는 숨은 모드 전환 불가
