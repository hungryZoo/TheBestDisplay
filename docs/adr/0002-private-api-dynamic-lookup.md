# ADR-0002: 비공개 API의 실행 시 동적 조회와 기능 가용성 판정

- 상태: 채택
- 관련: SRS-ARC-002, MRD-RSK-001, MRD-RSK-003, MRD-PLT-003, E-03

## 맥락

- 색 모드, 링크 정보, 숨은 모드, HDR 전환, DDC는 공개 API로 제공 불가
- 선행 실험에서 SkyLight, IOMobileFramebuffer, IOKit(IOAV, IODP 계열), DisplayServices, MonitorPanel의 심볼 존재와 읽기 경로 동작 확인 (`docs/research/spikes.md`)
- 비공개 심볼은 macOS 판에 따라 제거되거나 시그니처가 바뀔 가능성 존재

## 결정

- 비공개 프레임워크를 정적 링크하지 않고 `dlopen`과 `dlsym`으로 실행 시 조회
- 심볼 단위로 가용성을 판정하여 `Capability` 집합으로 노출. 미가용 기능은 비활성 표시와 사유 제공
- 구조체는 실측한 크기와 오프셋으로 원시 바이트에서 해석. 크기 가정은 단위 테스트로 고정
- Objective-C 비공개 클래스(`MPDisplay`, `CGVirtualDisplay`, `CBBlueLightClient` 등)는 `NSClassFromString`과 셀렉터 응답 확인 후 호출
- DSC는 색 모드 선택을 통한 간접 제어와 상태 표시로 한정
- 샌드박스 미적용, Mac App Store 배포 제외

## 근거

- 심볼 누락 시 실행 실패(dyld 오류) 대신 기능 단위 비활성으로 축소
- SDK에 없는 프레임워크의 링크 설정 불필요

## 결과

- 함수 포인터 타입 선언의 정확성은 컴파일러가 검증하지 않음. 선언마다 근거(디스어셈블, 공개 소스, 실험)를 주석과 조사 문서에 기록
- 쓰기 경로는 기능별 TC에서 실측. 호출 거부 시 읽기 전용 제공으로 전환하고 문서 갱신

## 대안

- 공개 API 한정: 핵심 요구(색 모드, 링크 정보) 충족 불가
- 권한 상승 도우미 프로세스: 설치 절차와 보안 부담 증가. 비권한 호출 실패가 확인된 기능에 한해 재검토
