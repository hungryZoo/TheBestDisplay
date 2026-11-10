# ADR-0001: SwiftPM 패키지와 번들 조립 스크립트 기반 빌드

- 상태: 채택
- 관련: SRS-ARC-001, SRS-ARC-003, E-02

## 맥락

- 창 앱(.app 번들)과 명령행 도구를 같은 코드 기반에서 제공
- 턴마다 명령행에서 빌드, 테스트, 검증을 자동 수행
- 순수 로직(EDID 해석, 대역폭 계산, 진단 규칙)은 하드웨어 없이 단위 테스트 필요

## 결정

- SwiftPM 단일 패키지에 TBDCore, TBDPlatform, TheBestDisplay(앱), tbdctl(CLI) 타깃 구성
- 앱 번들은 `scripts/build_app.sh`가 릴리스 실행 파일, `Info.plist`, ad-hoc 서명으로 조립
- 외부 패키지 의존성 없음

## 근거

- `swift build`와 `swift test`만으로 전체 검증 가능
- 프로젝트 파일(.xcodeproj)의 병합 충돌과 생성 도구 의존 제거
- Xcode에서 `Package.swift`를 직접 열어 개발 가능

## 결과

- 앱 아이콘, 엔타이틀먼트, 서명 설정은 스크립트에서 관리
- SwiftUI 미리 보기는 Xcode에서 패키지를 열 때만 사용 가능

## 대안

- Xcode 프로젝트 직접 관리: GUI 설정 편의, 명령행 자동화와 변경 추적 불리
- XcodeGen: 프로젝트 생성 자동화, 도구 의존 추가
