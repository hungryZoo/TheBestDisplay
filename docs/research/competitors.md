# 경쟁 제품 기능 조사

## 0. 조사 개요

- 조사일: 2026-11-10
- 조사 목적: TheBestDisplay(macOS 26, Apple Silicon 대상 디스플레이 설정 및 진단 앱) Phase 0 기능 후보 도출용 경쟁 제품 기능 목록화
- 조사 방법: 공식 저장소 README, Wiki, 공식 가이드 사이트, 릴리스 노트, 공개 소스 코드 열람. 앱 실행 검증 없음
- 조사 대상 버전
  - BetterDisplay v5.2.1 (2026-10-29 릴리스), CLI 문서는 v5.0.6 기준 표기
  - WhatCable v1.5.0 (2026-10-13 릴리스, 커밋 58e588a)
  - MonitorControl v4.4.0, Lunar v6.11.3, displayplacer v1.4.0, AllRez 2025-04-21 최종 커밋
- 확인 구분 정의
  - 문서: 공식 문서(README, Wiki, 가이드, 공식 사이트, 릴리스 노트, 개발자 본인의 이슈 코멘트)에서 확인
  - 소스: 공개 소스 코드에서 클래스명, 키, 로직을 직접 확인
  - 미확인: 문서와 소스 어디에서도 확인하지 못함. 추측 기재 없음
- 출처 표기 방식: 각 절의 "출처 목록" 표에 키와 URL 정의, 본문 표의 "출처" 열에 키 기재

## 1. BetterDisplay

### 1.1 제품 개요

| 항목 | 내용 | 출처 | 확인 |
| --- | --- | --- | --- |
| 형태 | 메뉴 막대 앱, 선택형 사이드바 레이아웃, 설정 창 | B1 | 문서 |
| 개발 | waydabber, Kodeon Software | B1 | 문서 |
| 소스 공개 여부 | 현행 앱 소스 비공개. 공개 저장소는 릴리스, 이슈, 토론 용도. `betterdisplaycli`와 번역 저장소만 공개 | G48 | 문서 |
| 배포 | 직접 배포(DMG, Homebrew cask). Mac App Store 미배포. 사유: 비공개 또는 비문서화 macOS 인터페이스 사용 | B1, G49 | 문서 |
| 지원 OS | v5: macOS 26.3 이상(Apple Silicon, Intel). v4.3.7: macOS 13.2 이상 | B1 | 문서 |
| 가격 | Pro 21.99 USD 또는 19.99 EUR, 영구 라이선스, 최소 2년 업데이트, 14일 체험 | B1 | 문서 |
| 무료 사용 조건 | 비업무용 무료 기능 제공 | B1, B3 | 문서 |
| 지역화 | 38개 언어 및 지역 변형, 한국어 포함 | B1 | 문서 |

### 1.2 출처 목록

| 키 | 문서 | URL |
| --- | --- | --- |
| B1 | README | https://github.com/waydabber/BetterDisplay |
| B2 | Wiki 목차 | https://github.com/waydabber/BetterDisplay/wiki |
| B3 | Wiki: 무료 및 Pro 기능 목록 | https://github.com/waydabber/BetterDisplay/wiki/List-of-free-and-Pro-features |
| B4 | Wiki: 통합 기능과 CLI | https://github.com/waydabber/BetterDisplay/wiki/Integration-features,-CLI |
| B5 | Wiki: HiDPI 데스크톱 | https://github.com/waydabber/BetterDisplay/wiki/Fully-scalable-HiDPI-desktop |
| B6 | Wiki: macOS 스케일링 설명 | https://github.com/waydabber/BetterDisplay/wiki/MacOS-scaling,-HiDPI,-LoDPI-explanation |
| B7 | Wiki: XDR 및 HDR 밝기 업스케일 | https://github.com/waydabber/BetterDisplay/wiki/XDR-and-HDR-brightness-upscaling |
| B8 | Wiki: TV용 Night Shift | https://github.com/waydabber/BetterDisplay/wiki/Enable-Night-Shift-for-televisions |
| B9 | Wiki: PWM 및 디더링 | https://github.com/waydabber/BetterDisplay/wiki/Eye-care:-prevent-PWM-and-or-temporal-dithering |
| B10 | 릴리스 노트 | https://github.com/waydabber/BetterDisplay/releases |
| B11 | betterdisplaycli 저장소 | https://github.com/waydabber/betterdisplaycli |
| B12 | 이슈 5935 (타이밍 즉시 생성 요청) | https://github.com/waydabber/BetterDisplay/issues/5935 |
| B13 | 이슈 5484 (Link Information 확장) | https://github.com/waydabber/BetterDisplay/issues/5484 |
| B14 | 이슈 5496 (DPCD, EDID, DSC 리포트) | https://github.com/waydabber/BetterDisplay/issues/5496 |
| G0 | 가이드 사이트맵 | https://betterdisplay.pro/guide/sitemap.xml |
| G1 | Display Mode | https://betterdisplay.pro/guide/interface-reference/app-menu/device-menu/display-mode/ |
| G2 | Refresh Rate | https://betterdisplay.pro/guide/interface-reference/app-menu/device-menu/refresh-rate/ |
| G3 | Color Depth | https://betterdisplay.pro/guide/interface-reference/app-menu/device-menu/color-depth/ |
| G4 | Color Mode | https://betterdisplay.pro/guide/interface-reference/app-menu/device-menu/color-mode/ |
| G5 | Screen Rotation | https://betterdisplay.pro/guide/interface-reference/app-menu/device-menu/rotation/ |
| G6 | Mirror Display | https://betterdisplay.pro/guide/interface-reference/app-menu/device-menu/mirroring/ |
| G7 | Move Display | https://betterdisplay.pro/guide/interface-reference/app-menu/device-menu/move-display/ |
| G8 | Configuration Protection | https://betterdisplay.pro/guide/interface-reference/app-menu/device-menu/configuration-protection/ |
| G9 | Management and Quick Toggles | https://betterdisplay.pro/guide/interface-reference/app-menu/device-menu/management-and-toggles/ |
| G10 | Device header and connection | https://betterdisplay.pro/guide/interface-reference/app-menu/device-menu/header-and-connection/ |
| G11 | Apple Display Preset | https://betterdisplay.pro/guide/interface-reference/app-menu/device-menu/apple-display-preset/ |
| G12 | Input Source | https://betterdisplay.pro/guide/interface-reference/app-menu/device-menu/input-source/ |
| G13 | Image Adjustments (앱 메뉴) | https://betterdisplay.pro/guide/interface-reference/app-menu/device-menu/image-adjustments/ |
| G14 | Color Profile | https://betterdisplay.pro/guide/interface-reference/app-menu/device-menu/color-profile/ |
| G15 | Sliders | https://betterdisplay.pro/guide/interface-reference/app-menu/device-menu/sliders/ |
| G16 | System Colors | https://betterdisplay.pro/guide/interface-reference/app-menu/tools/system-colors/ |
| G17 | Individual Display Settings (Display Information) | https://betterdisplay.pro/guide/interface-reference/settings/displays/display/ |
| G18 | Display EDID | https://betterdisplay.pro/guide/interface-reference/settings/displays/display/edid/ |
| G19 | System Configuration and Flexible Scaling | https://betterdisplay.pro/guide/interface-reference/settings/displays/display/system-configuration/ |
| G20 | General Settings | https://betterdisplay.pro/guide/interface-reference/settings/displays/display/general-settings/ |
| G21 | Additional Settings | https://betterdisplay.pro/guide/interface-reference/settings/displays/display/additional-settings/ |
| G22 | Display Connections | https://betterdisplay.pro/guide/interface-reference/settings/displays/overview/connections/ |
| G23 | DDC Control | https://betterdisplay.pro/guide/interface-reference/settings/displays/display/device-control/ddc/ |
| G24 | Image Adjustments (설정) | https://betterdisplay.pro/guide/interface-reference/settings/displays/display/image-adjustments/ |
| G25 | Software Image Adjustments, Upscaling and Dimming | https://betterdisplay.pro/guide/interface-reference/settings/displays/overview/brightness-upscaling-and-dimming/ |
| G26 | Create New Virtual Screen | https://betterdisplay.pro/guide/interface-reference/settings/displays/overview/create-virtual-screen/ |
| G27 | Virtual Screen | https://betterdisplay.pro/guide/interface-reference/settings/displays/virtual-screen/ |
| G28 | Advanced Virtual Screen Settings | https://betterdisplay.pro/guide/interface-reference/settings/displays/overview/advanced-virtual-screen-settings/ |
| G29 | Group Synchronization Settings | https://betterdisplay.pro/guide/interface-reference/settings/groups/group/synchronization/ |
| G30 | Free and Pro features | https://betterdisplay.pro/guide/licensing/free-and-pro-features/ |
| G31 | FAQ: HiDPI 해상도 한계 | https://betterdisplay.pro/guide/faq/scaling/hidpi-resolution-limits/ |
| G32 | FAQ: CRT 저해상도 신호 | https://betterdisplay.pro/guide/faq/scaling/crt-low-resolution/ |
| G33 | FAQ: HDMI 신호 분석 | https://betterdisplay.pro/guide/faq/general/hdmi-signal-analysis/ |
| G34 | FAQ: RGB 선택 | https://betterdisplay.pro/guide/faq/brightness/select-rgb/ |
| G35 | FAQ: 프레임버퍼와 연결 비트 심도 | https://betterdisplay.pro/guide/faq/brightness/framebuffer-connection-depth/ |
| G36 | FAQ: EDID 쓰기 결과 | https://betterdisplay.pro/guide/faq/scaling/edid-write-result/ |
| G37 | FAQ: DisplayID 확장 블록 | https://betterdisplay.pro/guide/faq/connections/displayid-extension/ |
| G38 | FAQ: 커스텀 EDID 가져오기 | https://betterdisplay.pro/guide/faq/scaling/import-custom-edid/ |
| G39 | FAQ: DisplayLink 스케일링 | https://betterdisplay.pro/guide/faq/scaling/displaylink-scaling/ |
| G40 | FAQ: 독 경유 DDC | https://betterdisplay.pro/guide/faq/general/ddc-through-dock/ |
| G41 | FAQ: Apple Cinema Display DDC | https://betterdisplay.pro/guide/faq/connections/apple-cinema-ddc/ |
| G42 | FAQ: 주사율 표시 불일치 | https://betterdisplay.pro/guide/faq/scaling/refresh-rate-disagrees/ |
| G43 | FAQ: HiDPI와 주사율 | https://betterdisplay.pro/guide/faq/scaling/hidpi-refresh-rate/ |
| G44 | FAQ: 디더링 비활성화 | https://betterdisplay.pro/guide/faq/brightness/disable-dithering/ |
| G45 | FAQ: 색 테이블 호환성 | https://betterdisplay.pro/guide/faq/brightness/color-table-compatibility/ |
| G46 | FAQ: 가상 스크린 HDR | https://betterdisplay.pro/guide/faq/scaling/virtual-screen-hdr/ |
| G47 | FAQ: 가상 스크린 주사율 | https://betterdisplay.pro/guide/faq/scaling/virtual-refresh-rate/ |
| G48 | FAQ: 소스 코드 | https://betterdisplay.pro/guide/faq/general/source-code/ |
| G49 | FAQ: Mac App Store | https://betterdisplay.pro/guide/faq/general/mac-app-store/ |
| G50 | 기술 용어: DSC | https://betterdisplay.pro/guide/technical-reference/dsc/ |
| G51 | 기술 용어: Link bandwidth | https://betterdisplay.pro/guide/technical-reference/link-bandwidth/ |
| G52 | 기술 용어: HDCP | https://betterdisplay.pro/guide/technical-reference/hdcp/ |
| G53 | FAQ: 네이티브 초과 데스크톱 | https://betterdisplay.pro/guide/faq/scaling/desktop-above-native/ |
| G54 | FAQ: 커스텀 EDID 재적용 | https://betterdisplay.pro/guide/faq/connections/edid-reapplied/ |

### 1.3 문서 구성

#### 1.3.1 Wiki 전체 목차 (16개 문서, 출처 B2, 확인: 문서)

- Wiki 상단 공지: 레거시 문서, 유지보수 중단, betterdisplay.pro/guide 이전 안내
- HiDPI, scaling
  - Fully scalable HiDPI desktop
  - MacOS scaling, HiDPI, LoDPI explanation
- Brightness and image control
  - XDR and HDR brightness upscaling
  - Enable Night Shift for televisions
  - Eye care: prevent PWM and/or temporal dithering
- Streaming/Sidecar
  - DIY teleprompter flipped screen
  - Rotated Sidecar
  - Salvage parts of a damaged screen by using virtual screen streaming
- App usage
  - Integration features, CLI
  - Safe mode, app reset, app removal
  - Export and import app settings
  - Enable console logging
- Licenses, features
  - Getting a Pro License
  - List of free and Pro features
  - License management via command line, scripted activation, MDM
- 목차 외 문서: Home

#### 1.3.2 가이드 사이트 구성 (사이트맵 508개 URL, 출처 G0, 확인: 문서)

- interface-reference/app-menu/device-menu: header-and-connection, display-mode, sliders, refresh-rate, color-depth, color-mode, mirroring, streaming, picture-in-picture, move-display, video-filters, rotation, device-control, image-adjustments, input-source, color-profile, apple-display-preset, configuration-protection, management-and-toggles
- interface-reference/app-menu/tools: displays-and-virtual-screens, groups, move-displays, video-filter-window, stream-selected-content, system-colors, updates-settings-and-quit, console
- interface-reference/settings/displays/overview: create-virtual-screen, advanced-virtual-screen-settings, connections, custom-controls, custom-lut-filters, brightness-upscaling-and-dimming
- interface-reference/settings/displays/display: general-settings, additional-settings, device-control(ddc, hdmi-cec-and-displaylink, displaylink, control-integration, network-controllers(lg-webos, samsung, philips, yamaha), volume-control, software-audio, combined-audio, settings), image-adjustments, system-configuration, edid
- interface-reference/settings: virtual-screen, groups(synchronization, layout-protection, ui-scale-matching), application, menu, keyboard, pro, about
- integration: shortcuts, cli-reference, cli-examples, controls-and-events, console, macos-console-logging, third-party-apps, terminal-preferences
- faq 범주: general, app-menu, scaling, display-modes, refresh-rates, edid, brightness, hdr, color, ddc, tv-controls, connections, display-disconnection, wake, layouts, keyboard-audio, audio, virtual-streaming, streaming, recording, remote-displays, automation, cli, licensing
- tutorials: 36개 문서
- technical-reference: 용어 문서 약 110개 (dsc, dpcd, link-bandwidth, color-mode, edid, hdcp, flexible-scaling 등)
- 본 조사에서 본문을 열람한 가이드 문서: 1.2절 G1-G54. 그 외 문서는 제목만 확인

### 1.4 기능 전수 목록

표기: "구분" 열은 무료 또는 Pro, "플랫폼" 열은 AS(Apple Silicon), Intel, 공통.

#### 1.4.1 해상도와 HiDPI

| 기능 | 내용 | 구분 | 플랫폼 | 출처 | 확인 |
| --- | --- | --- | --- | --- | --- |
| Display Mode 목록 | 논리 해상도, 종횡비 또는 Notch, 주사율, 비트 심도, HiDPI 여부를 한 행으로 표시. 선택 즉시 적용, Apply 단계 없음 | 무료 | 공통 | G1 | 문서 |
| 모드 필터 | 종횡비, 주사율, 비트 심도, HiDPI/LoDPI 태그 필터. Show All(unsafe, invalid 모드 포함), Show Custom Scaled Resolutions | 무료 | 공통 | G1 | 문서 |
| 모드 상태 라벨 | Current mode, Matches default resolution, Native mode (1:1 mapping), Invalid mode, Unsafe mode | 무료 | 공통 | G1 | 문서 |
| 즐겨찾기 모드 | 디스플레이별 5개 슬롯 저장 및 적용 | Pro | 공통 | G1, B4 | 문서 |
| 해상도 슬라이더 | 슬라이더 기반 데스크톱 크기 변경, 해상도 백분율 및 배율 표시 | 무료 | 공통 | G15, B3 | 문서 |
| HiDPI 토글 | 동일 크기의 HiDPI와 LoDPI 모드 간 전환 (`hiDPI`) | 무료 | 공통 | G9, B4 | 문서 |
| Notch 토글 | notch 포함 모드와 제외 모드 간 전환 (`notch`) | 메뉴 토글 무료(G9), CLI 문서는 Pro 표기(B4) | 공통 | G9, B4 | 문서 |
| Flexible scaling | 네이티브 종횡비 기준 다단계 스케일 해상도 생성. 구 명칭 native smooth scaling. 시스템 override 설치, 관리자 인증, 활성화 또는 재시동 필요 | Pro | 공통(네이티브 연결 한정) | G19, B5 | 문서 |
| Flexible scaling 범위 지정 | 최소 및 최대 폭, 높이 지정 | Pro | 공통 | G19 | 문서 |
| Custom scaled resolutions | 폭과 높이 입력 기반 스케일 해상도 추가. LoDPI와 HiDPI 변형 동시 요청. 행별 상태 표시(Currently available as HiDPI 등) | 무료 | 공통(네이티브 연결 한정) | G19 | 문서 |
| 네이티브 패널 해상도 편집 | Edit native panel pixel resolution | 무료 | 공통 | G19 | 문서 |
| 기본 해상도 편집 | Edit default resolution (폭, 높이, 주사율) | 무료 | 공통 | G19 | 문서 |
| 시스템 디스플레이 이름 편집 | Edit system display name | 무료 | 공통 | G19 | 문서 |
| 디스플레이 역할 편집 | Computer monitor 또는 Television 지정 | 무료 | 공통 | G19, B8 | 문서 |
| 720p 미만 해상도 허용 | Enable lower than 720p resolutions | 미확인 | 공통 | G31 | 문서 |
| 해상도 슬라이더 범위 제한 | 디스플레이별 슬라이더 선택지 제한, 물리 크기 보정 | 무료 | 공통 | G21 | 문서 |
| 커스텀 타이밍 편집기 | 제공 기능 없음. 타이밍 추가는 준비된 커스텀 EDID 바이너리 경유 | 해당 없음 | 해당 없음 | G38, B12 | 문서 |

#### 1.4.2 가상 스크린 (dummy)

| 기능 | 내용 | 구분 | 플랫폼 | 출처 | 확인 |
| --- | --- | --- | --- | --- | --- |
| 가상 스크린 생성 | 사전 구성 프리셋 기반 생성 및 연결 | 무료 | 공통 | G26, B3 | 문서 |
| 디스플레이 매칭 생성 | 실제 디스플레이 종횡비 매칭, 연관(association), 전체 화면 스트림 또는 미러 자동 구성 | Pro | 공통 | G26 | 문서 |
| 커스텀 종횡비 | `aspectWidth`, `aspectHeight`, `multiplierStep`, 해상도 범위 제한 | Pro | 공통 | G26, G27, B4 | 문서 |
| 커스텀 해상도 목록 | `useResolutionList`, `resolutionList` | Pro | 공통 | G27, B4 | 문서 |
| HiDPI 가상 스크린 | `virtualScreenHiDPI` | Pro | 공통 | G27, B4 | 문서 |
| HDR 가상 스크린 | 16비트 확장 휘도 모드, HDR 전용 모드 옵션 | Pro | 공통(지원 Mac 한정) | G27, G46 | 문서 |
| 커스텀 주사율 목록 | 24-240 Hz 입력, 기본 60 Hz | Pro | 공통(일부 구형 Mac 60 Hz 상한) | G27, G47 | 문서 |
| 8K 초과 해상도 | Enable resolutions over 8K (4K HiDPI) | 무료 | 공통 | G27, G31 | 문서 |
| 식별자 지정 | 이름, 시리얼, 벤더 번호, 모델 번호 | Pro | 공통 | G27, B4 | 문서 |
| 회전 방향 | Rotated Orientation (폭과 높이 교환), 연관 디스플레이 추종 자동 모드 | Pro | 공통 | G9 | 문서 |
| 연결과 폐기 | 연결, 연결 해제, 재연결, 폐기, 팩토리 색 프로파일 제거 | 무료 | 공통 | G9, G28 | 문서 |
| 연관 디스플레이 규칙 | 연관 디스플레이 기준 자동 연결, 미러 강제 | Pro | 공통 | G6, G10, G27 | 문서 |
| 활용 사례 | 헤드리스 Mac 원격 접속용 HiDPI 데스크톱, 네이티브 초과 데스크톱 미러, 손상 패널 부분 사용 | 혼합 | 공통 | B1, B2, G53 | 문서 |

#### 1.4.3 주사율과 VRR

| 기능 | 내용 | 구분 | 플랫폼 | 출처 | 확인 |
| --- | --- | --- | --- | --- | --- |
| Refresh Rate 메뉴 | 현재 해상도, HiDPI 상태, 비트 심도 기준 주사율 목록. 가변 주사율 행은 (Variable) 표기 | 무료 | 공통 | G2 | 문서 |
| 연결 수준 추가 주사율 | 일반 모드 목록에 없는 주사율(NTSC 분수 주사율 포함) 별도 그룹 표시 및 선택 | 무료 | AS | G2, G42, B3 | 문서 |
| 숨김 주사율 표시 | Option 누른 채 메뉴 열기 | 무료 | 공통 | G2 | 문서 |
| Refresh-rate reporter | Measured refresh rate, Reported actual refresh rate, Reported nominal refresh rate 실시간 표시(약 1초 주기). 소프트웨어 타이밍 관측값 | 무료 | 공통 | G2 | 문서 |
| CLI 주사율 목록 | `refreshRateList`: VRR 상태 포함, AS에서 비노출(NTSC) 타이밍 포함 | 무료 | 공통 | B4 | 문서 |
| 주사율 보호 | Configuration Protection의 Refresh Rate 항목, 비노출 주사율 보호 옵션 | Pro | 공통(비노출 주사율 보호는 AS) | G8, G21 | 문서 |

#### 1.4.4 HDR, XDR, 밝기 업스케일

| 기능 | 내용 | 구분 | 플랫폼 | 출처 | 확인 |
| --- | --- | --- | --- | --- | --- |
| HDR 모드 토글 | Enable HDR Mode (`hdr`), 서드파티 HDR 디스플레이 대상 | Pro | 공통 | G9, B4 | 문서 |
| Forced HDR | macOS의 해상도 및 주사율 제한 밖 HDR 모드 노출. 이미지 손상, 녹색 화면, 빈 화면 위험 경고 | Pro | AS | G4, G9 | 문서 |
| 색 테이블 XDR/HDR 업스케일 | 색 테이블(감마, EOTF) 조작 기반 SDR 휘도 확장. HDR 콘텐츠 클리핑 발생 | Pro | AS | B7, G24 | 문서 |
| Metal XDR/HDR 업스케일 | 오버레이 기반. 색 테이블 조정 비활성 조건 | Pro | 공통 | B7, G24 | 문서 |
| Direct XDR Upscaling | 내장 Apple XDR 디스플레이 전용 하드웨어 직접 제어. macOS 26.3 이상 | Pro | 내장 XDR 한정 | B7, G11 | 문서 |
| Native XDR 업스케일 | macOS 26.2 이하 전용 레거시 기능. v5 미포함 | Pro | 내장 XDR 한정 | B3, B7 | 문서 |
| 업스케일 보정 | HDR extra-brightness calibration, 수치 입력 지원(v5.2) | Pro | 공통 | B3, B10 | 문서 |
| 최대 휘도 | 지원 Apple XDR 디스플레이에서 1600 또는 2000 nits | Pro | 공통 | B1 | 문서 |
| XDR 프리셋 선택 | Apple Display Preset 선택(팩토리, 레퍼런스, 커스텀 구분) | 무료 | 공통 | G11, B3 | 문서 |
| SDR과 HDR 프로파일 자동 전환 | 모드별 색 프로파일 자동 전환 | Pro | 공통 | B1, B3 | 문서 |
| HDR 진입 시 Night Shift, True Tone 해제 | Disable Both in HDR Mode (`disableNightShiftInHDR`) | Pro | 공통 | G16, B4 | 문서 |
| HDR 상태 보호 | Configuration Protection의 HDR Status | Pro | 공통 | G8 | 문서 |
| HDR 정보 표시 | 디스플레이 지원 여부, 타이밍 및 스케일링 지원, native 또는 forced 또는 EDR 상태, EDR 현재값과 잠재값과 레퍼런스값, 보고된 HDR 휘도 | 무료 | 공통 | G17 | 문서 |

#### 1.4.5 DDC 제어

| 기능 | 내용 | 구분 | 플랫폼 | 출처 | 확인 |
| --- | --- | --- | --- | --- | --- |
| DDC 밝기, 대비, 볼륨 | `hardwareBrightness`, `hardwareContrast`, `volume`, `mute` | 무료 | 공통 | B3, B4 | 문서 |
| RGB gain, black level | `redHardwareGain`, `greenHardwareGain`, `blueHardwareGain`, `redHardwareBlackLevel`, `greenHardwareBlackLevel`, `blueHardwareBlackLevel` | 무료 | 공통 | B3, B4 | 문서 |
| 입력 전환 | DDC 입력 목록, 커스텀 이름과 아이콘과 블록 배치, LG 대체 주소 명령(`ddcAlt`), `changeInputSource`, `inputSourceList` | 무료 | 공통 | G12, B4 | 문서 |
| 전원 제어 | `hardwarePowerOff`, `hardwareBacklight`, 헤더 스위치의 DDC Power Off | 무료 | 공통 | G10, B4 | 문서 |
| 공장 초기화 | `hardwareFactoryReset` | Pro 표기 없음 | 공통 | B4 | 문서 |
| DDC capabilities 탐지 | capabilities 문자열 파싱 및 지원 명령 읽기 시도, 자동 구성 (`ddcCapabilities`, `ddcCapabilitiesString`) | 무료 | 공통 | G23, B4 | 문서 |
| 임의 VCP 읽기와 쓰기 | `ddc` + `vcp` + `value`, VCP 이름 또는 10진 또는 16진 코드 지정 | Pro 표기 없음 | 공통 | B4 | 문서 |
| 커스텀 DDC 기능 | 사용자 정의 DDC 컨트롤 추가 및 편집 | Pro | 공통 | G23, B3 | 문서 |
| 통신 타이밍 설정 | 고급 DDC 통신 설정, dedicated queue 기본값(AS on, Intel off) | 무료 | 공통 | G23 | 문서 |
| 내장 HDMI DDC | M1 Mac과 보급형 M2 Mac mini의 내장 HDMI, 2018 Intel Mac mini 내장 HDMI 지원 | 무료 | 해당 모델 | B3 | 문서 |
| DisplayLink DDC와 색 제어 | 지원 범위 내 제공 | 무료 | 공통 | B3 | 문서 |
| Apple 디스플레이 DDC 차단 | Apple 디스플레이는 기본 DDC 비활성, Treat as generic third-party display 옵션 | 무료 | 공통 | G41 | 문서 |

- `vcp` 파라미터의 이름 목록 (출처 B4, 확인: 문서)
  - 지오메트리와 스캔: `horizontalFrequency`, `verticalFrequency`, `horizontalPosition`, `horizontalSize`, `horizontalPincushion`, `horizontalPincushionBalance`, `horizontalConvergenceRB`, `horizontalConvergenceMG`, `horizontalLinearity`, `horizontalLinearityBalance`, `verticalPosition`, `verticalSize`, `verticalPincushion`, `verticalPincushionBalance`, `verticalConvergenceRB`, `verticalConvergenceMG`, `verticalLinearity`, `verticalLinearityBalance`, `horizontalParallelogram`, `verticalParallelogram`, `horizontalKeystone`, `verticalKeystone`, `rotation`, `topCornerFlare`, `topCornerHook`, `bottomCornerFlare`, `bottomCornerHook`, `horizontalMirror`, `verticalMirror`, `displayScaling`, `scanMode`, `horizontalMoire`, `verticalMoire`, `clock`, `clockPhase`, `focus`, `adjustZoom`, `screenOrientation`
  - 창과 PIP: `windowPositionTopLeftX`, `windowPositionTopLeftY`, `windowPositionBottomRightX`, `windowPositionBottomRightY`, `windowBackground`, `windowControlOnOff`, `windowSelect`, `windowSize`, `windowTransparency`
  - 휘도와 색: `luminance`, `contrast`, `backlightControlLegacy`, `backlightLevelWhite`, `backlightLevelRed`, `backlightLevelGreen`, `backlightLevelBlue`, `videoGainRed`, `videoGainGreen`, `videoGainBlue`, `videoBlackLevelRed`, `videoBlackLevelGreen`, `videoBlackLevelBlue`, `colorSaturation`, `colorTemperatureIncrement`, `colorTemperatureRequest`, `selectColorPreset`, `colorPresetC`, `gamma`, `hue`, `sharpness`, `grayScaleExpansion`, `fleshToneEnhancement`, `userColorVisionCompensation`, `velocityScanModulation`, `blackStabilizer`, `autoColorSetup`, `sourceColorCoding`, `stereoVideoMode`, `tvBlackLevel`, `tvContrast`, `tvSharpness`
  - 6축 색상: `sixAxisHueControlBlue`, `sixAxisHueControlCyan`, `sixAxisHueControlGreen`, `sixAxisHueControlMagenta`, `sixAxisHueControlRed`, `sixAxisHueControlYellow`, `sixAxisSaturationControlBlue`, `sixAxisSaturationControlCyan`, `sixAxisSaturationControlGreen`, `sixAxisSaturationControlMagenta`, `sixAxisSaturationControlRed`, `sixAxisSaturationControlYellow`
  - LUT와 화면 순도: `blockLutOperation`, `lutSize`, `singlePointLutOperation`, `topLeftScreenPurity`, `topRightScreenPurity`, `bottomLeftScreenPurity`, `bottomRightScreenPurity`
  - 입력과 출력: `inputSelect`, `inputSelectAlt`, `outputSelect`, `tvChannelUpDown`
  - 오디오: `audioSpeakerVolume`, `speakerSelect`, `audioMicrophoneVolume`, `audioJackConnectionStatus`, `audioMuteScreenBlank`, `audioTreble`, `audioBass`, `audioBalanceLR`, `audioProcessorMode`
  - 전원과 상태: `powerMode`, `powerControl`, `auxiliaryPowerOutput`, `statusIndicator`, `displayUsageTime`, `ambientLightSensor`, `imageMode`, `displayApplication`, `osd`, `osdLanguage`
  - 식별과 제어: `vcpVersion`, `displayControllerId`, `displayFirmwareLevel`, `displayTechnologyType`, `flatPanelSubPixelLayout`, `displayDescriptorLength`, `transmitDisplayDescriptor`, `enableDisplayOfDisplayDescriptor`, `displayIdentificationOnDataOperation`, `applicationEnableKey`, `displayEnableKey`, `assetTag`, `auxiliaryDisplaySize`, `auxiliaryDisplayData`, `scratchPad`, `remoteProcedureCall`, `newControlValue`, `softControls`, `activeControl`, `performancePreservation`, `settings`, `degauss`, `autoSetup`, `autoSetupOnOff`, `unknown`
  - 초기화: `restoreFactoryDefaults`, `restoreFactoryLuminanceContrastDefaults`, `restoreFactoryGeometryDefaults`, `restoreFactoryColorDefaults`, `restoreFactoryTvDefaults`

#### 1.4.6 소프트웨어 디밍과 밝기

| 기능 | 내용 | 구분 | 플랫폼 | 출처 | 확인 |
| --- | --- | --- | --- | --- | --- |
| 밝기 제어 방식 자동 선택 | `brightness`: 사용 가능한 방식 중 자동 선택 | 무료 | 공통 | B4 | 문서 |
| 소프트웨어 디밍(색 테이블) | 색 테이블 기반 디밍, 완전 흑색까지 디밍 | 무료 | 공통 | B3 | 문서 |
| 소프트웨어 디밍(오버레이) | 오버레이 기반 디밍 | 무료 | 공통 | B3, G24 | 문서 |
| Combined brightness | 하드웨어와 소프트웨어 결합 밝기(`combinedBrightness`), 최소 허용 하드웨어 밝기 설정(PWM 회피 용도) | 무료(최소 하드웨어 밝기 설정은 Pro) | 공통 | B4, B9, G24 | 문서 |
| Apple 네이티브 밝기 | Apple 및 내장 디스플레이 하드웨어 밝기, `autoBrightness` | 무료 | 공통 | G9, B4 | 문서 |
| nits 표시 | 슬라이더와 OSD의 nits 표시, 수동 nits 범위 구성(하드웨어 최소, 최대, HDR 모드 SDR 피크, HDR 피크) | 표시 옵션 무료, OSD nits는 Pro | 공통 | G20, B3 | 문서 |
| nits 기반 CLI | `brightnessNits`, `softwareBrightnessNits`, `hardwareBrightnessNits` | Pro 표기 없음 | 공통 | B4 | 문서 |
| 주변광 표시 | `ambientLight`, Manage Display의 Ambient light level(lux) | CLI는 Pro 표기, 메뉴 표시는 무료 | 지원 센서 한정 | G9, B3, B4 | 문서 |
| 화면 보호기 및 잠금 시 디밍 | Dim display brightness on screen saver or lock | Pro | 공통 | G24 | 문서 |
| 시작과 깨어남 시 복원 | 밝기 복원, 과도 디밍 복원 방지 보호 | 무료 | 공통 | G25 | 문서 |
| 키보드 제어 | 네이티브 밝기 및 볼륨 키, 기본 커스텀 단축키(무료), 고급 단축키(Pro) | 혼합 | 공통 | B3 | 문서 |
| OSD | 네이티브 또는 커스텀 OSD, 서드파티 OSD 연동(MediaMate, DynamicLake, Alcove, Atoll) | 무료 | 공통 | B1, B3 | 문서 |

#### 1.4.7 색 프로파일, 색온도, 감마, 이미지 조정

| 기능 | 내용 | 구분 | 플랫폼 | 출처 | 확인 |
| --- | --- | --- | --- | --- | --- |
| 색 프로파일 선택 | ColorSync 프로파일 선택, 검사, Retouch a color profile 항목(상세 미확인), 팩토리 프로파일 일괄 제거 (`colorProfileURL`, `installedColorProfileURLs`, `colorProfileReset`) | 무료 | 공통 | G14, B4 | 문서 |
| 색 프로파일 즐겨찾기 | 5개 슬롯 | Pro | 공통 | G14, B10 | 문서 |
| 소프트웨어 대비 | `contrast` | 무료 | 공통 | B3, B4 | 문서 |
| 소프트웨어 gain, gamma | `gain`, `gamma`, `rGamma`, `gGamma`, `bGamma`, `rGain`, `gGain`, `bGain` | Pro | 색 테이블 지원 디스플레이 | B4 | 문서 |
| 색온도 | `temperature` | Pro | 공통 | B3, B4 | 문서 |
| 양자화 | `quantization` (표시 색 수 축소) | Pro | 공통 | B4, B9 | 문서 |
| 색 반전 | `inverted` | Pro 표기 없음 | 공통 | B4 | 문서 |
| 컴포지터 필터(v5) | 채도, 색조, 하이라이트, 섀도, vibrance, 세피아, 비네트, 가우시안 블러, 픽셀화, 샤픈, 언샤프 마스크, 노이즈 감소, 모션 블러, bloom, gloom, 모노크롬, thermal, X-Ray, median, comic 등 (`saturation`, `hue`, `filter...` 계열) | Pro | 공통 | B1, B4 | 문서 |
| 커스텀 3D LUT | 디스플레이 이미지 조정 및 PIP/스트림 필터에 3D LUT 적용 | Pro | 공통 | B1, B3 | 문서 |
| 프레임버퍼 색 매핑 | Standard, Inverted, Grayscale, Inverted Grayscale Appearance (`standardFramebuffer` 등). 저장 및 복원 없음 | 무료 | AS | G4, B4 | 문서 |
| GPU Dithering 토글 | `gpuDithering`, 디스플레이별 기억 및 복원 | 무료 | AS | G4, G44, B4 | 문서 |
| Uniformity Correction 토글 | 내장 디스플레이의 균일도 보정 | 무료 | AS | G4 | 문서 |
| Underscan | `underscan`, 네이티브 underscan 슬라이더 | 무료 | Intel 기본, AS는 강제 활성 옵션 | G13, G24, B4 | 문서 |
| 조정 일시 중지와 초기화 | `suspendImageAdjustments`, `resetColorAdjustments` | Pro 표기 없음 | 공통 | B4 | 문서 |
| 조정 방식 선택 | 색 테이블, 컴포지터 필터, 오버레이(Metal) 방식 선택과 호환 모드 | 무료 | 공통 | G24, G25, G45 | 문서 |
| 모서리 반경 | Top/Bottom Corner Radius 오버레이, 0-3% | 무료 | 공통 | G9 | 문서 |

#### 1.4.8 Connection mode (Color Mode)

| 기능 | 내용 | 구분 | 플랫폼 | 출처 | 확인 |
| --- | --- | --- | --- | --- | --- |
| Color Mode 메뉴 | 연결 비트 심도(내장 패널은 Internal), RGB 또는 YCbCr, chroma 샘플링(4:4:4, 4:2:2, 4:2:0), Full/Limited Range, SDR/HDR 태그 조합 목록. 선택 즉시 적용 | 무료(현재 SDR/HDR 인코딩 유지 범위) | AS | G4, G34 | 문서 |
| SDR/HDR 인코딩 변경 선택 | 현재 연결 인코딩과 다른 SDR/HDR 인코딩 행 선택, HDR 인코딩 간 전환 | Pro | AS | G4 | 문서 |
| 선호 모드 표시 | 시스템 선호 모드에 별 표시 (`preferredConnectionMode`) | 무료 | AS | G4, B4 | 문서 |
| CLI 지정 형식 | `connectionMode` 값: 모드 번호 또는 `bpc:[8\|10\|12\|16]+range:[limited\|full]+encoding:[rgb\|ycbcr]+chroma:[444\|422\|420]+hdrmode:[sdr\|hdr10\|dolby]`. 누락 요소는 현재 값 유지 | 무료 | AS, 네이티브 연결 | B4 | 문서 |
| 모드 목록 조회 | `connectionModeList`(현재 해상도, 주사율, HDR 상태 일치), `connectionModeListAll`(전체) | 무료 | AS | B4 | 문서 |
| Mixed Modes | 프레임버퍼 또는 Apple 프리셋의 SDR/HDR 구성과 불일치하는 연결 형식 노출 | Pro | AS | G4 | 문서 |
| Apple 프리셋 디스플레이 표기 | Preset HDR, Preset SDR 태그 | 무료 | AS | G4 | 문서 |
| 색 모드 보호 | Configuration Protection의 Color Mode, HDR Color Mode (`protectSDRColorMode`, `protectHDRColorMode`) | Pro | AS | G8, B4 | 문서 |
| Color Depth 메뉴 | 프레임버퍼 비트 심도 선택 (`colorDepth`) | 무료 | Intel 전용 메뉴 | G3, B4 | 문서 |
| 심도 불일치 안내 | 연결 심도가 프레임버퍼 심도보다 낮을 때 두 심도 표시와 temporal dithering 가능성 안내 | 무료 | AS | G4, G35 | 문서 |

#### 1.4.9 화면 회전

| 기능 | 내용 | 구분 | 플랫폼 | 출처 | 확인 |
| --- | --- | --- | --- | --- | --- |
| Screen Rotation | 0, 90, 180, 270도. macOS가 회전 지원을 보고하는 연결 디스플레이 대상 | 메뉴는 무료, CLI `rotation`은 Pro 표기 | 공통 | G5, B4 | 문서 |
| 회전 보호 | Configuration Protection의 Rotation | Pro | 공통 | G8 | 문서 |
| 스트림과 PIP 회전 | `rotateBy`, `flipHorizontal`, `flipVertical` (세로 Sidecar, 텔레프롬프터) | Pro | 공통 | B3, B4 | 문서 |

#### 1.4.10 미러링

| 기능 | 내용 | 구분 | 플랫폼 | 출처 | 확인 |
| --- | --- | --- | --- | --- | --- |
| 미러 대상 선택 | 소스 디스플레이 기준 대상 추가 및 제거, SOURCE, TARGET, VIRTUAL 배지, Stop Mirroring (`mirror`) | Pro | 공통 | G6, B4 | 문서 |
| 미러 구성 보호 | Configuration Protection의 Mirroring, Keep unmirrored | Pro | 공통 | G8 | 문서 |
| 미러 대상 해상도 변경 허용 | Allow resolution change for mirror target displays | 미확인 | 공통 | G1, G47 | 문서 |
| 가상 스크린 미러 수면 우회 | Use mirrored virtual screen sleep workaround | 무료 | AS | G28 | 문서 |

#### 1.4.11 레이아웃 (배치, 메인 디스플레이)

| 기능 | 내용 | 구분 | 플랫폼 | 출처 | 확인 |
| --- | --- | --- | --- | --- | --- |
| Arrange | 드래그 기반 시각적 배치, 가장자리 스냅, 정렬 가이드, Shift로 스냅 해제 | 무료(일부 고급 그리드 스냅은 Pro) | 공통 | G7, B3 | 문서 |
| Align | 기준 디스플레이 주변 16개 위치 중 선택 (`moveTo`: `topLeftCorner`, `topLeft`, `top`, `topRight`, `topRightCorner`, `leftTop`, `left`, `leftBottom`, `rightTop`, `right`, `rightBottom`, `bottomLeftCorner`, `bottomLeft`, `bottom`, `bottomRight`, `bottomRightCorner`) | Pro | 공통 | G7, B4 | 문서 |
| 좌표 배치 | `placement`: 전역 좌표 `XxY`, 논리 픽셀 | Pro 표기 없음 | 공통 | B4 | 문서 |
| 메인 디스플레이 지정 | Set as Main Display (`main`) | 무료(단축키는 Pro) | 공통 | G9, B4 | 문서 |
| 메인 상태 보호 | Configuration Protection의 Main Status (`protectAsMain`) | Pro | 공통 | G8, B4 | 문서 |
| 그룹 Layout Protection | 그룹 단위 배치 보호, adaptive layout anchors | Pro | 공통 | B1, B3, G7 | 문서 |
| 동일 디스플레이 교체 | `swapIdenticalDisplays` | Pro | 공통 | B4 | 문서 |
| 시각적 식별 | Identify Visually, 헤더 Option-클릭 | 무료 | 공통 | G9, G10 | 문서 |

#### 1.4.12 디스플레이 연결 해제와 재연결

| 기능 | 내용 | 구분 | 플랫폼 | 출처 | 확인 |
| --- | --- | --- | --- | --- | --- |
| 소프트 연결 해제 | 케이블 유지 상태로 데스크톱 레이아웃에서 제거 (`connected`). AS는 대기(standby) 진입, Intel은 완전 수면 미지원 | Pro(앱이 해제한 디스플레이의 재연결은 무료) | 공통 | G10, G22, B4 | 문서 |
| 헤더 스위치 동작 선택 | Connect/Disconnect, Screen Control, DDC Power Off, Disabled | 무료 | 공통 | G10 | 문서 |
| 외장 연결 시 내장 자동 해제 | Disconnect built-in display when an external display is connected | Pro | AS | G22 | 문서 |
| 자동 재연결 | 시작 시, 종료 시, 연결 디스플레이 0개 시 전체 자동 연결 | Pro | 공통 | G22 | 문서 |
| 깨어남 후 재해제 | Disconnect reconnected displays upon wake | Pro | 공통 | G22 | 문서 |
| 일괄 명령 | `disconnectAllButMain`, `connectAllDisplays`, Shift 조합 동작 | Pro | 공통 | G10, B4 | 문서 |
| 안전 규칙 | 최소 1개 물리 디스플레이 유지, iMac 내장 패널과 M3 기본형 내장 디스플레이 별도 override, Safe Mode | Pro | 공통 | G10, G22 | 문서 |
| 재초기화 | Reinitialize Display (`reinitialize`), 깨어남 또는 잠금 해제 시 재초기화, VMM7100 어댑터 리셋(`resetVMM7100`) | 무료 | AS | G9, G21, B4 | 문서 |
| 재감지 | `reconfigure` | Pro 표기 없음 | 공통 | B4 | 문서 |
| Sidecar 연결 | `sidecarList`, `sidecarConnected` | Pro 표기 없음 | 공통 | B4 | 문서 |
| 연결 중 수면 방지 | Prevent Sleep While Connected, 전역 Prevent Sleep | Pro | 공통 | G9, B3, B10 | 문서 |
| 연결 이벤트 명령 | 디스플레이별 연결, 해제, 수면, 깨어남 이벤트 명령 실행 | Wiki 비교표는 무료(B3), README는 per-display command integration에 Pro 필요 표기(B1) | 공통 | B1, B3 | 문서 |

#### 1.4.13 EDID 조회와 오버라이드

| 기능 | 내용 | 구분 | 플랫폼 | 출처 | 확인 |
| --- | --- | --- | --- | --- | --- |
| EDID 조회 | OS managed(권장) 또는 Direct I2C 방식, 읽기 길이 1-4096 바이트 (`osEDID`, `i2cEDID`) | 무료 | 공통 | G18, B4 | 문서 |
| EDID 해석 표시 | 버전, 디스플레이 이름, 벤더 및 모델 ID, 시리얼, 제조 연도와 주 | 무료 | 공통 | G18 | 문서 |
| EDID 표시 형식 | Base64, 16진수, C 배열, HEX 에디터 블록, 길이 | 무료 | 공통 | G18 | 문서 |
| EDID 내보내기 | 바이너리 파일 내보내기 | 무료 | 공통 | G18, B3 | 문서 |
| EDID 리포트 | `EDIDReport`: 식별, 타이밍, 색, CTA 확장, DisplayID 타이밍 및 tiled-display 디코딩, macOS 제공 EDID와 직접 읽기 비교 | 무료 | 공통 | B4, G37 | 문서 |
| 커스텀 EDID 불러오기 | 바이너리 파일 또는 Base64 붙여넣기. 개별 필드 편집 미지원 | 무료(저장 관리) | 공통 | G18, G38 | 문서 |
| 커스텀 EDID 적용 | Apply Custom EDID Now, Reset Factory EDID (Unapply). 디스플레이 메모리 미변경(휘발성 override) (`customEDID`, `applyCustomEDID`, `applyFactoryEDID`) | Pro | AS, 외장 디스플레이 | G9, G18, B4 | 문서 |
| 감지 시 자동 적용 | Automatically apply custom EDID upon detection (`autoApplyCustomEDID`) | Pro | AS | G18, B4 | 문서 |
| 식별자 연속성 유지 | Preserve continuity in case of an EDID display identity change, Restore factory EDID on quit | Pro | AS | G18 | 문서 |
| 모델 단위 EDID override | System Configuration의 Display EDID override, 다음 연결 또는 재시동 후 적용 | Pro | Intel | G19 | 문서 |
| EDID 장치 쓰기 | Write EDID to Device, 256바이트 이하, 위험 승인 필요, chunk 크기와 지연과 재시도 설정 | Pro | 공통(장치 지원 한정) | G18, G36 | 문서 |

#### 1.4.14 PIP와 스트리밍

| 기능 | 내용 | 구분 | 플랫폼 | 출처 | 확인 |
| --- | --- | --- | --- | --- | --- |
| PIP | 물리 디스플레이 또는 가상 스크린의 PIP 창 (`pip`) | Pro | 공통 | B3, B4 | 문서 |
| 전체 화면 로컬 스트리밍 | 다른 디스플레이로 스트림 (`stream`) | Pro | 공통 | B3, B4 | 문서 |
| 선택 창 스트리밍(v5) | 개별 창 또는 창 그룹 캡처 (`contentStreamWindow`), 크롭 편집 | Pro | 공통 | B1, B4, B10 | 문서 |
| Video Filter Window | 필터 전용 창 (`videoFilterWindow`) | Pro | 공통 | B3, B4 | 문서 |
| 변환 옵션 | `freeAspect`, `integerScaling`, `directPixelMapping`, `rotateBy`, `flipHorizontal`, `flipVertical`, `zoom`, `streamUnderscan`, `partial` 계열 크롭, `horizontalLocation`, `verticalLocation` | Pro | 공통 | B4 | 문서 |
| 창 옵션 | `alpha`, `priority`(`normal`, `topmost`, `absolute`, `absoluteLockScreen`), `unmovable`, `clickthrough`, `showTitlebar`, `showShadow`, `magnification`, `autoStart`, `cursorShown` | Pro | 공통 | B4 | 문서 |
| 목표 프레임 레이트 | `fpsTarget`: 0(무제한) 또는 1-200 | Pro | 공통 | B4 | 문서 |
| 비디오 필터 | `videoFilters`, `videoFilter`(밝기, 대비, 노출, 감마, 색온도, LUT, blend mode, photo effect 등), `renderHDR` | Pro | 공통(HDR 파이프라인은 AS) | B4, G46 | 문서 |
| 권한 | 스트리밍은 화면 기록 권한 필요, 미러링은 불필요 | 해당 없음 | 공통 | G6, G26 | 문서 |

#### 1.4.15 디스플레이 그룹과 동기화

| 기능 | 내용 | 구분 | 플랫폼 | 출처 | 확인 |
| --- | --- | --- | --- | --- | --- |
| 기본 그룹 밝기 동기화 | Default Group의 Brightness 동기화 | 무료 | 공통 | G29, B3 | 문서 |
| 커스텀 그룹 | 그룹 생성, 활성화(`enabled`, `active`), 활성화 정책(`activationPolicy`: `always`, `allMembersPresent`, `anyMembersPresent`, `anyTwoMembersPresent`, `anySyncSourceWithTargetMembersPresent`) | Pro | 공통 | B3, B4 | 문서 |
| 고급 동기화 | Brightness (Combined), Brightness (Hardware), Brightness (Software), 대비, 볼륨, 이미지 조정 동기화 (`synchronization`) | Pro | 공통 | G29, G15 | 문서 |
| nits 정규화 동기화 | Synchronize brightness nits | Pro | 공통 | G29, B3 | 문서 |
| UI scale matching | 그룹 내 UI 크기 일치, Match Group UI Scales (`uiScaleMatching`) | Pro | 공통 | G9, B4 | 문서 |
| 그룹 Layout Protection | `layoutProtection` | Pro | 공통 | B4 | 문서 |
| 소스와 대상 필터 | 외장 디스플레이, 메인 디스플레이 소스 필터, 목록 편집 | Pro | 공통 | G29 | 문서 |

#### 1.4.16 Night Shift, True Tone, 시스템 색

| 기능 | 내용 | 구분 | 플랫폼 | 출처 | 확인 |
| --- | --- | --- | --- | --- | --- |
| 시스템 색 토글 | Night Shift, True Tone, Dark Mode 토글 | 메뉴 토글 무료, CLI(`nightShift`, `trueTone`, `darkMode`)는 Pro 표기 | 공통 | G16, B4 | 문서 |
| Night Shift 강도 | Night Shift strength 슬라이더 (`nightShiftValue`) | Pro | 공통 | G16, B4 | 문서 |
| TV용 Night Shift | 디스플레이 역할을 Computer monitor로 변경. 관리자 인증과 재시동 필요 | 무료 | 네이티브 연결 한정 | B8, G19, B3 | 문서 |
| HDR 연동 해제 | HDR 진입 시 Night Shift와 True Tone 해제 및 복귀 시 복원 | Pro | 공통 | G4, G16 | 문서 |

#### 1.4.17 구성 보호 (Configuration Protection)

| 기능 | 내용 | 구분 | 플랫폼 | 출처 | 확인 |
| --- | --- | --- | --- | --- | --- |
| 보호 항목 | Resolution, Refresh Rate, Color Mode, HDR Color Mode, Rotation, Color Profile, HDR Color Profile, HDR Status, Mirroring, Main Status | Pro | 공통(Color Mode 계열은 AS) | G8 | 문서 |
| 동작 방식 | 스위치 켜는 시점의 값 캡처, 외부 변경 시 복원, 앱 내 변경은 저장값 갱신, 반복 충돌 시 일시 중단 | Pro | 공통 | G8 | 문서 |
| CLI | `protectResolution`, `protectRefreshRate`, `protectHDR`, `protectRotation`, `protectAsMain`, `protectSDRProfile`, `protectHDRProfile`, `protectSDRColorMode`, `protectHDRColorMode`, `protectAll` | Pro | 공통 | B4 | 문서 |

#### 1.4.18 네트워크 장치, HDMI-CEC, 오디오

| 기능 | 내용 | 구분 | 플랫폼 | 출처 | 확인 |
| --- | --- | --- | --- | --- | --- |
| HDMI-CEC 제어 | TV 볼륨, 음소거, 전원, 입력 선택 (`sendCEC`, `CECAddress`, `CECReport`). DisplayPort AUX DPCD CEC 터널링 경유 | 무료 | AS | B1, B4, G12 | 문서 |
| 네트워크 장치 제어 | LG webOS, Samsung Tizen, Philips Android TV, Yamaha AVR | 무료 | 공통 | B1, B3 | 문서 |
| 가상 리모컨 | `sendRemoteKey`, `remoteKeyList`, 플로팅 리모컨 창 | Pro 표기 없음 | 공통 | B4, B10 | 문서 |
| Software Audio(v5.2, 실험) | 드라이버 없는 소프트웨어 볼륨과 음소거, Combined Volume Control, 오디오 튜닝 | 기본 무료, 고급 튜닝 Pro | 공통 | B10, G30 | 문서 |

#### 1.4.19 디스플레이 정보 표시 항목

Display Information 리포트(설정 > Displays > 디스플레이 > Display Information). 조회와 내보내기는 무료. 출처 G17, B13, B14. 확인: 문서.

| 섹션 | 표시 항목 |
| --- | --- |
| Basic Display Information | 이름, 유형, 연결 상태(Connected, Disconnected, Soft-disconnected, Soft-disconnected (system)) |
| Identifiers | 앱 tag ID, 시리얼, 벤더, 모델, 제품명, 영숫자 시리얼, 제조일, 시스템 UUID, 물리 크기, registry location, Metal device, I2C service, DDC 메시징 방식, 현재 macOS display ID, 최초 및 최종 감지일 |
| Capabilities | 소프트웨어 제어, Apple 하드웨어 제어, 색 테이블 지원, DDC 호환 가능성, HiDPI, 회전, VRR, Apple 프리셋, 색 프로파일 지원, HDR 지원 및 상태, EDR 값, HDR 휘도, Horizontal GPU resolution limit, Allocation limits |
| Current Display Mode | 논리 및 픽셀 해상도, HiDPI, 비트 심도와 인코딩, native 및 default 플래그, 주사율과 VRR 범위, 모드 번호, row bytes, 밀도, unsafe 및 invalid 플래그 |
| Current/Preferred Display Mode (Connection Level) | 크기, 주사율과 VRR, 비트 심도, 색 모드, YCbCr, HDR/SDR, 색역, virtual 상태, 픽셀 종횡비, 선호 스케일, 최대 소스 크기와 대역폭 |
| XDR Configuration | 선택된 Apple 레퍼런스 프리셋 인덱스와 속성 |
| Color Profile Configuration | ColorSync 프로파일 속성 |
| Sidecar Configuration | 장치, 모델, 버전, 프레임 레이트, USB 또는 무선 링크 |
| Link Information | Estimated uncompressed payload, Display Stream Compression (DSC) 활성 여부, Estimated compressed payload, compression ratio, Connection type, Transmission mode(예: HBR3), Link rate(Gbps/lane), Lane count, Raw link bandwidth, Effective link bandwidth, Link encoding(예: 8b/10b), Downspread, HDCP 지원 프로토콜 버전, DPCD 수신기 능력값 |
| Link Information (DSC 활성 시) | DSC 버전, component 및 line-buffer 심도, target bits per pixel, picture 및 slice 크기, chunk 크기 |
| Link Information (DSC 비활성 시) | 수신기의 decompression 및 passthrough 능력, 형식, 심도, slice 수, 최대 slice 폭 |
| Link Information (타일링) | Display tiling, Tile size, Maximum hinted resolution, 픽셀 레이트 한계 |
| Display Adaptations | 모델별 adaptation 적용 상태와 버전 |

- 링크 속도와 DSC 표시 여부: 표시함. v5에서 추가 (B1의 "Expanded display diagnostics", B13). 확인: 문서
- 값의 성격: 보고값 또는 추정값. 케이블 품질 측정이나 처리량 벤치마크 아님 (G17, G51). 확인: 문서
- 데이터 출처에 대한 개발자 설명: "IOKit IOAV* calls and I/O Registry records" (B13), DSC 리포트의 Source 표기 "IOAVVideoInterfaceGetLinkData DSC PPS payload" (B14). 확인: 문서
- CLI 진단 리포트: `displayInformation`, `EDIDReport`, `DPCDReport`, `rawDPCD`, `DSCReport`, `CECReport`, `appleBrightnessReport`, `ddcCapabilities` (B4). DPCD, DSC, CEC 리포트는 AS 전용. 확인: 문서
- DPCD 리포트 예시 항목: DPCD revision, maximum link rate, maximum lane count, maximum downspread, main link channel coding(8b/10b, 128b/132b), downstream port count (B14). AllRez에서 착안했다는 개발자 표기 있음. 확인: 문서
- HDMI 케이블 상의 실시간 신호 캡처 및 분석: 미지원 (G33). 확인: 문서

#### 1.4.20 통합과 자동화

| 기능 | 내용 | 구분 | 출처 | 확인 |
| --- | --- | --- | --- | --- |
| CLI | 앱 번들 바이너리 직접 호출 또는 `betterdisplaycli`(Homebrew, MIT, Swift). 실행 중인 앱 프로세스 필요 | 접근 무료, Pro 기능 조작은 Pro | B4, B11 | 문서 |
| 커스텀 URL scheme | `BetterDisplay://operation?parameter=value`, x-callback-url, 토큰 옵션 | 접근 무료 | B4 | 문서 |
| HTTP | `http://<hostname>:55777/...`, 포트 변경, 토큰 옵션 | 접근 무료 | B4 | 문서 |
| DistributedNotificationCenter | 요청 `pro.betterdisplay.BetterDisplay.request`, 응답 `.response`, OSD `.osd`, `.launched`, `.terminated` | 무료 | B4 | 문서 |
| macOS Shortcuts | App Intents, 포인터 위치 또는 포커스 또는 메인 디스플레이 동적 대상(v5.2) | 접근 무료 | B4, B10 | 문서 |
| 내장 콘솔 | 앱 내 CLI 및 로그 콘솔(v5) | 무료 | B1, B3 | 문서 |
| 제어 통합 | 셸 스크립트, URL, 알림 기반 커스텀 컨트롤 | Pro(사용자 정의) | B3, B4 | 문서 |
| Raycast 확장 | 서드파티 확장 | 해당 없음 | B1 | 문서 |
| 설정 내보내기와 가져오기 | 앱 설정 export, import | 미확인 | B2 | 문서 |

### 1.5 CLI operation과 파라미터 목록

출처 B4(v5.0.6 기준 생성 도움말 텍스트). 확인: 문서. 최신 목록은 https://betterdisplay.pro/guide/integration/cli-reference/ (본문 대조 미실시).

- 구문: `BetterDisplay operation [operation] [-parameter[=value]]`, 단일 및 이중 하이픈 모두 허용
- Operation: `perform`, `set`, `get`, `toggle`, `feed`, `create`, `discard`, `help`, `exit`, `clear`
- 장치 식별: `tagID`, `UUID`, `displayID`, `name`, `nameLike`(`n`), `originalName`, `originalNameLike`, `productName`, `productNameLike`, `vendor`, `model`, `serial`, `alphanumericSerial`, `yearOfManufacture`, `weekOfManufacture`, `registryLocation`, `type`(`deviceType`: `Display`, `VirtualScreen`, `DisplayGroup`), `displayWithMouse`, `displayWithFocus`, `displayWithMainStatus`, `displayWithNonMainStatus`
- 값 지정: `value`, `offset`, `min`, `max`
- 밝기와 볼륨: `brightness`, `combinedBrightness`, `hardwareBrightness`, `softwareBrightness`, `brightnessNits`, `softwareBrightnessNits`, `hardwareBrightnessNits`, `ambientLight`, `autoBrightness`, `brightnessUpscaling`, `directBrightnessUpscaling`, `volume`, `mute`
- DDC: `hardwareContrast`, `redHardwareBlackLevel`, `greenHardwareBlackLevel`, `blueHardwareBlackLevel`, `redHardwareGain`, `greenHardwareGain`, `blueHardwareGain`, `ddc`, `ddcAlt`, `vcp`, `hardwareBacklight`, `hardwarePowerOff`, `hardwareFactoryReset`, `ddcCapabilities`, `ddcCapabilitiesString`
- 소프트웨어 이미지 조정: `gain`, `gamma`, `rGamma`, `gGamma`, `bGamma`, `rGain`, `gGain`, `bGain`, `temperature`, `quantization`, `contrast`, `underscan`, `gaussianBlur`, `saturation`, `hue`, `inverted`, `suspendImageAdjustments`, `resetColorAdjustments`
- 컴포지터 필터: `filterHighlight`, `filterShadow`, `filterVibrance`, `filterSepia`, `filterVignette`, `filterPixellateScale`, `filterCrystallizeRadius`, `filterHexagonalPixellate`, `filterPointillize`, `filterEdges`, `filterEdgeWorkRadius`, `filterCMYKHalftone`, `filterDotScreen`, `filterHatchedScreen`, `filterLineScreen`, `filterNoiseReduction`, `filterMotionBlur`, `filterUnsharpMask`, `filterSharpenLuminance`, `filterBloomIntensity`, `filterGloomIntensity`, `filterMonochrome`, `filterThermal`, `filterXRay`, `filterMedian`, `filterComic`
- 모드와 연결: `resolution`, `refreshRate`, `colorDepth`, `hiDPI`, `notch`, `displayModeNumber`, `displayModeList`, `refreshRateList`, `favoriteMode`, `saveFavoriteMode`, `connectionMode`, `connectionModeList`, `connectionModeListAll`, `preferredConnectionMode`, `hdr`, `rotation`, `gpuDithering`
- 프레임버퍼: `framebufferBoolProperty`, `framebufferNumericProperty`, `standardFramebuffer`, `invertedFramebuffer`, `grayscaleFramebuffer`, `invertedGrayscaleFramebuffer` (AS 전용)
- 색 프로파일과 프리셋: `colorProfileURL`, `colorProfileReset`, `installedColorProfileURLs`, `xdrPreset`, `xdrPresetReset`, `xdrPresetList`
- 배치와 미러: `placement`, `moveTo`, `main`, `mirror`, `swapIdenticalDisplays`
- 연결 관리: `connected`, `reinitialize`, `reconfigure`, `disconnectAllButMain`, `connectAllDisplays`, `resetVMM7100`, `sidecarList`, `sidecarConnected`
- 가상 스크린: `virtualScreenName`, `virtualScreenSerial`, `virtualScreenVendorNumber`, `virtualScreenModelNumber`, `aspectWidth`, `aspectHeight`, `sizeInch`, `multiplierStep`, `limitMultiplierSize`, `multiplierMinWidth`, `multiplierMinHeight`, `multiplierMaxWidth`, `multiplierMaxHeight`, `flipped`, `virtualScreenHiDPI`, `useResolutionList`, `resolutionList`
- 보호: `protectResolution`, `protectRefreshRate`, `protectHDR`, `protectRotation`, `protectAsMain`, `protectSDRProfile`, `protectHDRProfile`, `protectSDRColorMode`, `protectHDRColorMode`, `protectAll`
- EDID와 진단: `customEDID`, `applyCustomEDID`, `applyFactoryEDID`, `autoApplyCustomEDID`, `i2cEDID`, `osEDID`, `EDIDReport`, `rawDPCD`, `DPCDReport`, `CECReport`, `DSCReport`, `displayInformation`, `appleBrightnessReport`, `identifier`, `identifiers`
- 장치 제어: `control`, `sendRemoteKey`, `sendRemoteKeyPress`, `sendRemoteKeyRelease`, `remoteKeyList`, `changeInputSource`, `inputSourceList`, `configuredControllerList`, `sendCEC`, `CECAddress`
- 스트림과 PIP: `stream`, `pip`, `videoFilterWindow`, `contentStreamWindow`, `addConfiguration`, `removeConfiguration`, `freeAspect`, `integerScaling`, `directPixelMapping`, `rotateBy`, `flipHorizontal`, `flipVertical`, `horizontalLocation`, `verticalLocation`, `cursorShown`, `streamUnderscan`, `zoom`, `videoFilters`, `videoFilter`, `renderHDR`, `alpha`, `fpsTarget`, `partial`, `partialOriginX`, `partialOriginY`, `partialWidth`, `partialHeight`, `resume`, `priority`, `unmovable`, `clickthrough`, `showTitlebar`, `showShadow`, `excludePipWindow`, `magnification`, `autoStart`, `originX`, `originY`, `width`, `height`
- 대상 지정: `specifier`, `targetTagID`, `targetUUID`, `targetDisplayID`, `targetName`(`targetN`), `targetNameLike`, `targetOriginalName`, `targetOriginalNameLike`, `targetSelf`
- 그룹: `enabled`, `active`, `activationPolicy`, `synchronization`, `layoutProtection`, `uiScaleMatching`
- 시스템: `nightShiftValue`, `nightShift`, `trueTone`, `darkMode`, `disableNightShiftInHDR`
- 앱: `proAvailable`, `osdShowBasic`, `osdShowCustom`, `osdIntegrationNotification`, `appMenu`, `settingsWindow`, `consoleLog`, `restartApp`, `quitApp`, `appMenuIcon`
- `videoFilter` 값 목록: `blendMode`, `blendModeEnabled`, `blendStrength`, `bloomIntensity`, `brightness`, `cmykHalftone`, `colorPosterize`, `comic`, `contrast`, `crystallizeRadius`, `dotScreen`, `edgeWorkRadius`, `edges`, `exposure`, `gamma`, `gaussianBlur`, `gloomIntensity`, `hatchedScreen`, `hexagonalPixellate`, `highlight`, `hue`, `invert`, `lineScreen`, `median`, `monochrome`, `motionBlur`, `noiseReduction`, `photoEffect`, `photoEffectEnabled`, `pixellateScale`, `pointillize`, `saturation`, `sepia`, `shadow`, `sharpenLuminance`, `temperature`, `thermal`, `unsharpMask`, `vibrance`, `vignette`, `xRay`, `custom:<name>`
- `sendCEC` 값 목록: `volumeUp`, `volumeDown`, `mute`, `standby`, `wake`, `input`, `select`, `up`, `down`, `left`, `right`, `rootMenu`, `setupMenu`, `contentsMenu`, `exit`

### 1.6 무료와 Pro 구분 요약

출처 B3(v5 기준 비교표), G30. 확인: 문서.

- 무료 기능
  - GUI, 다중 밝기 제어 방식, 네이티브 밝기 및 볼륨 키, 기본 커스텀 단축키, 네이티브 또는 커스텀 OSD
  - 색 테이블 디밍, 오버레이 디밍, 하드웨어와 소프트웨어 결합 디밍, 완전 흑색 디밍
  - DDC 밝기, 대비, 볼륨, RGB gain, 입력 전환, 입력 커스터마이즈, 전원 제어, capabilities 탐지 및 자동 구성
  - AS 및 Intel 연결 DDC, M1 Mac과 보급형 M2 Mac mini 내장 HDMI DDC, 2018 Intel Mac mini 내장 HDMI DDC, DisplayLink DDC와 색 제어
  - LG webOS, Samsung Tizen, Philips Android TV, Yamaha AVR 제어, HDMI-CEC 제어
  - 표준 제어 통합(스크립트, URL, 알림), CLI, HTTP, URL scheme, Shortcuts, 내장 콘솔, 외부 HUD 및 notch 앱 연동
  - 커스텀 스케일 해상도 편집, 디스플레이 이름 override, 네이티브 및 기본 해상도 override, TV용 Night Shift
  - 가상 스크린 생성, 가상 스크린과 디스플레이 연관
  - Display mode selector, Refresh rate selector, AS 추가 및 NTSC 주사율, AS 색 모드 선택, 해상도 슬라이더
  - 소프트웨어 대비, EDID 조회 및 내보내기, 색 프로파일 및 XDR 프리셋 선택
  - 기본 밝기 동기화, 시각적 디스플레이 배치, 연결 이벤트 액션, 확장 디스플레이 정보 및 진단 리포트, 주변광 표시
- Pro 기능
  - Flexible HiDPI scaling, 디스플레이 연결 및 연결 해제, Display configuration protection, 미러링 구성 및 보호
  - 색 테이블 XDR/HDR 업스케일(AS), Metal XDR/HDR 업스케일, Direct XDR 업스케일, HDR extra-brightness 보정, 서드파티 HDR 업스케일, OSD의 nits 표시
  - 고급 소프트웨어 색 조정, 소프트웨어 색온도, 확장 컴포지터 필터, 커스텀 3D LUT
  - PIP, Video Filter Window, 전체 화면 스트리밍, 선택 창 스트리밍, 스트림 변환(늘이기, 위치, 회전, 크롭, 반전), 목표 프레임 레이트
  - 커스텀 가상 스크린 구성, HDR 및 고주사율 가상 스크린
  - AS 및 Intel EDID override, SDR과 HDR 간 색 프로파일 자동 전환, Forced HDR
  - 커스텀 디스플레이 그룹, 고급 밝기 및 이미지 조정 동기화, nits 정규화 동기화, 해상도 동기화 및 UI scale matching, adaptive layout protection
  - 고급 커스텀 단축키, 사용자 정의 통합 및 DDC 컨트롤, 지정 디스플레이 연결 중 시스템 수면 방지
- 주석
  - CLI, 콘솔, HTTP, URL scheme, Shortcuts 접근 자체는 무료. Pro 기능 조작은 Pro 필요
  - 체험 기간 중 무료 모드 확인 방법: Settings > Application > Advanced Settings & Privacy > Licensing & Pro Features 끄기

### 1.7 Apple Silicon 제약 표

| 항목 | 제약 내용 | 우회 수단(문서 기재) | 출처 | 확인 |
| --- | --- | --- | --- | --- |
| 임의 커스텀 타이밍 즉시 활성화 | 불가. 개발자 답변: 임의 타이밍을 즉시 활성화할 수 없음. EDID에 근거해 인식된 타이밍과 색 모드 조합만 `connectionModeListAll`로 조회 후 `connectionMode`로 활성화 가능 | 커스텀 EDID로 타이밍 추가. macOS 디스플레이 프로세서의 수용이 전제 | B12 | 문서 |
| 타이밍 필드 편집 | 앱 내 EDID 필드 편집기 없음. 외부 EDID 편집기로 준비한 바이너리만 가져오기 가능 | 외부 EDID 편집기 | G38 | 문서 |
| DSC 강제 설정 또는 해제 | 제어 기능 문서 없음. DSC는 Link Information, `DSCReport`의 보고 대상 | 없음 | G17, G50, B4 | 미확인(제어 기능 부재는 문서 범위 내 확인, 기술적 가능 여부는 미확인) |
| EDID override 적용 범위 | 외장 디스플레이 한정, framebuffer communication service 접근 필요, 내장 Apple 디스플레이는 비활성. DisplayLink 등 타 앱 관리 가상 디스플레이는 조회와 편집 불가 | 없음 | G9, G18 | 문서 |
| EDID override 지속성 | 휘발성(live) override. 디스플레이 메모리 미변경. 재감지 시 재적용 옵션 필요. 식별자 변경 시 macOS가 다른 디스플레이로 인식 | Automatically apply custom EDID upon detection, Preserve continuity 옵션 | G18, G54 | 문서 |
| EDID override 수용 여부 | 커스텀 EDID 내 모든 타이밍과 기능을 Mac이 지원한다는 보장 없음 | 없음 | G37, G38 | 문서 |
| EDID 장치 쓰기 | 256바이트 제한, 대부분의 모니터가 쓰기 제한. 전송 성공 메시지가 저장 성공을 뜻하지 않음 | EDID 에뮬레이터 등 쓰기 허용 장치 | G18, G36 | 문서 |
| HiDPI 수평 해상도 상한 | 보급형 M1/M2: 6K(6144px, HiDPI 3072px). M1/M2 Pro/Max/Ultra: 8K(7680px, HiDPI 3840px). Wiki v2.2.3 기준 수치 | 가상 스크린의 8K 초과 옵션. Catalyst 앱 충돌 가능성 경고 | B5 | 문서(최신 칩 수치는 미확인) |
| HiDPI 렌더링 한계 조회 | Display Information의 Horizontal GPU resolution limit, Allocation limits로 확인. Mac, 연결, 배치, macOS에 따라 변동 | 낮은 HiDPI 크기 선택, 다른 포트 비교 | G31 | 문서 |
| Flexible scaling 최대 크기 | 스케일(HiDPI) 데스크톱 크기는 네이티브 해상도 초과 불가 | 가상 스크린 미러 또는 스트림 | B5, G53 | 문서 |
| Flexible scaling 적용 절차 | 시스템 override 설치, 관리자 인증, 활성화 또는 재시동 필요. 동일 벤더 및 모델 ID의 모든 디스플레이에 적용 | 없음 | G19, B5 | 문서 |
| 저해상도 HiDPI 모드 | 매우 낮은 세로 크기의 HiDPI 모드는 macOS가 거부 후 즉시 복귀. 720p 미만은 기본 숨김 | Enable lower than 720p resolutions | G31 | 문서 |
| HiDPI와 주사율 | 스케일 HiDPI 데스크톱에서 사용 가능한 주사율 감소 가능 | 낮은 HiDPI 크기, 연결 수준 주사율 선택 | G43 | 문서 |
| 연결 수준 추가 주사율 | 이후 모드 변경 시 유지되지 않음. macOS 설정 표시값과 불일치. 큰 HiDPI 렌더링 표면과 조합 시 아티팩트 또는 불안정 가능 | Configuration Protection(Pro) | G2, G42 | 문서 |
| 프레임버퍼 색 심도 선택 | Color Depth 메뉴는 Intel 전용. AS는 연결 형식(Color Mode)으로 대체 | Color Mode 메뉴 | G3, G4 | 문서 |
| 색 모드 선택 범위 | 현재 해상도와 주사율에서 연결이 제공하는 형식만 선택 가능. 보호 없이는 재연결이나 모드 전환 후 유지 미보장 | 주사율 낮춰 재조회, Color Mode 보호(Pro) | G4, G34 | 문서 |
| Mixed Modes와 Forced HDR | 빈 화면, 녹색 화면, 이미지 손상 위험 | 물리 재연결 | G4 | 문서 |
| 연결 모드 변경 위험 | `connectionMode` 변경은 위험 작업으로 표기. 미지원 타이밍 선택 시 대상 화면 공백 | 복구용 화면 유지 | B4, G32 | 문서 |
| 640x480 등 저해상도 신호 | 연결 모드 전환으로 신호 선택 가능. 데스크톱이 신호보다 크면 잘림 | PIP 또는 스트림 배치(Pro) | G32 | 문서 |
| 네이티브 underscan | Intel 경로 기본. AS는 강제 활성 옵션, 지원 보장 없음. 현재 값 read-back 없음 | Force-enable underscan slider | G13, G24 | 문서 |
| 소프트 연결 해제 | iMac 내장 패널과 M3 기본형 내장 디스플레이는 별도 안전 override 필요. 일부 디스플레이는 대기 진입 실패. 재연결 실패 시 물리 재연결 또는 덮개 여닫기 | 안전 override, 자동 재연결 | G10, G22 | 문서 |
| 가상 스크린 미러 | 수면 문제, 색 문제(일부 구성 깜박임), 마우스 커서 문제 | Flexible scaling 우선 사용, sleep workaround 옵션 | B5, B9, G28 | 문서 |
| DisplayLink 디스플레이 | Flexible scaling, System Configuration, EDID 기능 미적용. 드라이버 관리 가상 경로 | 네이티브 연결, 가상 스크린 미러 또는 스트림 | G19, G39 | 문서 |
| DDC 경로 | 독이나 어댑터가 DDC 미전달 가능. read-back과 write 지원 여부가 서로 다를 수 있음 | 직접 연결 비교, capabilities 재탐지 | G40, G23 | 문서 |
| Apple 디스플레이 DDC | 기본 차단. 구형 Apple 디스플레이에서 영구 문제 가능성 경고 | Treat as generic third-party display | G41 | 문서 |
| GPU 디더링 | GPU 측 디더링만 토글 가능. 모니터 내부 디더링은 제어 대상 아님 | 8비트 연결 형식 선택 | G44, B9 | 문서 |
| 색 테이블 조정 호환성 | M5 Pro, M5 Max, MacBook Neo에서 소프트웨어 색 조정 오동작 사례 FAQ 존재 | 색 테이블 제어 끄기(호환 모드) | G45 | 문서 |
| Night Shift | 네이티브 연결 디스플레이 한정. Television 역할, DisplayLink, Sidecar 제외 | 디스플레이 역할 편집, Metal 색온도 조정 | B8, G19 | 문서 |
| Direct XDR 업스케일 | 내장 Apple XDR 디스플레이 한정. 외장 Studio Display XDR, Pro Display XDR 미지원. macOS 26.3 이상 | 색 테이블 업스케일 | B7 | 문서 |
| HDMI 신호 분석 | HDMI 케이블 상의 실시간 트래픽 캡처 및 분석 불가 | Display Information, CEC 리포트 | G33 | 문서 |
| 링크 정보 해석 | 수신기 최대값은 현재 연결의 사용값을 뜻하지 않음. DSC 지원 보고와 현재 모드의 DSC 사용 확인은 별개 | 없음 | G17, G50 | 문서 |
| DisplayPort MST 관련 제약 | 열람 문서 범위 내 기재 없음 | 해당 없음 | 해당 없음 | 미확인 |

## 2. WhatCable

### 2.1 제품 개요

| 항목 | 내용 | 출처 | 확인 |
| --- | --- | --- | --- |
| 형태 | 메뉴 막대 앱(SwiftUI popover), Dock 앱 모드, WidgetKit 위젯, 번들 CLI | W1 | 문서 |
| 목적 | Mac에 연결된 USB-C 케이블의 실제 능력과 충전 저속 원인 설명 | W1 | 문서 |
| 지원 환경 | macOS 14 이상, Apple Silicon 전용. 사유: Intel Mac은 USB-C 포트 컨트롤러 서비스가 비어 있음(커뮤니티 진단 자료 기준) | W1 | 문서 |
| 가격 | 무료 오픈 소스. WhatCable Pro 9.99 GBP 일회 구매, Mac 2대 | W1 | 문서 |
| 배포 | Developer ID 서명 및 공증, Homebrew cask, CLI 전용 formula. Mac App Store 미배포(SMC 접근과 CLI 설치 모델 사유) | W1 | 문서 |
| 최신 버전 | v1.5.0 (2026-10-13) | W3 | 문서 |
| 모듈 구조 | WhatCable(UI), WhatCableCore(진단 로직, PD 디코딩), WhatCableDarwinBackend(IOKit watcher), WhatCableAppKit(플러그인 확장점), WhatCablePlugins(Pro), WhatCableWidget, WhatCableCLI | W1 | 문서 |

### 2.2 출처 목록

소스 경로 접두사: `https://github.com/darrylmorley/whatcable/blob/main/` (조사 시점 커밋 58e588a)

| 키 | 문서 또는 파일 | URL 또는 경로 |
| --- | --- | --- |
| W1 | README | https://github.com/darrylmorley/whatcable |
| W2 | LICENSE | https://github.com/darrylmorley/whatcable/blob/main/LICENSE |
| W3 | 릴리스 | https://github.com/darrylmorley/whatcable/releases |
| W4 | HPM 포트 컨트롤러 클래스 | Sources/WhatCableDarwinBackend/Watchers/HPMPortControllerClasses.swift |
| W5 | HPM watcher | Sources/WhatCableDarwinBackend/Watchers/AppleHPMInterfaceWatcher.swift |
| W6 | HPM 모델 | Sources/WhatCableCore/Port/AppleHPMInterface.swift |
| W7 | TypeC PHY watcher | Sources/WhatCableDarwinBackend/Watchers/AppleTypeCPhyWatcher.swift |
| W8 | TypeC PHY 모델 | Sources/WhatCableCore/Port/AppleTypeCPhy.swift |
| W9 | DisplayPort transport watcher | Sources/WhatCableDarwinBackend/Watchers/DisplayPortTransportWatcher.swift |
| W10 | DisplayPort transport 모델 | Sources/WhatCableCore/Display/IOPortTransportStateDisplayPort.swift |
| W11 | 디스플레이 타이밍 reader | Sources/WhatCableDarwinBackend/Reading/DisplayTimingReader.swift |
| W12 | 디스플레이 모드 reader | Sources/WhatCableDarwinBackend/Reading/DisplayModeReader.swift |
| W13 | 디스플레이 진단 | Sources/WhatCableCore/Display/DisplayDiagnostic.swift |
| W14 | DP lane 구성 | Sources/WhatCableCore/Display/DisplayPortLaneConfig.swift |
| W15 | TRM transport watcher | Sources/WhatCableDarwinBackend/Watchers/TRMTransportWatcher.swift |
| W16 | USB3 transport watcher | Sources/WhatCableDarwinBackend/Watchers/USB3TransportWatcher.swift |
| W17 | USB-PD SOP watcher | Sources/WhatCableDarwinBackend/Watchers/USBPDSOPWatcher.swift |
| W18 | VDM identity watcher | Sources/WhatCableDarwinBackend/Watchers/VDMIdentityWatcher.swift |
| W19 | 전원 소스 watcher | Sources/WhatCableDarwinBackend/Watchers/PowerSourceWatcher.swift |
| W20 | 포트 진단 watcher | Sources/WhatCableDarwinBackend/Watchers/PortDiagnosticsWatcher.swift |
| W21 | Thunderbolt switch watcher | Sources/WhatCableDarwinBackend/Watchers/IOThunderboltSwitchWatcher.swift |
| W22 | Thunderbolt 링크 모델 | Sources/WhatCableCore/Thunderbolt/IOThunderboltLink.swift |
| W23 | USB watcher | Sources/WhatCableDarwinBackend/Watchers/USBWatcher.swift |
| W24 | 액체 감지 watcher | Sources/WhatCableDarwinBackend/Watchers/LiquidDetectionWatcher.swift |
| W25 | SMC reader | Sources/WhatCableDarwinBackend/Reading/SMCPowerReader.swift |
| W26 | 배터리 reader | Sources/WhatCableDarwinBackend/Reading/AppleSmartBatteryReader.swift |
| W27 | 데이터 링크 진단 | Sources/WhatCableCore/USB/DataLinkDiagnostic.swift |
| W28 | 충전 진단 | Sources/WhatCableCore/Power/ChargingDiagnostic.swift |
| W29 | 영어 문자열 리소스 | Sources/WhatCableCore/Resources/en.lproj/Localizable.strings |
| W30 | Apple UVDM watcher | Sources/WhatCableDarwinBackend/Watchers/AppleUVDMWatcher.swift |
| W31 | HPM 포트 UUID 맵 | Sources/WhatCableDarwinBackend/Reading/HPMPortUUIDMap.swift |

### 2.3 표시 항목

| 항목 | 내용 | 구분 | 출처 | 확인 |
| --- | --- | --- | --- | --- |
| 포트별 헤드라인 | Thunderbolt / USB4, USB device, Display connected, Charging only, Slow USB / charge-only cable, Nothing connected | 무료 | W1 | 문서 |
| 충전 진단 배너 | 케이블 제한, 충전기 제한, Mac 요청 전력, 정상, 배터리 만충 구분 | 무료 | W1, W28 | 문서, 소스 |
| 세션 중 장애 경고 | 포트 장애 카운터 기반 과전류, 연결 끊김 후 복귀 경고 | 무료 | W1, W20 | 문서, 소스 |
| 데이터 속도 진단 | Mac 포트, 케이블, 장치 중 제한 요소 판정 | 무료 | W1, W27 | 문서, 소스 |
| 케이블 e-marker 정보 | 속도(USB 2.0, 5, 10, 20, 40, 80 Gbps), 전류 정격(3 A, 5 A, 60W, 100W, 240W), 칩 벤더 | 무료 | W1 | 문서 |
| USB-IF 인증 | 케이블의 XID를 번들 인증 목록과 대조, 네트워크 조회 없음 | 무료 | W1 | 문서 |
| 케이블 신뢰 신호 | VID 0, 예약 비트 패턴, USB-IF 목록에 없는 VID 표시. 판정이 아닌 참고 정보 | 무료 | W1 | 문서 |
| 충전기 PDO 목록 | 충전기가 광고하는 전압 프로파일 전체, 현재 협상된 프로파일 강조 | 무료 | W1, W19 | 문서, 소스 |
| 연결 장치 식별 | PD Discover Identity 응답 기반 벤더명과 제품 유형 | 무료 | W1, W18 | 문서, 소스 |
| 연결 장치 트리 | 허브 체인 구조 표시, 허브 기본 숨김, USB 컨트롤러별 그룹 | 무료 | W1, W23 | 문서, 소스 |
| Thunderbolt fabric | lane별 속도, 세대(TB3, TB4, TB5), 다중 홉 스위치 토폴로지, 활성 터널 | 무료 | W1, W21, W22 | 문서, 소스 |
| 케이블 식별 | e-marker 지문과 번들 DB 대조, 브랜드 및 모델 표시 | 무료 | W1 | 문서 |
| 활성 transport | USB 2, USB 3, Thunderbolt, DisplayPort | 무료 | W1, W6 | 문서, 소스 |
| DisplayPort alt mode lane 구성 | 4 DP lanes 또는 2 DP lanes + USB3 구분. USB3 동시 활성 여부로 판정 | 무료 여부 미확인 | W14 | 소스 |
| 원시 IOKit 속성 표시 | Option-클릭 또는 설정 토글 | 무료 | W1 | 문서 |
| 위젯 | small, medium, large WidgetKit 위젯 | 무료 | W1 | 문서 |
| 케이블 이력 | 케이블 저장, 재연결 인식, 협상 이력 타임라인 | Pro | W1 | 문서 |
| 전력 모니터 | 실시간 전력 측정, PD contract 검사, 시스템 전력 입력 그래프 | Pro | W1 | 문서 |
| Negotiation Diagnostics | Mac 포트, 케이블, 장치의 지원값과 협상값 비교, e-marker와 Thunderbolt 컨트롤러 교차 검증 | Pro | W1 | 문서 |
| Display Diagnostics | 모니터의 현재 디스플레이 모드와 DisplayPort 링크 전송 능력 비교, 5K 및 6K 실제 해상도 표시, DSC 사용 시 최상 모드 도달 확인, 체인 내 HDMI 또는 DisplayPort 어댑터 표시 | Pro | W1, W13 | 문서, 소스 |
| 포트 상태 | 포트 health 카운터, 케이블 저항 추정, 핀 다이어그램, 액체 감지 상태 | Pro | W1, W24 | 문서, 소스 |
| 알림 | 케이블 연결 및 해제, 앱 업데이트 알림 | 무료 | W1 | 문서 |

### 2.4 진단 문구 생성 방식

| 항목 | 내용 | 출처 | 확인 |
| --- | --- | --- | --- |
| 방식 | 규칙 기반. 진단별 구조체가 `Bottleneck` 열거형과 수치를 보유, `summary`와 `detail` 문자열 생성. 언어 모델 사용 흔적 없음 | W13, W27, W28 | 소스 |
| 진단 종류 | `ChargingDiagnostic`(전력), `DataLinkDiagnostic`(데이터 속도), `DisplayDiagnostic`(디스플레이) 3종. 동일한 형태로 설계했다는 주석 | W13, W27, W28 | 소스 |
| 충전 판정 분류 | `noCharger`, `chargerLimit`, `cableLimit`, `macLimit`, `fine`, `standbyCharger`. 입력: 충전기 출력, 케이블 정격, 협상된 PDO. 경고 대상은 충전기보다 낮은 케이블 정격 | W28 | 소스 |
| 데이터 판정 분류 | `fine`, `cableLimit`, `hostLimit`, `deviceLimit`, `degraded`, `unknownCable`, `cableContradictsActive`. 입력: Mac 포트, 케이블, 장치의 능력값과 협상 속도 | W27 | 소스 |
| 디스플레이 판정 분류 | `fine`, `belowMonitorMax`, `adapterLimit`, `unknownMode`, `compressionActive` | W13 | 소스 |
| 디스플레이 판정 근거 | macOS 디스플레이 노드의 타이밍 목록을 근거로 사용. DSC 여부는 `DSCRequiredColorElementIDs`가 현재 색 모드를 포함하는지로 판독, 대역폭 계산 추론 아님. 대역폭 계산은 교차 검증값으로만 병기 | W11, W13 | 소스 |
| 전달 능력 수치 | 현재 링크 상태(`laneCount` x rate)의 스냅샷만 사용. 모드 변경에 따른 링크 재학습 여부는 미측정이라는 주석 | W13 | 소스 |
| 문구 원칙 | 비난형 표현 회피. 근거가 없으면 사실만 보고(`unknownMode`). Apple 디스플레이의 DSC는 링크 탓으로 표현하지 않음(Apple 디스플레이는 EDID 바이트 8-9가 0x0610인 경우로 판별) | W10, W13 | 소스 |
| 지역화 | `String(localized:)`와 `Localizable.strings` 사용. 영어 원문이 키. 한국어 포함 19개 언어 리소스 | W29, W1 | 소스, 문서 |
| 문구 예시 | "Display running compressed (DSC) to fit through the link", "Cable is limiting charging speed", "Charging well at 96W" | W29, W1 | 소스, 문서 |

### 2.5 데이터 소스

README 기재: IOKit 서비스 4계열 읽기, entitlement 없음, private API 없음, helper daemon 없음 (W1, 확인: 문서). 아래 클래스명과 키는 소스 코드의 문자열 리터럴을 그대로 인용 (확인: 소스).

#### 2.5.1 IOKit 클래스명

| 용도 | 클래스명 | 비고 | 출처 |
| --- | --- | --- | --- |
| 포트 컨트롤러 | `AppleHPMInterfaceType10`, `AppleHPMInterfaceType11`, `AppleHPMInterfaceType12`, `AppleHPMInterfaceType18`, `AppleTCControllerType10`, `AppleTCControllerType11`, 추가 catch-all `IOPort` | Type12는 수집 자료에서 미관측이라는 주석. Type18은 A18 Pro 기기. README 기준 TCController는 M1 및 M2, HPMInterface Type10-12는 M3 세대 | W4, W5, W1 |
| 포트 UUID 매핑 | `AppleHPMDeviceHALType3` | SMC 조인 키용 | W31 |
| USB-C PHY | `AppleTypeCPhy` (기반 클래스 매칭) | 칩별 leaf 클래스 예: `AppleT8132TypeCPhy`, `AppleT6040TypeCPhy`. PHY당 1개 인스턴스 | W7, W8 |
| DisplayPort transport | `IOPortTransportStateDisplayPort` | 추가 및 제거 알림 등록 | W9 |
| 기타 transport 상태 | `IOPortTransportStateUSB2`, `IOPortTransportStateUSB3`, `IOPortTransportStateCIO`, `IOPortTransportStateCC` | TRM 속성 감시 대상은 USB2, DisplayPort, USB3, CIO 4개 클래스 | W15, W16, W17 |
| USB-PD 식별 | `IOPortTransportComponentCCUSBPDSOP`, `IOPortTransportComponentCCUSBPDSOPp`, `IOPortTransportComponentCCUSBPDSOPpp` | SOP(포트 파트너), SOP'(케이블 근단 e-marker), SOP''(원단 e-marker) | W17, W18, W1 |
| Apple 액세서리 식별 | `IOPortTransportProtocolAppleUVDM` | | W30 |
| 전원 소스 | `IOPortFeaturePowerSource` | PDO 목록과 선택된 PDO | W19 |
| 디스플레이 노드 | `AppleCLCD2`, `IOMobileFramebufferShim` | 주석 기준 `AppleCLCD2`는 M1 계열, M2, M3. `IOMobileFramebufferShim`은 M2 Pro/Max/Ultra, M3 Pro/Max, M4 및 M5 전 기종 | W11 |
| Thunderbolt | `IOThunderboltSwitch`, `IOIOThunderboltSwitch` | 두 이름 모두 매칭 | W21 |
| USB | `IOUSBHostDevice`, `IOUSBHostInterface`, `AppleUSBHostBillboardDevice` | | W23 |
| 액체 감지 | `AppleHPMLDCMType2` | | W24 |
| 전력 측정 | `AppleSMC`, `AppleSmartBattery` | SMC 접근은 Pro 전력 측정용 | W25, W26, W1 |

#### 2.5.2 프로퍼티 키

| 대상 | 키 | 출처 |
| --- | --- | --- |
| 포트 컨트롤러(HPM) | `PortType`, `PortTypeDescription`, `PortDescription`, `PortNumber`, `ConnectionActive`, `ActiveCable`, `OpticalCable`, `IOAccessoryUSBActive`, `IOAccessoryUSBSuperSpeedActive`, `IOAccessoryUSBModeType`, `IOAccessoryUSBConnectString`, `TransportsSupported`, `TransportsActive`, `TransportsProvisioned`, `PlugOrientation`, `Plug Event Count`, `ConnectionCount`, `Overcurrent Count`, `Pin Configuration`, `DisplayPortPinAssignment`, `IOAccessoryPowerCurrentLimits`, `FW Version`, `Boot Flags`, `LDCM_StateDescription`, `FeaturesEnabled`, `IOAccessoryPowerMode`, `IOAccessoryActivePowerMode`, `ConnectionUUID`, `UUID` | W6 |
| 포트 판별 조건 | `PortTypeDescription`이 `USB-C` 또는 `MagSafe` 접두, 서비스 이름이 `Port-` 접두 | W6 |
| transport 문자열 값 | `USB2`, `USB3`, `USB4`, `CIO`, `DisplayPort` | W6 |
| USB-C PHY | `AppleTypeCPhyID`, `AppleTypeCPhyLane`, `AppleTypeCPhyUSB2`, `AppleTypeCPhyDisplayPortPclk`, `AppleTypeCPhyDisplayPortTunnel`, `Transport`, `Power Level`, `Client`, `Link Rate` | W7 |
| PHY 값 형식 | lane `Transport`: `CIO`, `DisplayPort`, `USB3`, 빈 문자열. `Power Level`: `on` 또는 빈 문자열. `Link Rate` 예: "5.40Gbps/lane (HBR2)" | W8 |
| DisplayPort 링크 | `Active`, `LaneCount`, `MaxLaneCount`, `LinkRate`, `LinkRateDescription`, `Tunneled`, `HPD_State`, `HPD_StateDescription`, `NominalSignalingFrequenciesHz`, `Index` | W9 |
| DisplayPort 모니터 | `EDID`, `EDIDChanged`, `Metadata`, `ManufacturerName`, `ProductName`, `ProductID`, `SerialNumber`, `YearOfManufacture`, `Year of Manufacture`, `Week of Manufacture` | W9 |
| DisplayPort 어댑터와 상태 | `DFP Type`, `DFP Type Description`, `BranchDeviceID`, `BranchDeviceOUI`, `SinkCount`, `Role`, `RoleDescription`, `DriverStatus`, `DriverStatusDescription`, `TransportType`, `TransportTypeDescription`, `TransportDescription` | W9 |
| DisplayPort 인증과 권한 | `AuthorizationRequired`, `AuthorizationStatus`, `AuthorizationStatusDescription`, `AuthenticationRequired`, `AuthenticationStatus`, `AuthenticationStatusDescription`, `HashStatus`, `HashStatusDescription`, `TRM_TransportSupervised` | W9 |
| 부모 포트 조인 | `ParentPortType`, `ParentPortTypeDescription`, `ParentPortNumber`, `ParentPortBuiltIn`, `ParentBuiltInPortType`, `ParentBuiltInPortTypeDescription`, `ParentBuiltInPortNumber` | W9 |
| 디스플레이 노드 타이밍 | `DPTimingModeId`, `TimingElements`, `PreferredTimingElements`, `HorizontalAttributes`, `VerticalAttributes`, `Active`, `Total`, `PreciseSyncRate`(16.16 고정소수점, 65536으로 나눔), `IsInterlaced` | W11 |
| 디스플레이 노드 색 모드 | `ColorModes`, `ID`, `PixelEncoding`, `Depth`, `SupportsDSC`, `IsVirtual`, `DownstreamFormat`, `ValidPixelEncodings`, `DSCRequiredColorElementIDs`, `UnsafeColorElementIDs` | W11 |
| 디스플레이 노드 식별 | `EDID UUID`, `IOMFBUUID`, `DisplayAttributes`, `ProductAttributes`, `SerialNumber`, `external` | W11 |
| 디스플레이 노드 매칭 규칙 | `EDID UUID`는 EDID 바이트 8-23을 UUID로 표기하고 시리얼 바이트 12-15를 0으로 채운 값. DisplayPort 노드의 EDID 바이트로 같은 키 생성 | W11 |
| CoreGraphics | `CGDisplayCopyDisplayMode`, `CGDisplayCopyAllDisplayModes`, `CGDisplayVendorNumber`, `CGDisplayModelNumber`, `CGDisplaySerialNumber`, `CGDisplayIsBuiltin`, `NSScreenNumber` | W12 |
| TRM transport | `CableGeneration`, `CableSpeed`, `Generation`, `AsymmetricModeSupported`, `LegacyAdapter`, `LinkTrainingMode`, `TunneledTransportsProvisioned`, `Priority`, `TRM_State`, `TRM_StateDescription`, `TRM_Profile`, `TRM_ProfileDescription`, `TRM_TransportRestricted`, `TRM_DeviceLocked`, `TRM_IdentificationRestricted`, `TRM_GracePeriodReason`, `TRM_RelaxedPeriod`, `TRM_CacheMiss` | W15 |
| USB3 transport | `SuperSpeedSignaling`, `SuperSpeedSignalingDescription`, `DataRole`, `PortDataRole` | W16 |
| USB-PD 식별 | `VDOs`, `Vendor ID`, `Product ID`, `bcdDevice`, `Specification Revision`, `Product Type`, `Product Type Description`, `ComponentName`, `AddressDescription`, `Metadata` | W17, W18 |
| 전원 소스 | `PowerSourceOptions`, `WinningPowerSourceOption`, `PowerSourceName`, `PowerTelemetryData`, `SystemPowerIn`, `ExternalConnected`, `PortControllerInfo` | W19 |
| 포트 진단 카운터(`AppleSmartBattery` 노드) | `PortControllerInfo` 배열 항목의 `PortControllerAttachCount`, `PortControllerDetachCount`, `PortControllerHardResetCount`, `PortControllerShortDetectCount`, `PortControllerI2cErrCount`, `PortControllerCapMismatch`, `PortControllerActiveContractRdo`, `PortControllerMaxPower`, `PortControllerNPDOs`, `PortControllerNEprPDOs`, `PortControllerPortPDO`, `PortControllerFetStatus`, `PortControllerVdoFailCount`, `PortControllerDataRoleSwapCount`, `PortControllerPwrRoleSwapCount` 등 | W20 |
| Thunderbolt | `Current Link Speed`, `Current Link Width`, `Supported Link Speed`, `Supported Link Width`, `Target Link Speed`, `Target Link Width`, `Link Bandwidth`, `Thunderbolt Version`, `Route String`, `Router ID`, `Adapter Type`, `Hop Table`, `Max Port Number`, `Upstream Port Number`, `Dual-Link Port`, `CLx State`, `Device Vendor Name`, `Device Model Name`, `Device Vendor ID`, `Device Model ID`, `DROM`, `UID`, `Depth`, `Port Number`, `Socket ID`, `USB Port Map`, `Maximum Bandwidth Allocated`, `Required Bandwidth Allocated` | W21, W22 |
| USB 장치 | `UsbIOPort`, `locationID`, `Device Speed`, `USB Product Name`, `USB Vendor Name`, `USB Serial Number`, `idVendor`, `idProduct`, `bcdUSB`, `bDeviceClass`, `kUSBContainerID`, `USBPortType`, `Bus Power Available`, `Requested Power`, `UsbBillboardSupportedModes`, `UsbBillboardCurrentMode`, `UsbBillboardPreferredMode`, `UsbBillboardAltModeFailed`, `UsbBillboardVersion` | W23 |
| 액체 감지 | `LiquidDetected`, `MeasurementStatus`, `MitigationsEnabled`, `State`, `StateDescription` | W24 |
| SMC 키 | 전력: `VD0R`, `ID0R`, `PDTR`, `PPBR`. 배터리 충전 상태: `CH0R`, `CHCE`, `CHCC`, `AC-i`, `BSFC`, `CHLS`, `CHWA`, `BUIC`, `CHNC`, `CHSC` | W25 |

- 읽기 방식: `IOServiceMatching(클래스명)`, `IOServiceGetMatchingServices`, `IOServiceAddMatchingNotification`, `IORegistryEntryCreateCFProperty`, `IORegistryEntryGetParentEntry`(kIOServicePlane) 사용. 알림 기반 갱신과 1초 주기 폴링 병행 (W7). 확인: 소스
- USB 장치와 물리 포트 연결: XHCI 포트 노드의 `UsbIOPort` 경로 사용, 없으면 `locationID` 상위 바이트와 `hpm` SPMI 조상 기반 추정 (W1). 확인: 문서
- `DisplayPortPinAssignment` 정수값: lane 분배 판정에 신뢰 불가라는 주석(동일 독에서 2 lane과 4 lane 모두 같은 값 보고) (W14). 확인: 소스
- PD 디코딩 기준: USB-PD R3.2 V1.2 (W1). 확인: 문서
- 벤더명 DB: 번들 SQLite(`whatcable.db`), USB-IF 벤더 목록과 usb.ids와 사용자 제보 케이블 지문 병합 (W1). 확인: 문서

### 2.6 CLI

출처 W1. 확인: 문서.

- 제공 여부: 제공. 바이너리 이름 `whatcable`, 앱 번들 내 `Contents/Helpers/whatcable`, Homebrew 설치 시 PATH 연결
- 무료 플래그: 인자 없음(전체 포트 요약), `--json`, `--watch`, `--raw`(원시 IOKit 속성 포함), `--report`, `--test-kit`, `--no-usb-probe`, `--desktop`, `--popover`, `--version`, `--help`
- Pro 플래그: `--monitor`, `--monitor-json`, `--dashboard`(전체 화면 TUI, Overview와 Negotiation과 Power 3개 화면), `--activate`, `--licence`, `--deactivate`, `--pro`
- 기타: `--silence-pro-hints`, `--show-pro-hints`

### 2.7 라이선스

| 항목 | 내용 | 출처 | 확인 |
| --- | --- | --- | --- |
| 기본 라이선스 | MIT (Copyright 2026 Darryl Morley). 저장소 파일의 기본값 | W2 | 문서 |
| 예외 | 자체 LICENSE 파일을 가진 하위 디렉터리는 해당 조건 적용. 비공개 개발 저장소의 `Sources/WhatCablePlugins/`는 독점 소스 | W2 | 문서 |
| 공개 저장소의 Plugins 디렉터리 | `Bootstrap.swift` 1개 파일만 존재 | W1 저장소 트리 | 소스 |
| GitHub 라이선스 자동 판별 | NOASSERTION. 사유 미확인 | GitHub API | 미확인 |
| 디스플레이 진단 코드 위치 | `DisplayDiagnostic`, `DisplayTimingReader`, EDID 파서는 공개 저장소의 WhatCableCore 및 WhatCableDarwinBackend에 존재. Sources 하위에 별도 LICENSE 파일 없음(루트 LICENSE의 MIT 기본값 적용 범위). Display Diagnostics 화면은 README 기준 Pro | W2, W11, W13 | 소스 |

### 2.8 제약 (문서 기재)

출처 W1. 확인: 문서.

- e-marker가 있는 케이블만 케이블 정보 표시. 60 W 미만 케이블 다수는 e-marker 없음
- 일부 케이블은 반대편에 장치가 연결된 뒤에만 e-marker 응답
- 소프트웨어로 케이블 내부 물리 구성 검증 불가. e-marker 값이 사실과 다를 수 있음
- Apple Silicon 데스크톱의 전면 USB-C 포트는 케이블, 전력, PD 데이터 미노출
- Intel Mac 미지원

## 3. 보조 비교

### 3.1 출처 목록

| 키 | 문서 | URL |
| --- | --- | --- |
| M1 | MonitorControl README | https://github.com/MonitorControl/MonitorControl |
| L1 | Lunar README | https://github.com/alin23/Lunar |
| L2 | Lunar 공식 사이트 | https://lunar.fyi/ |
| D1 | displayplacer README | https://github.com/jakehilborn/displayplacer |
| S1 | SwitchResX 공식 사이트(기능, 버전 이력 문구) | https://www.madrau.com/ |
| S2 | SwitchResX FAQ 데이터 | https://www.madrau.com/data/faq.json |
| DB1 | DisplayBuddy 공식 사이트 | https://displaybuddy.app/ |
| DB2 | DisplayBuddy 가격 | https://displaybuddy.app/pricing |
| DB3 | DisplayBuddy FAQ | https://displaybuddy.app/faq |
| A1 | AllRez 저장소 | https://github.com/joevt/AllRez |
| P1 | Apple 지원 문서: Displays 설정 | https://support.apple.com/guide/mac-help/change-displays-settings-mh40768/mac |

### 3.2 MonitorControl

- 개요: 외장 디스플레이 밝기와 볼륨 제어 메뉴 막대 앱. MIT, 무료, v4.4.0 (M1, 문서)
- 디스플레이 옵션: 밝기, 볼륨, 대비 제어 (M1, 문서)
- 제어 방식: 외장은 DDC, Apple 및 내장 디스플레이는 네이티브 프로토콜, 소프트웨어 디밍은 감마 테이블, AirPlay와 Sidecar와 DisplayLink 및 가상 화면은 shade(오버레이) (M1, 문서)
- 부가 기능: 네이티브 OSD 표시, 부드러운 밝기 전환, 하드웨어와 소프트웨어 결합 디밍, 완전 흑색 디밍, 내장 및 Apple 화면 밝기를 외장으로 동기화, 단일 슬라이더 전체 동기화, 커스텀 단축키와 Apple 키보드 밝기 및 미디어 키 (M1, 문서)
- 제약: 2018 Intel Mac mini 내장 HDMI, 모든 M1 Mac 내장 HDMI, 보급형 M2 Mac mini 내장 HDMI에서 DDC 미지원. DisplayLink 독은 DDC 불가, 소프트웨어 디밍만 가능. EIZO 등 MCCS over USB 디스플레이는 소프트웨어 디밍만 가능 (M1, 문서)
- 제약: macOS Tahoe에서 네이티브 OSD 백분율 값 미표시 (M1, 문서)
- 해상도, HiDPI, 회전, 배치, 미러, EDID, 입력 전환 기능: 없음 (B3의 비교표 기준, 문서)
- 진단 기능: 없음 (M1 범위 내 기재 없음, 미확인)

### 3.3 Lunar

- 개요: 외장 모니터 밝기 적응 제어 앱. 저장소 MIT, Pro 기능 소스는 암호화되어 저장소만으로 빌드 불가. v6.11.3 (L1, 문서)
- 가격: Pro 영구 라이선스 23 USD, 14일 체험. 무료 사용자는 수동 조정 하루 100회, Shortcuts 액션 하루 100회 (L2, 문서)
- 디스플레이 옵션: DDC 밝기, 대비, 볼륨, 입력 전환, 전원 끄기. Apple 디스플레이 네이티브 제어. 감마 테이블 및 네트워크 제어 fallback (L1, L2, 문서)
- 디스플레이 옵션: 화면 방향 변경(0, 90, 180, 270도 단축키), 숨겨진 해상도 드롭다운 (L1, 문서)
- 밝기 확장: XDR Brightness(2021 이후 MacBook Pro, Pro Display XDR), 1000-1600 nits 표기, Sub-zero dimming(0% 미만 디밍) (L1, L2, 문서)
- 자동화: Sync Mode(내장 조도 센서 추종), Sensor Mode(외부 조도 센서), Location Mode, Clock Mode, App Presets (L1, L2, 문서)
- 연결 관리: BlackOut(선택 디스플레이 끄기, USB-C 충전과 모니터 오디오와 USB 허브 유지), Auto BlackOut(외장 연결 시 내장 끄기) (L1, L2, 문서)
- 기타: FaceLight, CLI(`get`, `set`, `displays`, `lux`, `ddc`, `gamma`, `listen`, `lid`), Shortcuts (L2, 문서)
- 제약: DisplayLink는 DDC와 감마 미전달, 제어에 Raspberry Pi 중계 필요 (L2, 문서)
- 진단 기능: 링크 또는 케이블 진단 기재 없음 (미확인)

### 3.4 displayplacer

- 개요: 다중 디스플레이 해상도와 배치 구성용 CLI. MIT, v1.4.0 (2023-06-11), 저장소 최종 push 2024-06-05 (D1, 문서)
- 조회: `displayplacer list`로 현재 화면 정보와 가능한 해상도 모드 출력, 현재 레이아웃 재현용 인자 문자열 출력 (D1, 문서)
- 적용 인자: `id`, `res`, `hz`, `color_depth`, `scaling`, `origin`, `degree`, `mode`, `enabled`, `quiet` (D1, 문서)
- 미러링: `id:<id1>+<id2>` 형식. 첫 번째 screenId가 "Optimize for" 화면 (D1, 문서)
- 메인 디스플레이: origin (0,0) 화면이 primary (D1, 문서)
- 화면 비활성화: `enabled:false`. 복구에 물리 재연결이 필요한 경우 있음 (D1, 문서)
- 식별자: persistent, contextual, serial screenId 3종. macOS가 persistent screenId를 바꾸는 사례 기재 (D1, 문서)
- 제약: 목록의 일부 해상도는 동작하지 않음. 내장 MacBook 화면 회전 지원 (D1, 문서)
- Apple Silicon 및 macOS 26 동작 여부: 미확인
- 진단 기능: 없음 (모드 목록 출력 한정)

### 3.5 SwitchResX

- 개요: 해상도 제어 도구. 셰어웨어, 10일 체험. 현재 버전 번호와 가격은 미확인 (S1, 문서)
- 디스플레이 옵션: 커스텀 해상도(타이밍 해상도와 스케일 해상도 구분), 종횡비 지정, 주사율별 그룹 표시, HiDPI 스케일 해상도 정의 (S1, S2, 문서)
- Display Sets: 해상도, 회전, 미러, 활성 상태 등의 묶음 저장, 단축키 연결, 이벤트(전원 연결 등) 및 앱별 자동 적용, 연쇄 적용, AppleScript 연동 (S1, 문서)
- 디스플레이 비활성화: Intel 지원. Apple Silicon은 macOS Ventura 이상과 v4.13 이상에서 지원 (S2, 문서)
- EDID: 내보내기, 커스텀 EDID 가져오기, 가져온 EDID와 현재 EDID의 해석 정보 및 텍스트 차이 표시 (S1, 문서)
- Apple Silicon 색 모드: SDR 대 HDR, RGB 대 YCbCr 색 프로파일 선택 지원. macOS 설정에 없는 주사율 추가 지원 (S1, 문서)
- Apple Silicon 커스텀 타이밍: macOS Ventura 이상에서 커스텀 타이밍 추가 복원, 내장 화면 커스텀 타이밍 override 지원 문구 존재. 잘못된 해상도 적용 방지용 safe mode(시작 시 control 키) (S1, 문서)
- 제약: 스케일 해상도 폭은 M1 및 M2에서 6016px, M1 및 M2 Pro에서 7360px까지 처리 (S2, 문서)
- 제약: Apple Silicon HiDPI는 macOS 12.4부터 네이티브 해상도 이하에서만 활성. 인터레이스 해상도는 macOS 11부터 전 기종 제거 (S2, 문서)
- macOS 26 Tahoe 호환성: FAQ 항목 존재. 답변 본문은 미확인 (S2)
- 진단 기능: EDID 해석 표시 외 링크 진단 기재 없음 (미확인)

### 3.6 DisplayBuddy

- 개요: 외장 모니터 제어 메뉴 막대 앱. macOS와 Windows. 일회 구매 24.99 USD(Mac 1대), 29.99 USD(Mac 2대), 7일 환불, SetApp 제공 (DB1, DB2, 문서)
- 디스플레이 옵션: DDC 밝기, 하드웨어 대비, 내장 스피커 볼륨, 입력 소스, 해상도, 회전 (DB1, 문서)
- 프리셋: 밝기, 대비, 볼륨, 입력 소스, 동기화, 전원 끄기, 해상도, 회전, 디스플레이 배치 저장 및 복원 (DB1, 문서)
- 스케줄: 일출, 일몰, 시각, 충전기 연결, 디스플레이 연결 조건에 프리셋 연결 (DB1, 문서)
- 동기화: 단일 슬라이더로 전체 디스플레이 밝기 연동 (DB1, 문서)
- 제어 방식: DDC 우선, 미지원 시 감마 제어 자동 전환, LG webOS와 Samsung Tizen은 Wi-Fi 제어, Apple 디스플레이는 네이티브 API (DB1, DB3, 문서)
- 기타: UltraBright(MacBook Pro 밝기 확장), 위젯, Shortcuts와 Siri, CLI와 MCP, 커스텀 단축키 (DB1, 문서)
- 제약: HDR 전용 설정 직접 제어 없음. 독, 허브, HDMI 어댑터의 DDC 전달 여부에 의존 (DB3, 문서)
- 호환성: macOS Tahoe와 M1-M5 지원 표기 (DB3, 문서)
- 진단 기능: 기재 없음 (미확인)

### 3.7 AllRez

- 개요: macOS 디스플레이 정보 덤프 도구. 저장소 설명 "Dump all display info in macOS including DPCD and DDC/CI". C 및 C++ 소스, Xcode 프로젝트 3종(기본, 10.12, 10.6) (A1, 문서)
- README: 없음. 사용법과 출력 항목 설명 문서 미확인 (A1)
- 소스 구성(파일명 기준): `dpcd.cpp`, `displayport.cpp`, `vcp.cpp`, `vcpcodes.h`, `ddccicommands.h`, `AGDCDiagnose.cpp`, `iofbdebuguser.cpp`, `oui.cpp`, IOGraphics 헤더 사본. 별도 `dumpdpcd` 명령 (A1, 소스)
- 진단 범위: 파일명 외 소스 본문 열람 미실시. 출력 항목 상세 미확인
- 디스플레이 옵션 변경 기능: 미확인
- 라이선스: 저장소에 라이선스 표기 없음 (GitHub API license null) (A1, 문서)
- 최종 커밋: 2025-04-21 "Add dumpdpcd command" (A1, 문서)
- Apple Silicon 지원 범위: 미확인
- 관련성: BetterDisplay의 DPCD 리포트가 AllRez에서 착안했다는 개발자 표기 (B14, 문서)

### 3.8 macOS 시스템 설정 "디스플레이" 패널

- 출처 문서의 적용 버전: macOS 27 기준 페이지. macOS 26 페이지와의 차이는 미확인 (P1)
- 배치: Arrange, Add Display 팝업 메뉴, Use as, Optimize for (P1, 문서)
- 해상도: Resolution, Show all resolutions, Advanced의 Show resolutions as list, Dynamic resolution (P1, 문서)
- 밝기와 색: Brightness, Automatically adjust brightness 또는 Ambient light compensation, True Tone, Color profile, Preset, Customize Presets, Calibrate Display (P1, 문서)
- 주사율: Refresh rate, Adaptive Sync, Genlock (P1, 문서)
- 기타: Rotation, High Dynamic Range, Underscan, When connected to TV, Night Shift, Detect Displays, Link to Mac or iPad (P1, 문서)
- Sidecar 관련: Show Sidebar, Show Touch Bar, Enable double tap on Apple Pencil (P1, 문서)
- 미제공 항목(패널 옵션 목록에 없음): RGB 또는 YCbCr, chroma, range, 연결 비트 심도 선택, DDC 제어, EDID 조회 및 override, 링크 속도와 lane 수 및 DSC 표시, 케이블 진단, 소프트 연결 해제 (P1 범위 내 기재 없음, 문서)
- 진단 기능: 패널 내 진단 표시 없음. System Information 앱의 Graphics/Displays 항목은 본 조사에서 미확인

## 4. TheBestDisplay 기능 후보 총괄표

- 비고 열의 괄호 안 키는 근거 출처(1.2절, 2.2절, 3.1절 정의). 확인 구분은 해당 절의 표 기준
- "AS"는 Apple Silicon

| 영역 | 기능 | 참고 제품 | 비고 (Apple Silicon 제약) |
| --- | --- | --- | --- |
| 해상도 | 전체 디스플레이 모드 목록과 태그 필터(종횡비, 주사율, 심도, HiDPI) | BetterDisplay, displayplacer, SwitchResX | unsafe 및 invalid 모드 구분 표시 필요 (G1) |
| 해상도 | 해상도 슬라이더, 즐겨찾기 모드 | BetterDisplay, SwitchResX | 모드 선택은 영구 구성으로 저장됨 (G1) |
| 해상도 | 커스텀 스케일 해상도 추가 | BetterDisplay, SwitchResX | 시스템 override 설치, 관리자 인증, 활성화 또는 재시동 필요. 동일 벤더 및 모델 전체에 적용 (G19) |
| 해상도 | 커스텀 타이밍 | SwitchResX | 임의 타이밍 즉시 활성화 불가. 커스텀 EDID 경유이며 macOS 수용이 전제 (B12). SwitchResX는 Ventura 이상 지원 표기 (S1) |
| 해상도 | 네이티브 및 기본 해상도 override, 디스플레이 역할 변경 | BetterDisplay | 재시동 필요 (G19, B8) |
| HiDPI | HiDPI와 LoDPI 토글, notch 모드 토글 | BetterDisplay | 대응 모드가 있을 때만 전환 (G9) |
| HiDPI | Flexible scaling(다단계 HiDPI 스케일) | BetterDisplay | 네이티브 해상도 초과 불가. 수평 상한 보급형 M1/M2 6144px, 상위 칩 7680px(구 문서 수치) (B5). 최신 칩 수치 미확인 |
| HiDPI | 렌더링 한계 표시(Horizontal GPU resolution limit, Allocation limits) | BetterDisplay | 포트, 배치, macOS에 따라 변동 (G31) |
| HiDPI | HiDPI 개념 설명(논리, 렌더링, 물리 해상도 구분) | BetterDisplay | 해당 없음 (B6) |
| 주사율 | 현재 모드 기준 주사율 목록, VRR 표기 | BetterDisplay, macOS 설정 | HiDPI 크기에 따라 가능한 주사율 감소 (G43) |
| 주사율 | 연결 수준 비노출 주사율(NTSC 분수 등) 선택 | BetterDisplay, SwitchResX | AS 전용. 모드 변경 후 미유지, macOS 설정 표시와 불일치 (G2, G42) |
| 주사율 | 주사율 측정 표시(측정값, 보고 실제값, 보고 공칭값) | BetterDisplay | 소프트웨어 타이밍 관측값이며 패널 계측 아님 (G2) |
| HDR | HDR 토글과 상태 표시(native, forced, EDR 값, HDR 휘도) | BetterDisplay, macOS 설정 | Forced HDR은 빈 화면과 녹색 화면 위험 (G4) |
| HDR | XDR 프리셋 선택 | BetterDisplay, macOS 설정 | 프리셋에 따라 밝기 제어 범위 변동 (G11) |
| HDR | XDR/HDR 밝기 업스케일 | BetterDisplay, Lunar, DisplayBuddy | 색 테이블 방식은 HDR 콘텐츠 클리핑. Direct 방식은 내장 XDR 한정, macOS 26.3 이상 (B7) |
| 색 모드 | RGB 또는 YCbCr, chroma, range, 연결 비트 심도, HDR EOTF 조합 목록과 선택 | BetterDisplay, SwitchResX | AS 전용 기능. 현재 해상도와 주사율에서 연결이 제공하는 형식만 선택 가능. 재연결 후 유지 미보장 (G4, G34) |
| 색 모드 | 선호 모드와 현재 모드 구분 표시, 프레임버퍼 심도와 연결 심도 불일치 안내 | BetterDisplay | 프레임버퍼 심도 선택 메뉴는 Intel 전용 (G3, G35) |
| 색 모드 | 색 모드 유지(변경 감지 후 복원) | BetterDisplay | 앱 상시 실행 필요 (G8, G34) |
| 색 모드 | GPU 디더링 토글 | BetterDisplay | AS 전용. 모니터 내부 디더링은 제어 불가 (G44) |
| DDC | 밝기, 대비, 볼륨, 음소거, RGB gain, 입력 전환, 전원 | BetterDisplay, MonitorControl, Lunar, DisplayBuddy | 독, 어댑터, DisplayLink 경유 시 DDC 미전달 가능. Apple 디스플레이는 DDC 비권장 (G40, G41, M1) |
| DDC | capabilities 탐지와 자동 구성, 임의 VCP 읽기 및 쓰기 | BetterDisplay, AllRez | read-back과 write 지원 여부 상이 가능 (G23) |
| DDC | 내장 HDMI 포트 DDC | BetterDisplay | MonitorControl은 M1 내장 HDMI 미지원 (M1, B3) |
| 밝기 | 하드웨어, 소프트웨어, 결합 밝기와 nits 표시 | BetterDisplay, MonitorControl, Lunar | nits는 보고값 또는 추정값 (G20) |
| 밝기 | 소프트웨어 디밍(색 테이블, 오버레이), 0% 미만 디밍 | BetterDisplay, MonitorControl, Lunar, DisplayBuddy | M5 Pro, M5 Max, MacBook Neo에서 색 테이블 조정 오동작 사례 (G45) |
| 밝기 | 디스플레이 간 밝기 동기화(nits 정규화 포함) | BetterDisplay, MonitorControl, Lunar, DisplayBuddy | 해당 없음 (G29) |
| 색 | 색 프로파일 선택과 SDR 및 HDR별 자동 전환 | BetterDisplay, macOS 설정, SwitchResX | 해당 없음 (G14) |
| 색 | 색온도, 감마, gain, 대비, 채도 조정 | BetterDisplay | 색 테이블 지원 디스플레이 한정 (B4) |
| 색 | Night Shift, True Tone 토글과 TV용 Night Shift | BetterDisplay, macOS 설정 | 네이티브 연결 한정. Television 역할, DisplayLink, Sidecar 제외 (B8) |
| 회전 | 0, 90, 180, 270도 회전 | BetterDisplay, Lunar, displayplacer, DisplayBuddy, macOS 설정 | macOS가 회전 지원을 보고하는 디스플레이 한정 (G5) |
| 배치 | 드래그 배치와 스냅, 기준 디스플레이 대비 16방향 정렬, 좌표 지정 | BetterDisplay, displayplacer, macOS 설정 | 해당 없음 (G7) |
| 배치 | 메인 디스플레이 지정 | BetterDisplay, displayplacer, macOS 설정 | 해당 없음 (G9) |
| 배치 | 배치 프리셋 저장과 복원, 배치 보호 | BetterDisplay, displayplacer, DisplayBuddy, SwitchResX | macOS가 디스플레이 식별자를 바꾸는 사례 존재 (D1) |
| 미러 | 소스와 대상 지정 미러링, 미러 해제 | BetterDisplay, displayplacer, macOS 설정 | 미러 변경 시 해상도와 메인 디스플레이 변동 가능 (G6) |
| 미러 | 미러 구성 보호 | BetterDisplay | 해당 없음 (G8) |
| 연결 관리 | 소프트 연결 해제와 재연결 | BetterDisplay, Lunar(BlackOut), SwitchResX, displayplacer | AS는 대기 진입. iMac 내장과 M3 기본형 내장은 별도 override. 최소 1개 물리 디스플레이 유지 규칙 필요 (G10, G22) |
| 연결 관리 | 외장 연결 시 내장 자동 해제, 자동 재연결 | BetterDisplay, Lunar | AS 전용 (G22) |
| 연결 관리 | 디스플레이 재초기화, 재감지 | BetterDisplay, macOS 설정(Detect Displays) | 재초기화는 AS 외장 디스플레이 한정 (G9, G21) |
| 연결 관리 | 구성 보호(해상도, 주사율, 색 모드, 회전, 프로파일, HDR, 미러, 메인) | BetterDisplay | 반복 충돌 시 일시 중단 로직 필요 (G8) |
| 가상 디스플레이 | 가상 스크린 생성(프리셋, 커스텀 종횡비, HiDPI) | BetterDisplay | 미러 구성 시 수면, 색, 커서 문제 사례 (B5) |
| 가상 디스플레이 | HDR, 고주사율, 8K 초과 가상 스크린 | BetterDisplay | Mac별 지원 모드와 크기 제한. 8K 초과 시 Catalyst 앱 충돌 가능성 (B5, G27) |
| EDID | EDID 조회(OS 제공, I2C 직접), 해석, 내보내기 | BetterDisplay, SwitchResX, WhatCable, AllRez | 내장 디스플레이와 DisplayLink는 대상 제외 (G18) |
| EDID | EDID 리포트(CTA, DisplayID, tiled display 디코딩) | BetterDisplay, WhatCable | WhatCable은 자체 EDID 파서 보유 (W13, G37) |
| EDID | 커스텀 EDID 적용과 원복 | BetterDisplay, SwitchResX | AS는 휘발성 override, 외장 디스플레이 한정. 식별자 변경 시 다른 디스플레이로 인식 (G18, G54) |
| EDID | EDID 장치 쓰기 | BetterDisplay | 256바이트 제한, 장치 손상 위험. 후보 제외 검토 대상 (G18, G36) |
| 링크 진단 | 연결 유형, 전송 모드, link rate, lane 수, raw 및 effective 대역폭, 인코딩, downspread | BetterDisplay, WhatCable | 보고값 또는 추정값. BetterDisplay는 IOAV 계열 호출과 I/O Registry 사용 언급 (B13, G17) |
| 링크 진단 | DSC 활성 여부와 PPS 필드, 비압축 및 압축 payload 추정 | BetterDisplay, WhatCable | DSC 강제 제어 기능은 문서상 없음. WhatCable은 `DSCRequiredColorElementIDs` 판독 (W11, B14) |
| 링크 진단 | DPCD 덤프와 리포트 | BetterDisplay, AllRez | BetterDisplay는 AS 전용 표기 (B4, B14) |
| 링크 진단 | HDCP 지원 버전 표시 | BetterDisplay | 재생 인증 상태가 아닌 지원 프로토콜 버전 (G52) |
| 링크 진단 | 최상 모드 미도달 원인 판정(선택 모드, 어댑터, 케이블 구분) | WhatCable | 링크 재학습 여부 미측정에 따른 비단정 표현 필요 (W13) |
| 링크 진단 | 디스플레이 정보 리포트 내보내기 | BetterDisplay | 시리얼, UUID 등 식별자 포함 주의 (G17) |
| 케이블/포트 진단 | 포트별 연결 상태, 활성 transport, 플러그 방향 | WhatCable | Intel 미지원. 데스크톱 전면 USB-C 포트는 데이터 미노출 (W1, W6) |
| 케이블/포트 진단 | 케이블 e-marker(속도, 전류 정격, 벤더), USB-IF 인증, 신뢰 신호 | WhatCable | e-marker 없는 케이블은 정보 없음 (W1) |
| 케이블/포트 진단 | DisplayPort alt mode lane 구성(4 lane 또는 2 lane + USB3) | WhatCable | `DisplayPortPinAssignment` 값은 신뢰 불가라는 소스 주석 (W14) |
| 케이블/포트 진단 | PHY lane별 transport와 DP link rate | WhatCable | `AppleTypeCPhy` 계열 클래스 의존 (W7, W8) |
| 케이블/포트 진단 | Thunderbolt 세대, lane 속도, 스위치 토폴로지, 터널 | WhatCable | 해당 없음 (W21, W22) |
| 케이블/포트 진단 | 충전기 PDO 목록, 협상 전력, 충전 제한 요소 판정 | WhatCable | 실시간 전력 측정은 SMC 접근 필요(샌드박스 차단) (W1) |
| 케이블/포트 진단 | 체인 내 어댑터 식별(DFP Type, Branch device) | WhatCable | 해당 없음 (W9) |
| 케이블/포트 진단 | 규칙 기반 진단 문구와 JSON 출력 CLI | WhatCable | 해당 없음 (W13, W1) |

## 5. 미확인 항목 목록

- BetterDisplay 가이드의 CLI reference 최신 본문과 Wiki v5.0.6 기준 목록 간 차이
- BetterDisplay의 DSC 강제 설정 또는 해제 가능 여부(제어 기능 문서 없음)
- BetterDisplay의 DisplayPort MST 관련 기능과 제약
- BetterDisplay HiDPI 수평 상한의 M3 이후 칩별 수치
- BetterDisplay가 링크 정보 수집에 사용하는 API의 전체 목록(개발자 코멘트의 일부 언급만 확인)
- WhatCable 무료 빌드에서 디스플레이 진단 결과가 노출되는 범위
- SwitchResX 현재 버전 번호, 가격, macOS 26 호환성 답변 본문
- DisplayBuddy의 M1 내장 HDMI DDC 지원 여부
- AllRez의 출력 항목 상세, Apple Silicon 지원 범위, 라이선스
- displayplacer의 macOS 26 및 Apple Silicon 동작 상태
- macOS 26 기준 "디스플레이" 패널 옵션(열람 문서는 macOS 27 기준)
