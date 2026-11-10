# 플랫폼 API 조사

- 조사 일자: 2026-11-10
- 대상: macOS 26, Apple Silicon, 샌드박스 미적용 앱
- 조사 방법: 웹 문서와 공개 소스 저장소 열람. 로컬 실측 없음.
- 문서 성격: 기능별 구현 가능 API 목록과 근거. 동작 보장 문서 아님.

## 0. 표기 규칙과 공통 근거

### 0.1 확인 구분

| 구분 | 의미 |
|---|---|
| 문서 | Apple 공식 문서, 또는 프로젝트 README, 릴리스 노트, 이슈, 조사 노트에 서술된 내용 |
| 소스 | 공개 저장소의 소스 코드 또는 SDK tbd 심볼 목록에서 직접 확인한 내용 |
| 미확인 | 공개 근거를 찾지 못한 내용. 시그니처 미확인, 동작 미확인 포함 |

- "소스"는 해당 코드가 존재함을 뜻함. 이 조사에서 실행 결과를 확인한 것은 아님.
- 저장소 조사 노트에 적힌 측정값은 해당 저장소 작성자의 보고이며 "문서"로 분류.

### 0.2 주요 참조 저장소

| 약칭 | 저장소 | 성격 | 최근 푸시 |
|---|---|---|---|
| displayplacer | https://github.com/jakehilborn/displayplacer | 모드, 배치, 회전 CLI (C, Objective-C) | 2024-06 |
| AllRez | https://github.com/joevt/AllRez | 디스플레이 정보 덤프 도구. 비공개 선언 다수 | 2025-04 |
| Lunar | https://github.com/alin23/Lunar | 밝기 제어 앱. 공개 저장소에 일부 소스 포함 | 2026-10 |
| mac-utils | https://github.com/alin23/mac-utils | Lunar 작성자의 단일 파일 Swift 도구 모음 | 2026-10 |
| MonitorControl | https://github.com/MonitorControl/MonitorControl | DDC 밝기, 음량 제어 앱 | 2026-10 |
| m1ddc | https://github.com/waydabber/m1ddc | Apple Silicon DDC CLI (BetterDisplay 작성자) | 2026-10 |
| WhatCable | https://github.com/darrylmorley/whatcable | USB-C 포트, 케이블, DP 링크 정보 앱. macOS 14 이상, Apple Silicon 전용 | 2026-10 |
| lumen | https://github.com/shashvat1965/lumen | 디스플레이 제어 앱. README 요구 사항이 macOS 26, Apple Silicon | 2026-10 |
| Crisp | https://github.com/didriksg/Crisp | 디스플레이 제어 앱. macOS 14 이상. 측정 기록 문서 포함 | 2026-11 |
| AwesomeDisplay | https://github.com/MehbubRashid/AwesomeDisplay | 디스플레이 제어 라이브러리와 CLI. macOS 14 이상 | 2026-10 |
| BrightIntosh | https://github.com/niklasr22/BrightIntosh | XDR 밝기 업스케일 앱 | 2026-10 |
| fastfetch | https://github.com/fastfetch-cli/fastfetch | 시스템 정보 CLI. Apple Silicon EDID, 밝기 조회 코드 포함 | 2026-11 |
| Asahi Linux | https://github.com/AsahiLinux/linux | DCP(디스플레이 코프로세서) 드라이버. TimingElements, ColorElements 파서 | 2026-11 |
| macos-sdk | https://github.com/alexey-lysiuk/macos-sdk | macOS SDK 사본. 비공개 프레임워크 tbd 포함 | 2026-07 |
| BetterDisplay | https://github.com/waydabber/BetterDisplay | 비공개 소스 앱. 릴리스 노트, 이슈, 토론만 공개 | 2026-11 |

### 0.3 macOS SDK tbd 심볼 존재 확인

- 근거: macos-sdk 저장소의 MacOSX14.5.sdk, MacOSX15.5.sdk, MacOSX26.5.sdk tbd 파일. 확인 구분: 소스.
- tbd 등재는 링크 가능한 내보내기 심볼임을 뜻함. 런타임 동작 보장은 아님.

| 프레임워크 (tbd) | 확인한 심볼 | 14.5 | 15.5 | 26.5 |
|---|---|---|---|---|
| CoreGraphics | CGSGetNumberOfDisplayModes, CGSGetDisplayModeDescriptionOfLength, CGSGetCurrentDisplayMode, CGSConfigureDisplayMode, CGSConfigureDisplayEnabled, CGSEnableHDR, CGSIsHDREnabled, CGSIsHDRSupported, CGSServiceForDisplayNumber | 있음 | 있음 | 있음 |
| CoreGraphics | Objective-C 클래스 CGVirtualDisplay, CGVirtualDisplayDescriptor, CGVirtualDisplayMode, CGVirtualDisplaySettings | 있음 | 있음 | 있음 |
| CoreGraphics | CGSSetDisplayRotation | 없음 | 없음 | 없음 |
| SkyLight | SLSGetNumberOfDisplayModes, SLSGetDisplayModeDescriptionOfLength, SLSGetCurrentDisplayMode, SLSConfigureDisplayMode, SLSConfigureDisplayEnabled, SLSGetDisplayList, SLSSetDisplayRotation, SLSDisplaySetHDRModeEnabled, SLSDisplayIsHDRModeEnabled, SLSDisplaySupportsHDRMode, SLSIsDisplayModeVRR, SLSIsDisplayModeProMotion, SLSGetDisplayModeMinRefreshRate, SLSCopyDisplayInfoDictionary, SLSDetectDisplays, SLSDisplaySetUnderscan, SLSDisplaySetActivePresetIndex, SLSServiceForDisplayNumber | 있음 | 있음 | 있음 |
| IOKit | IOAVServiceCreate, IOAVServiceCreateWithService, IOAVServiceReadI2C, IOAVServiceWriteI2C, IOAVServiceCopyEDID, IOAVServiceSetVirtualEDIDMode, IOAVServiceGetLinkData, IOAVServiceGetFRLLinkData, IOAVServiceGetFRLMaxRate, IOAVServiceSetFRLMaxRate, IOAVServiceRetrainFRL, IOAVVideoInterfaceCopyTimingElements, IOAVVideoInterfaceCopyColorElements, IOAVVideoInterfaceCopyDisplayAttributes, IOAVVideoInterfaceSetRotation | 확인 안 함 | 확인 안 함 | 있음 |
| DisplayServices | DisplayServicesGetBrightness, DisplayServicesSetBrightness, DisplayServicesSetBrightnessSmooth, DisplayServicesCanChangeBrightness, DisplayServicesGetLinearBrightness, DisplayServicesSetLinearBrightness, DisplayServicesRegisterForBrightnessChangeNotifications | tbd 존재 | tbd 존재 | 있음 |
| IOMobileFramebuffer | IOMobileFramebufferOpen, IOMobileFramebufferGetDigitalOutMode, IOMobileFramebufferSetDigitalOutMode, IOMobileFramebufferGetSupportedDigitalOutModes, IOMobileFramebufferGetGammaTable, IOMobileFramebufferSetGammaTable | tbd 존재 | tbd 존재 | 있음 |
| MonitorPanel | Objective-C 클래스 MPDisplay, MPDisplayMgr, MPDisplayMode, MPDisplayPreset | tbd 존재 | tbd 존재 | 있음 |
| CoreBrightness | Objective-C 클래스 CBBlueLightClient, CBTrueToneClient, CBAdaptationClient, BrightnessSystemClient | tbd 존재 | tbd 존재 | 있음 |
| CoreDisplay | CoreDisplay_DisplayCreateInfoDictionary, CoreDisplay_Display_GetUserBrightness, CoreDisplay_Display_SetUserBrightness, CoreDisplay_Display_SetHDRModeEnabled, CoreDisplay_Display_IsHDRModeEnabled, CoreDisplay_Display_SupportsHDRMode, CoreDisplay_Display_SetActivePresetIndex | 확인 안 함 | 확인 안 함 | 있음 |

- "tbd 존재"는 파일 존재만 확인하고 개별 심볼 대조는 26.5에서만 수행했음을 뜻함.
- 출처 (소스)
  - https://github.com/alexey-lysiuk/macos-sdk/blob/main/MacOSX26.5.sdk/System/Library/Frameworks/CoreGraphics.framework/Versions/A/CoreGraphics.tbd
  - https://github.com/alexey-lysiuk/macos-sdk/blob/main/MacOSX26.5.sdk/System/Library/PrivateFrameworks/SkyLight.framework/Versions/A/SkyLight.tbd
  - https://github.com/alexey-lysiuk/macos-sdk/blob/main/MacOSX26.5.sdk/System/Library/Frameworks/IOKit.framework/Versions/A/IOKit.tbd
  - https://github.com/alexey-lysiuk/macos-sdk/blob/main/MacOSX26.5.sdk/System/Library/PrivateFrameworks/DisplayServices.framework/Versions/A/DisplayServices.tbd
  - https://github.com/alexey-lysiuk/macos-sdk/blob/main/MacOSX26.5.sdk/System/Library/PrivateFrameworks/IOMobileFramebuffer.framework/Versions/A/IOMobileFramebuffer.tbd
  - https://github.com/alexey-lysiuk/macos-sdk/blob/main/MacOSX26.5.sdk/System/Library/PrivateFrameworks/MonitorPanel.framework/Versions/A/MonitorPanel.tbd
  - https://github.com/alexey-lysiuk/macos-sdk/blob/main/MacOSX26.5.sdk/System/Library/PrivateFrameworks/CoreBrightness.framework/Versions/A/CoreBrightness.tbd
  - https://github.com/alexey-lysiuk/macos-sdk/blob/main/MacOSX26.5.sdk/System/Library/Frameworks/CoreDisplay.framework/Versions/A/CoreDisplay.tbd

### 0.4 비공개 심볼 호출 방식

- (a) `@_silgen_name` 선언: CoreGraphics tbd에 있는 CGS 심볼에 적용 가능. Crisp의 프로브 스크립트가 이 방식 사용.
- (b) `dlopen` 후 `dlsym`, `unsafeBitCast`로 `@convention(c)` 함수 타입 변환: SkyLight, DisplayServices, IOMobileFramebuffer, CoreBrightness 심볼에 적용. lumen, AwesomeDisplay가 이 방식 사용. 심볼 부재 시 해당 기능만 비활성화 가능.
- (c) Objective-C 브리징 헤더 선언: MonitorPanel(MPDisplay), CGVirtualDisplay, CoreBrightness 클래스에 적용. displayplacer, Lunar, Crisp가 이 방식 사용.
- 출처
  - https://github.com/didriksg/Crisp/blob/main/scripts/vrr-probe.swift (소스)
  - https://github.com/shashvat1965/lumen/blob/main/Sources/Private.swift (소스)
  - https://github.com/MehbubRashid/AwesomeDisplay/blob/main/Sources/AwesomeDisplayCore/PrivateAPI/SkyLight.swift (소스)

## 1. 디스플레이 모드 전체 열거와 전환

### 1.1 API 목록

| API | 프레임워크 | 공개 여부 | 선언 | 확인 |
|---|---|---|---|---|
| CGDisplayCopyAllDisplayModes | CoreGraphics | 공개 | `CFArrayRef CGDisplayCopyAllDisplayModes(CGDirectDisplayID display, CFDictionaryRef options)` | 문서 |
| kCGDisplayShowDuplicateLowResolutionModes | CoreGraphics | 공개 | 옵션 딕셔너리 키. 값 `kCFBooleanTrue` | 문서 |
| CGConfigureDisplayWithDisplayMode | CoreGraphics | 공개 | `CGError CGConfigureDisplayWithDisplayMode(CGDisplayConfigRef, CGDirectDisplayID, CGDisplayModeRef, CFDictionaryRef)` | 문서 |
| CGSGetNumberOfDisplayModes | CoreGraphics (SkyLight에 SLS 동명 심볼) | 비공개 | `CGError CGSGetNumberOfDisplayModes(CGDirectDisplayID display, int *nModes)` | 소스 |
| CGSGetDisplayModeDescriptionOfLength | 위와 같음 | 비공개 | `CGError CGSGetDisplayModeDescriptionOfLength(CGDirectDisplayID display, int idx, CGSDisplayModeDescription *mode, int length)` | 소스 |
| CGSGetCurrentDisplayMode | 위와 같음 | 비공개 | `CGError CGSGetCurrentDisplayMode(CGDirectDisplayID display, int *modeNum)` | 소스 |
| CGSConfigureDisplayMode | 위와 같음 | 비공개 | `CGError CGSConfigureDisplayMode(CGDisplayConfigRef config, CGDirectDisplayID display, int modeNum)` | 소스 |
| MPDisplay allModes, setMode:, setModeNumber:, modeWithNumber: | MonitorPanel | 비공개 | Objective-C 메서드 | 소스 |

- displayplacer 헤더는 CGS 함수 반환형을 `void`로 선언. AllRez, Crisp, AwesomeDisplay는 `CGError`로 선언.
- Swift 선언 예시 (Crisp 프로브 스크립트 형식)

```swift
@_silgen_name("CGSGetNumberOfDisplayModes")
func CGSGetNumberOfDisplayModes(_ display: CGDirectDisplayID, _ nModes: UnsafeMutablePointer<Int32>) -> CGError

@_silgen_name("CGSGetDisplayModeDescriptionOfLength")
func CGSGetDisplayModeDescriptionOfLength(_ display: CGDirectDisplayID, _ idx: Int32,
                                          _ mode: UnsafeMutableRawPointer, _ length: Int32) -> CGError

@_silgen_name("CGSConfigureDisplayMode")
func CGSConfigureDisplayMode(_ config: CGDisplayConfigRef?, _ display: CGDirectDisplayID, _ modeNumber: Int32) -> CGError
```

### 1.2 모드 구조체 레이아웃

- 구조체 길이: 212바이트(0xD4). displayplacer, Crisp, AwesomeDisplay 모두 `length`에 0xD4 전달. AwesomeDisplay 노트는 과거 CGSInternal 헤더의 260바이트 레이아웃이 현재 macOS와 맞지 않는다고 보고.
- 필드 오프셋 (AllRez의 `CGSDisplayModeDescription`, displayplacer의 `modes_D4`, Crisp 헤더 종합)

| 오프셋 | 타입 | 내용 | 근거 |
|---|---|---|---|
| 0x00 | uint32 | 모드 번호 | displayplacer, AllRez, Crisp |
| 0x04 | uint32 | 플래그. Crisp 헤더 주석 기준 0x40000000 비트가 데스크톱 GUI 사용 불가 표시 | AllRez, Crisp |
| 0x08 | uint32 | 논리 폭 (포인트) | 3개 저장소 공통 |
| 0x0C | uint32 | 논리 높이 (포인트) | 3개 저장소 공통 |
| 0x10 | uint32 | depth 형식 | 3개 저장소 공통 |
| 0x14 | uint32 | bytesPerRow | AllRez |
| 0x18 | uint32 | bitsPerPixel | AllRez |
| 0x1C | uint32 | bitsPerSample (8 또는 10) | AllRez |
| 0x20 | uint32 | samplesPerPixel | AllRez |
| 0x24 | uint32 | 정수 주사율 | AllRez |
| 0xBC | uint32 | 주사율 16.16 고정소수점. 상위 16비트(오프셋 0xBE)가 정수 Hz. displayplacer의 `freq` 필드와 같은 위치 | AllRez, displayplacer |
| 0xC0 | uint32 | IOFlags | AllRez |
| 0xC4 | uint32 | IODisplayModeID | AllRez |
| 0xC8 | uint32 | 실제 픽셀 폭 (HiDPI에서 논리 폭의 2배) | AllRez |
| 0xCC | uint32 | 실제 픽셀 높이 | AllRez |
| 0xD0 | float | 배율. 1.0 일반, 2.0 HiDPI | displayplacer, AllRez, Crisp |

- 저장소 간 불일치 항목
  - 모드 번호 의미: AllRez 주석은 "0부터 모드 수 - 1까지의 인덱스"로, 0xC4의 IODisplayModeID와 별개로 기술. Crisp 헤더 주석과 AwesomeDisplay 노트는 모드 번호가 `CGDisplayModeGetIODisplayModeID` 값과 같다고 기술. Apple Silicon에서의 관계는 로컬 실측 필요.
  - 0x14-0xBB 구간: AllRez만 필드명 부여. 나머지 저장소는 미해석 영역으로 처리.

### 1.3 동작 보고

- 공개 열거의 한계: `CGDisplayCopyAllDisplayModes`는 실제 EDID 타이밍과 겹치는 GPU 스케일 HiDPI 변형을 숨김. CGS 목록에는 포함됨 (Crisp 헤더 주석). 외장 디스플레이 네이티브 크기의 HiDPI 모드(예: 6880x2880 백킹의 3440x1440)는 CGS 경로로만 적용 가능했다는 보고 (Crisp 조사 노트, 2026-11-02 기록).
- `CGSConfigureDisplayMode` 첫 인자: `CGBeginDisplayConfiguration`이 돌려준 설정 토큰. 연결 ID 전달 시 macOS 26에서 `checkCapacity()` 내부 세그멘테이션 오류 보고 (Crisp 조사 노트).
- 모드 번호 변동: HiDPI 오버라이드 주입과 제거, 재연결, 잠자기와 깨어남 뒤 모드 목록 재구성 시 번호 재할당 보고 (같은 타이밍이 130에서 683으로 변경). 저장과 복원은 폭, 높이, 주사율, HiDPI 여부로 대조 필요 (Crisp 조사 노트).
- 미러 대상 디스플레이: `CGConfigureDisplayWithDisplayMode`가 응답 없이 멈추거나 실패. 미러 원본에 모드 적용 필요 (Crisp 조사 노트).
- lumen은 `kCGDisplayShowDuplicateLowResolutionModes` 옵션 열거와 `CGConfigureDisplayWithDisplayMode` 조합만 사용 (macOS 26 대상).
- 회전 상태별 목록: displayplacer README 기준 현재 회전 상태의 해상도만 열거됨.

### 1.4 출처

- https://developer.apple.com/documentation/coregraphics/cgdisplaycopyalldisplaymodes(_:_:) (문서)
- https://developer.apple.com/documentation/coregraphics/kcgdisplayshowduplicatelowresolutionmodes (문서)
- https://developer.apple.com/documentation/coregraphics/cgconfiguredisplaywithdisplaymode(_:_:_:_:) (문서)
- https://github.com/jakehilborn/displayplacer/blob/master/src/Header.h (소스: modes_D4, CGS 선언)
- https://github.com/jakehilborn/displayplacer/blob/master/src/DisplayPlacer.c (소스: CGS 호출 순서)
- https://github.com/joevt/AllRez/blob/main/AllRez/AppleMisc.h (소스: CGSDisplayModeDescription 상세 필드)
- https://github.com/didriksg/Crisp/blob/main/Crisp/Crisp-Bridging-Header.h (소스: 선언과 주석)
- https://github.com/didriksg/Crisp/blob/main/docs/display-notes.md (문서: ResolutionService 항목의 측정 기록)
- https://github.com/MehbubRashid/AwesomeDisplay/blob/main/DEVELOPMENT.md (문서: 212바이트 구조체 재측정 기록)
- https://github.com/shashvat1965/lumen/blob/main/Sources/Display.swift (소스)
- https://github.com/jakehilborn/displayplacer/blob/master/src/Headers/MonitorPanel.framework/Headers/MPDisplay.h (소스: class-dump 헤더)
- RDM 저장소(https://github.com/avibrazil/RDM): 이번 조사에서 원문 미열람. 미확인.

## 2. HiDPI 강제

### 2.1 CGVirtualDisplay와 미러링 방식

| API | 프레임워크 | 선언 | 확인 |
|---|---|---|---|
| CGVirtualDisplayDescriptor | CoreGraphics (비공개 클래스) | 속성: `queue`, `name`, `maxPixelsWide`, `maxPixelsHigh`, `sizeInMillimeters`, `vendorID`, `productID`, `serialNum`, `terminationHandler`. Crisp 헤더는 `whitePoint`, `redPrimary`, `greenPrimary`, `bluePrimary`도 선언 | 소스 |
| CGVirtualDisplayMode | 위와 같음 | `initWithWidth:height:refreshRate:` | 소스 |
| CGVirtualDisplaySettings | 위와 같음 | 속성: `modes`, `hiDPI` (DeskPad 헤더는 `unsigned int`, Crisp 헤더는 `BOOL`) | 소스 |
| CGVirtualDisplay | 위와 같음 | `initWithDescriptor:`, `applySettings:`, `displayID` | 소스 |
| CGConfigureDisplayMirrorOfDisplay | CoreGraphics (공개) | `CGError CGConfigureDisplayMirrorOfDisplay(CGDisplayConfigRef, CGDirectDisplayID display, CGDirectDisplayID master)` | 문서 |

- 절차: (1) HiDPI 가상 디스플레이 생성, (2) 가상 디스플레이를 원하는 HiDPI 모드로 설정, (3) 실제 패널을 가상 디스플레이의 미러로 구성.
- 동작 보고 (Crisp 조사 노트, macOS 14 이상 대상 앱의 측정 기록)
  - `CGVirtualDisplay(descriptor:)`는 메인 스레드 필요. 다른 스레드에서 nil 반환.
  - `productID`와 `serialNum`은 구성별로 고유하고 재생성 간 동일해야 함. macOS가 디스플레이별 설정을 이 식별값으로 저장.
  - 모드 객체 수 약 400개 초과 시 `applySettings`가 전체 집합 거부.
  - 미러용 가상 디스플레이는 2배 백킹 크기와 절반 크기 픽셀 모드를 함께 선언해야 적용 가능한 모드 생성. 백킹만 선언한 경우 열거는 되지만 적용 실패 (5K2K 패널 기록).
  - 고해상도 가상 디스플레이 생성 직후 macOS가 스케일 모드를 기본값으로 지정. 원하는 모드 재적용 필요.
  - 해제 순서: 미러 해제 후 가상 디스플레이 파기.
  - 가상 디스플레이는 프로세스 종료 시 소멸.
  - WindowServer 스케일 백킹 한도: 5K2K 울트라와이드에서 폭 약 6720픽셀 초과 백킹 거부. 가상 디스플레이 미러 방식은 이 한도 적용을 받지 않음.
- AwesomeDisplay 노트: 미러링만으로는 HiDPI가 되지 않음. macOS가 가상 디스플레이의 1배 모드를 선택하므로 미러 구성 뒤 2배 모드를 따로 적용해야 함.

### 2.2 디스플레이 오버라이드 plist 방식

- 경로: `/Library/Displays/Contents/Resources/Overrides/DisplayVendorID-<16진수>/DisplayProductID-<16진수>` (Crisp 코드의 형식 문자열은 `%x`).
- 키: `DisplayVendorID`, `DisplayProductID`, `scale-resolutions`. `scale-resolutions` 항목은 백킹 폭과 높이를 각각 4바이트 빅엔디언으로 이은 8바이트 Data.
- 권한: 해당 디렉터리는 root 소유. 관리자 권한 쓰기 필요. 읽기는 권한 불필요.
- Apple Silicon 유효성 (Crisp 조사 노트의 측정 기록)
  - `scale-resolutions` 오버라이드는 Apple Silicon에서 적용됨. 오버라이드 제거 시 모드 수 149에서 113, 복원 시 113에서 149로 변화 기록.
  - 반영 시점: 재연결, 재부팅, 또는 디스플레이 비활성화 후 재활성화(9절의 `SLSConfigureDisplayEnabled`). `IOServiceRequestProbe`와 `SLSDetectDisplays`는 이 용도로 효과 없음.
  - 재활성화 방식은 화면이 약 1초 꺼짐. 노트북에서 유일한 활성 디스플레이를 끄면 즉시 Clamshell Sleep 진입. Crisp는 임시 가상 디스플레이를 유지해 회피.
  - HiDPI 백킹을 패널보다 크게 렌더링하지 않는 칩(A18 Pro 탑재 MacBook Neo)에서는 추가 스케일 모드 전부 거부.
- 오버라이드의 `IODisplayEDID` 키: Apple Silicon에서 무시된다는 서술 (Make-M1-Great-Again의 avedid.swift 주석). 대체 경로는 `IOAVServiceSetVirtualEDIDMode` (11절).
- macOS 15 제약: BetterDisplay 토론 3406에서 개발자가 "Sequoia가 M1과 보급형 Mac에 더 엄격한 한도 도입, HDR 모드에서 더 심함"이라고 답변.

### 2.3 출처

- https://github.com/Stengo/DeskPad/blob/main/DeskPad/CGVirtualDisplayPrivate.h (소스)
- https://github.com/didriksg/Crisp/blob/main/Crisp/Crisp-Bridging-Header.h (소스)
- https://github.com/didriksg/Crisp/blob/main/docs/display-notes.md (문서: MirroredModeService, VirtualDisplayService, HiDPIService, softReconnect 항목)
- https://github.com/didriksg/Crisp/blob/main/Crisp/Services/HiDPIService.swift (소스: 경로 형식, scale-resolutions 인코딩)
- https://github.com/MehbubRashid/AwesomeDisplay/blob/main/DEVELOPMENT.md (문서)
- https://github.com/jqqqqqqqqqq/Make-M1-Great-Again/blob/main/avedid.swift (소스: 주석과 IOAVServiceSetVirtualEDIDMode 사용)
- https://github.com/waydabber/BetterDisplay/discussions/3406 (문서)
- https://developer.apple.com/documentation/coregraphics/cgconfiguredisplaymirrorofdisplay(_:_:_:) (문서)

## 3. HDR 켜기, 끄기, 상태 조회와 XDR 밝기 업스케일

### 3.1 HDR API 목록

| API | 프레임워크 | 선언 | 확인 |
|---|---|---|---|
| SLSDisplaySupportsHDRMode | SkyLight | `bool SLSDisplaySupportsHDRMode(CGDirectDisplayID display)` | 소스 |
| SLSDisplayIsHDRModeEnabled | SkyLight | `bool SLSDisplayIsHDRModeEnabled(CGDirectDisplayID display)` | 소스 |
| SLSDisplaySetHDRModeEnabled | SkyLight | `CGError SLSDisplaySetHDRModeEnabled(CGDirectDisplayID display, bool enable, int, int)` | 소스 |
| CGSIsHDRSupported | CoreGraphics | `bool CGSIsHDRSupported(CGDirectDisplayID display)` | 소스 |
| CGSIsHDREnabled | CoreGraphics | `bool CGSIsHDREnabled(CGDirectDisplayID display)` | 소스 |
| CGSEnableHDR | CoreGraphics | `CGError CGSEnableHDR(CGDirectDisplayID display, bool enable, int, int)` | 소스 |
| MPDisplay hasHDRModes, preferHDRModes, setPreferHDRModes: | MonitorPanel | `@property(readonly) BOOL hasHDRModes; - (BOOL)preferHDRModes; - (void)setPreferHDRModes:(BOOL)arg1;` | 소스 |
| CoreDisplay_Display_SetHDRModeEnabled 외 | CoreDisplay | tbd 등재만 확인. 시그니처 미확인 | 미확인 |
| NSScreen maximumExtendedDynamicRangeColorComponentValue | AppKit (공개) | 현재 EDR 헤드룸 | 문서 |
| NSScreen maximumPotentialExtendedDynamicRangeColorComponentValue | AppKit (공개) | 잠재 최대 EDR 헤드룸 | 문서 |
| NSScreen maximumReferenceExtendedDynamicRangeColorComponentValue | AppKit (공개) | 레퍼런스 모드 EDR 값 | 문서 |

- Swift 선언 예시 (lumen, HDReenable 형식)

```swift
typealias SLSSetHDR = @convention(c) (CGDirectDisplayID, Bool, Int32, Int32) -> CGError
typealias SLSBoolQuery = @convention(c) (CGDirectDisplayID) -> Bool
// dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight") 후
// dlsym으로 "SLSDisplaySetHDRModeEnabled", "SLSDisplayIsHDRModeEnabled", "SLSDisplaySupportsHDRMode" 획득
```

### 3.2 HDR 동작 보고

- SLS 계열: AllRez는 macOS 11 이상에서 사용 가능으로 표기. lumen(macOS 26 대상), HDReenable, fastfetch가 사용. 셋째와 넷째 인자는 모든 사용처에서 0 전달.
- 시그니처 불일치: AwesomeDisplay는 `SLSDisplaySetHDRModeEnabled`를 인자 2개 형태로 선언. 나머지 저장소는 4개 형태.
- CGS 계열: AllRez 주석 기준 `CGSIsHDREnabled`는 HDR 미지원 디스플레이에서도 1 반환 사례 있음. `CGSEnableHDR`는 동작하지 않는 것으로 추정한다는 주석. MonitorControl은 `CGSIsHDREnabled`, `CGSIsHDRSupported`만 조회 용도로 사용.
- MPDisplay 계열: mac-utils의 ToggleHDR.swift가 `preferHDRModes`, `setPreferHDRModes`, `hasHDRModes` 사용. macOS가 HDR 미지원으로 판단하는 디스플레이에 대해 60 Hz 모드로 전환 후 HDR 활성화 시도 로직 포함.
- HDR 강제: lumen은 (1) 지원 미표기 디스플레이에도 `SLSDisplaySetHDRModeEnabled` 호출, (2) 실패 시 PQ EOTF 색 모드로 링크 전환(4절) 순서로 시도.
- 부작용 보고 (Crisp 조사 노트): 디스플레이 집합 변경 시 WindowServer가 집합별 저장 배치를 재적용하며 HDR 상태도 포함. HDR 선호만 기록되고 모드가 적용되지 않은 상태에서는 화면이 뿌옇게 표시.
- DDC 영향 (Crisp 조사 노트): DisplayHDR 모니터는 HDR 모드에서 DDC 밝기 쓰기를 ack하면서 무시.

### 3.3 XDR 밝기 업스케일

- (a) EDR 오버레이 방식
  - 구성: 디스플레이별 전체 화면, 클릭 통과 창에 `CAMetalLayer`로 1.0 초과 EDR 색을 표시하고 `compositingFilter`를 곱셈 블렌드로 지정. macOS가 EDR 헤드룸 확보를 위해 백라이트를 올림.
  - lumen: `compositingFilter = "multiplyBlendMode"`, 창 레벨 `.screenSaver`.
  - Crisp: WindowServer가 마지막 present 약 1초 뒤 창을 직접 스캔아웃으로 승격하며 필터를 버림. 오버레이를 5 fps로 계속 렌더링하고 `CGShieldingWindowLevel` 사용. BrightIntosh와 같은 기법이라는 서술.
  - 헤드룸 조회: `NSScreen.maximumExtendedDynamicRangeColorComponentValue`, `maximumPotentialExtendedDynamicRangeColorComponentValue`.
- (b) 감마 테이블 방식
  - 구성: EDR 상태 유도 후 `CGSetDisplayTransferByTable`에 1.0 초과 값을 포함한 테이블 적용.
  - BrightIntosh의 GammaTechnique.swift가 이 방식 구현. `CGGetDisplayTransferByTable`로 원본 저장, `CGDisplayRestoreColorSyncSettings`로 복원.
  - Crisp는 외장 HDR 모니터에 이 방식 사용. 외장 모니터의 보고 헤드룸은 신뢰 불가(1.2로 고정 표시된 상태에서 2.87배 테이블 스케일이 실제 밝기 증가 제공)라는 측정 기록.
- (c) 프리셋 방식: BetterDisplay v4.1.5 릴리스 노트에 "macOS Tahoe 26.3의 프리셋 검증 강화로 네이티브 XDR 업스케일 제거" 기재. v4.3.3에서 "내장 XDR 디스플레이 직접 밝기 업스케일" 추가. 구현 방법 미확인.
- 지원 기기 (BrightIntosh README): MacBook Pro 14형과 16형(M1 이후), Pro Display XDR, Studio Display XDR(실험적).
- 제약: BrightIntosh README 기준 활성 중 HDR 영상 클리핑. AwesomeDisplay 노트 기준 감마 테이블은 호출 프로세스 종료 시 원상 복구.

### 3.4 출처

- https://github.com/joevt/AllRez/blob/main/AllRez/AppleMisc.h (소스: SLS, CGS HDR 선언)
- https://github.com/joevt/AllRez/blob/main/AllRez/main.cpp (소스: 가용 버전 표기와 주석)
- https://github.com/shashvat1965/lumen/blob/main/Sources/Private.swift (소스)
- https://github.com/shashvat1965/lumen/blob/main/Sources/Display.swift (소스: HDR 강제 로직)
- https://github.com/shashvat1965/lumen/blob/main/Sources/XDRBoost.swift (소스)
- https://github.com/arcanelab/HDReenable/blob/main/Sources/HDRMenuApp/SkyLightHDR.swift (소스)
- https://github.com/MonitorControl/MonitorControl/blob/main/MonitorControl/Support/Bridging-Header.h (소스)
- https://github.com/alin23/mac-utils/blob/main/ToggleHDR.swift (소스)
- https://github.com/jakehilborn/displayplacer/blob/master/src/Headers/MonitorPanel.framework/Headers/MPDisplay.h (소스)
- https://github.com/niklasr22/BrightIntosh/blob/main/BrightIntosh/GammaTechnique.swift (소스)
- https://github.com/niklasr22/BrightIntosh/blob/main/README.md (문서)
- https://github.com/didriksg/Crisp/blob/main/docs/brightness-notes.md (문서)
- https://github.com/waydabber/BetterDisplay/releases/tag/v4.1.5 (문서)
- https://github.com/waydabber/BetterDisplay/issues/4936 (문서)
- https://developer.apple.com/documentation/appkit/nsscreen/maximumextendeddynamicrangecolorcomponentvalue (문서)
- https://developer.apple.com/documentation/appkit/nsscreen/maximumpotentialextendeddynamicrangecolorcomponentvalue (문서)
- https://developer.apple.com/documentation/appkit/nsscreen/maximumreferenceextendeddynamicrangecolorcomponentvalue (문서)
- Lunar의 XDR 구현 소스: 공개 저장소에서 해당 부분 미열람. 미확인.

## 4. 색 모드 조회와 설정

### 4.1 IORegistry 구조

- 디스플레이 노드 클래스: `AppleCLCD2`(M1 계열, M2, M3), `IOMobileFramebufferShim`(M2 Pro, Max, Ultra, M3 Pro, Max, M4와 M5 전체). 칩에 따른 구분이며 macOS 버전과 무관 (WhatCable 주석의 측정 기록).
- 노드 속성: `TimingElements`, `PreferredTimingElements`, `ColorElements`, `DPTimingModeId`, `DisplayAttributes`, `EDID UUID`, `IOMFBUUID`, `Transport`, `external`.
- `TimingElements`와 `PreferredTimingElements` 항목 키: `ID`, `HorizontalAttributes`, `VerticalAttributes`(하위 키 `Active`, `Total`, `FrontPorch`, `SyncWidth`, `PreciseSyncRate`), `IsInterlaced`, `IsVirtual`, `IsPreferred`, `Score`, `ColorModes`, `DSCRequiredColorElementIDs`, `UnsafeColorElementIDs`, `ValidPixelEncodings`, `MinimumVariableRefreshRate`, `MaximumVariableRefreshRate`.
- `ColorModes`와 `ColorElements` 항목 키: `ID`, `Depth`, `PixelEncoding`, `DynamicRange`, `EOTF`, `Colorimetry`, `Score`, `IsVirtual`, `SupportsDSC`, `DownstreamFormat`(변환기 경유 시).
- `PreciseSyncRate`는 16.16 고정소수점 주사율.
- 외장 패널의 실제 타이밍은 대부분 `PreferredTimingElements`에 있고 `TimingElements`에는 가상 HDR 항목이 들어간다는 보고 (WhatCable 주석).
- 현재 타이밍: `DPTimingModeId` 속성.
- 현재 색 모드: 레지스트리에 해당 키 없음 (WhatCable 주석). 4.2의 API로 조회.

### 4.2 IOMobileFramebuffer 비공개 API

| API | 선언 | 확인 |
|---|---|---|
| IOMobileFramebufferOpen | `kern_return_t IOMobileFramebufferOpen(io_service_t service, mach_port_t task, uint32_t type, IOMobileFramebufferRef *out)` | 소스 |
| IOMobileFramebufferGetDigitalOutMode | `kern_return_t IOMobileFramebufferGetDigitalOutMode(IOMobileFramebufferRef fb, uint32_t *colorModeID, uint32_t *timingModeID)` | 소스 |
| IOMobileFramebufferSetDigitalOutMode | `kern_return_t IOMobileFramebufferSetDigitalOutMode(IOMobileFramebufferRef fb, uint32_t colorModeID, uint32_t timingModeID)` | 소스 |
| IOMobileFramebufferGetSupportedDigitalOutModes | tbd 등재만 확인. macOS에서의 시그니처와 사용 예 미확인 | 미확인 |
| IOAVVideoInterfaceCopyTimingElements, IOAVVideoInterfaceCopyColorElements, IOAVVideoInterfaceCopyDisplayAttributes | IOKit tbd 등재만 확인 | 미확인 |

- Swift 선언 예시 (lumen 형식)

```swift
// dlopen("/System/Library/PrivateFrameworks/IOMobileFramebuffer.framework/IOMobileFramebuffer")
typealias FBOpen = @convention(c) (io_service_t, mach_port_t, UInt32, UnsafeMutablePointer<OpaquePointer?>) -> Int32
typealias FBGetMode = @convention(c) (OpaquePointer, UnsafeMutablePointer<UInt32>, UnsafeMutablePointer<UInt32>) -> Int32
typealias FBSetMode = @convention(c) (OpaquePointer, UInt32, UInt32) -> Int32
```

- lumen의 절차
  - (1) `IOServiceMatching("IOMobileFramebuffer")`로 서비스 열거, `DisplayAttributes.ProductAttributes`의 `LegacyManufacturerID`, `ProductID`, `SerialNumber`를 `CGDisplayVendorNumber`, `CGDisplayModelNumber`, `CGDisplaySerialNumber`와 대조해 디스플레이 매칭.
  - (2) `IOMobileFramebufferOpen(service, mach_task_self_, 0, &ref)`.
  - (3) `IOMobileFramebufferGetDigitalOutMode`로 현재 색 모드 ID와 타이밍 ID 획득.
  - (4) 현재 타이밍 ID의 `TimingElements` 항목에서 `ColorModes` 목록 추출.
  - (5) `IOMobileFramebufferSetDigitalOutMode(ref, 새 색 모드 ID, 현재 타이밍 ID)`.
  - (6) 15초 내 사용자 확인이 없으면 이전 색 모드로 복귀.
- 인자 순서 교차 근거: Asahi Linux DCP 드라이버의 `dcp_set_digital_out_mode_req` 구조체가 `color_mode_id`, `timing_mode_id` 순서.
- 유지성: BetterDisplay v3.0.2 릴리스 노트에 "색 모드 선택은 기본적으로 모드 변경마다 선호 모드로 초기화되므로 구성 보호 기능 추가" 기재.

### 4.3 열거값 해석의 불일치

| 필드 | WhatCable (커널 IOAVFamily 이름표 기반이라는 주석) | Asahi Linux parser.h | lumen ColorModes.swift |
|---|---|---|---|
| PixelEncoding 0 | RGB 4:4:4 | RGB | RGB |
| PixelEncoding 1 | YCbCr 4:2:0 | YCbCr 4:2:0 | YCbCr 4:2:2 |
| PixelEncoding 2 | YCbCr 4:2:2 | YCbCr 4:4:4 | YCbCr 4:2:0 |
| PixelEncoding 3 | YCbCr 4:4:4 | YCbCr 4:2:2 | YCbCr 4:4:4 |
| PixelEncoding 4 이상 | Dolby Vision, 터널링 변형 (4-14) | 같은 범위 정의 | 정의 없음 |
| EOTF 0 | 해당 없음 | SDR gamma | SDR |
| EOTF 1 | 해당 없음 | HDR gamma | PQ(HDR10) |
| EOTF 2 | 해당 없음 | ST 2084 (PQ) | HLG |
| EOTF 3 | 해당 없음 | BT.2100 (HLG) | 정의 없음 |
| DynamicRange 0, 1 | 해당 없음 | Full, Limited | Full, Limited |

- lumen README는 일부 YCbCr 크로마 형식 표기가 미검증이라고 명시.
- PixelEncoding 1-3과 EOTF 1-3의 실제 의미는 로컬 실측 필요.
- IOGraphics의 `kIOPixelEncoding*`, `kIODynamicRange*` 비트마스크(AllRez 헤더에 수록)는 `IODisplayTimingRange` 용도의 다른 타입. DCP 노드 값과 혼용 불가 (WhatCable 주석).

### 4.4 com.apple.windowserver.displays.plist의 LinkDescription 수정 방식

- 대상 파일: `/Library/Preferences/com.apple.windowserver.displays.plist`와 사용자 홈의 `Library/Preferences/ByHost/com.apple.windowserver.displays.<UUID>.plist`.
- 추가 항목: 디스플레이 구성 딕셔너리의 `CurrentInfo` 아래에 `LinkDescription` 딕셔너리. 키와 값은 `BitDepth` 8, `EOTF` 0, `PixelEncoding` 0, `Range` 1 (RGB 풀 레인지 강제 목적).
- 절차: plist 편집 후 재부팅. gist는 `sudo killall -HUP WindowServer` 비권장으로 기재.
- 유효성 보고 (GetVladimir gist 본문과 댓글)
  - macOS 13.3 이후 재부팅 시 plist가 덮어써지는 사례.
  - macOS 15.1에서 USB-C to DisplayPort 연결 동작 보고. 15.4.1에서 색 문제 보고.
  - macOS 26.1 베타에서 PlistBuddy 방식이 더 이상 동작하지 않는다는 댓글. gist 작성자는 macOS 26 미사용.
  - 확인된 칩은 M1, M2 계열. M3 이후 보고 없음.
- 값 해석 불일치: fix_m1_rgb.py는 `PixelEncoding` 1과 `Range` 0을 `PixelEncoding` 0과 `Range` 1로 변경. MacVivid는 `Range` 0을 풀 레인지로 주석 처리. `Range` 값 의미는 로컬 실측 필요.

### 4.5 BetterDisplay의 색 모드(connection mode) 기능

- 공개 사실: v3.0.2(2024-08)에서 Apple Silicon 전용 Color Mode 메뉴 추가. 연결 비트 심도, 픽셀 인코딩, 크로마 서브샘플링, 레인지 변경. v4.3.3에서 HDR 강제와 SDR 프레임버퍼에 HDR 신호를 내보내는 혼합 모드 추가.
- 구현에 쓰인 API: 비공개 소스. 미확인.
- 동작 특성(모드 변경마다 초기화, 주사율별 색 모드 목록 차이)은 4.2의 `IOMobileFramebufferSetDigitalOutMode`와 `TimingElements[].ColorModes` 구조에 부합. 동일 API라는 직접 근거는 없음.

### 4.6 출처

- https://github.com/darrylmorley/whatcable/blob/main/Sources/WhatCableDarwinBackend/Reading/DisplayTimingReader.swift (소스: 노드 클래스, 키 이름, 주석의 측정 기록)
- https://github.com/darrylmorley/whatcable/blob/main/Sources/WhatCableCore/Display/DisplayPixelEncoding.swift (소스)
- https://github.com/AsahiLinux/linux/blob/asahi/drivers/gpu/drm/apple/parser.c (소스: 키 이름)
- https://github.com/AsahiLinux/linux/blob/asahi/drivers/gpu/drm/apple/parser.h (소스: 열거값)
- https://github.com/AsahiLinux/linux/blob/asahi/drivers/gpu/drm/apple/iomfb.h (소스: dcp_set_digital_out_mode_req)
- https://github.com/shashvat1965/lumen/blob/main/Sources/ColorModes.swift (소스)
- https://github.com/shashvat1965/lumen/blob/main/README.md (문서: 요구 사항 macOS 26, 미검증 표기 고지)
- https://github.com/glpi-project/glpi-agent/blob/develop/resources/macos/ioreg/AppleCLCD2 (소스: 공개 ioreg 덤프 샘플의 키 이름)
- https://github.com/alin23/Lunar/blob/master/Lunar/Utils/DisplayController.swift (소스: DisplayAttributes 하위의 TimingElements, ColorElements 키 처리)
- https://gist.github.com/GetVladimir/c89a26df1806001543bef4c8d90cc2f8 (문서)
- https://github.com/sudowork/fix_m1_rgb/blob/main/fix_m1_rgb.py (소스)
- https://github.com/etherian3/MacVivid/blob/main/Sources/macvivid/Core/ColorFixer.swift (소스)
- https://github.com/waydabber/BetterDisplay/releases/tag/v3.0.2 (문서)
- https://github.com/waydabber/BetterDisplay/releases/tag/v4.3.3 (문서)

## 5. DSC 상태, DP 링크 속도, HDMI FRL과 TMDS 정보

### 5.1 DSC 상태 조회

- 공개 자료에 나오는 ioreg 키
  - `ColorModes[].SupportsDSC`: 색 모드별 DSC 지원 표시.
  - `TimingElements[].DSCRequiredColorElementIDs`: 해당 타이밍에서 DSC가 필요한 색 모드 ID 목록.
  - `TimingElements[].UnsafeColorElementIDs`: 변환기의 TMDS 한도를 넘는 색 모드 ID 목록.
  - `maxPeakBpp`, `maxAverageBpp`: AppleCLCD2 공개 덤프 샘플에 존재. 의미 미확인.
- 판정 방법
  - WhatCable: 구동 중 타이밍의 `DSCRequiredColorElementIDs`와 `ColorModes`로 판정. Apple 디스플레이 노드 46개 중 45개가 링크와 무관하게 모든 타이밍에 DSC 목록을 싣는다는 측정 기록.
  - 현재 색 모드 ID(4.2의 `IOMobileFramebufferGetDigitalOutMode`)가 현재 타이밍의 `DSCRequiredColorElementIDs`에 포함되는지 대조하는 방법: 두 공개 근거를 조합한 추론. 이 조합을 구현한 공개 소스 미확인. 로컬 실측 필요.
- BetterDisplay v5: Display Information에 DSC 버전, 색 성분당 비트, 목표 bpp, 슬라이스 크기, DPCD 원시 페이로드 표시. 이슈 5484에 "IOKit IOAV* 호출과 I/O Registry 레코드에서 수집"이라고 기재. 호출 함수와 시그니처 미확인.
- 관련 심볼: `IOAVServiceGetLinkData`, `IOAVServiceGetLinkDataWithSource`, `IOAVDeviceGetLinkData`, `IOAVVideoInterfaceGetLinkData`가 macOS 26.5 SDK IOKit tbd에 등재. 시그니처와 공개 사용 예 미확인.

### 5.2 DSC 비활성화 가능 여부

- DSC를 직접 끄는 API나 설정 키: 공개 문서와 공개 소스에서 근거 미확인.
- 간접 경로 후보 (모두 미확인, 로컬 실측 필요)
  - `DSCRequiredColorElementIDs`에 없는 색 모드로 전환(4.2).
  - `IOAVServiceSetVirtualEDIDMode`로 DSC 능력을 뺀 EDID 적용(11절).
- 반대 사례: GetVladimir gist 댓글에 macOS 15.4 업데이트 뒤 DSC를 잃었다는 사용자 보고.

### 5.3 DP 링크 속도와 레인 수

- 노드 클래스: `IOPortTransportStateDisplayPort`.
- 속성: `Active`, `LinkRate`, `LinkRateDescription`, `LaneCount`, `MaxLaneCount`, `Tunneled`, `HPD_State`, `HPD_StateDescription`, `SinkCount`, `DFP Type`, `DFP Type Description`, `BranchDeviceID`, `BranchDeviceOUI`, `NominalSignalingFrequenciesHz`, `EDID`, `EDIDChanged`, `Metadata`, `ParentPortType`, `ParentPortTypeDescription`, `ParentPortNumber`, `ParentBuiltInPortType`, `ParentBuiltInPortNumber`, `TransportType`, `TransportTypeDescription`, `DriverStatus`, `ManufacturerName`, `ProductName`, `ProductID`, `SerialNumber`.
- 동작 보고 (WhatCable): macOS 14 이상, Apple Silicon에서 읽힘. 엔타이틀먼트와 비공개 API 없이 IOKit 레지스트리 읽기만 사용. App Sandbox 안에서도 같은 값이 읽혔다는 README 서술.
- 레인 분할 판정: `DisplayPortPinAssignment` 정수는 신뢰 불가. 같은 값이 2레인과 4레인 링크 모두에서 보고된 사례. WhatCable은 같은 링크의 USB3 활성 여부로 판정.
- 보조 노드: `AppleTypeCPhy`의 `Link Rate`, `AppleTypeCPhyDisplayPortPclk`, `AppleTypeCPhyDisplayPortTunnel`, `AppleTypeCPhyLane`.

### 5.4 HDMI FRL과 TMDS

- 내장 HDMI 포트: `AppleHPMInterface` 노드가 없고, 부모 포트 타입이 USB-C가 아닌 `IOPortTransportStateDisplayPort` 노드로 나타남. 디스플레이 연결 시에만 노드 존재 (WhatCable). Crisp 노트는 MacBook Pro의 HDMI 포트가 빈 상태에서도 DisplayPort 노드를 유지한다고 기록. 두 서술의 차이는 로컬 실측 필요.
- FRL, TMDS 관련 ioreg 키 이름: 공개 자료에서 미확인.
- 관련 심볼: `IOAVServiceGetFRLLinkData`, `IOAVServiceGetFRLMaxRate`, `IOAVServiceGetFRLMinRate`, `IOAVServiceSetFRLMaxRate`, `IOAVServiceSetFRLMinRate`, `IOAVServiceRetrainFRL`, `IOAVServiceGetFRLCharacterErrorCounts`가 macOS 26.5 SDK IOKit tbd에 등재. 시그니처와 공개 사용 예 미확인.
- 간접 정보: `ColorModes[].DownstreamFormat`(변환기 출력 형식), `UnsafeColorElementIDs`(TMDS 한도 초과 모드), 공개 덤프 샘플의 `HasHDMILegacyEDID`.

### 5.5 출처

- https://github.com/darrylmorley/whatcable/blob/main/Sources/WhatCableDarwinBackend/Reading/DisplayTimingReader.swift (소스)
- https://github.com/darrylmorley/whatcable/blob/main/Sources/WhatCableDarwinBackend/Watchers/DisplayPortTransportWatcher.swift (소스)
- https://github.com/darrylmorley/whatcable/blob/main/Sources/WhatCableCore/Display/IOPortTransportStateDisplayPort.swift (소스)
- https://github.com/darrylmorley/whatcable/blob/main/Sources/WhatCableCore/Display/DisplayPortLaneConfig.swift (소스)
- https://github.com/darrylmorley/whatcable/blob/main/Sources/WhatCableCore/Port/BuiltInDisplayPort.swift (소스)
- https://github.com/darrylmorley/whatcable/blob/main/README.md (문서)
- https://github.com/glpi-project/glpi-agent/blob/develop/resources/macos/ioreg/AppleCLCD2 (소스)
- https://github.com/waydabber/BetterDisplay/issues/5484 (문서)
- https://github.com/waydabber/BetterDisplay/releases/tag/v5.0.5 (문서)
- https://github.com/didriksg/Crisp/blob/main/docs/display-notes.md (문서: liveDisplayPortCount 항목)

## 6. DDC/CI

### 6.1 API 목록

| API | 프레임워크 | 선언 | 확인 |
|---|---|---|---|
| IOAVServiceCreate | IOKit (비공개 심볼) | `IOAVServiceRef IOAVServiceCreate(CFAllocatorRef allocator)` | 소스 |
| IOAVServiceCreateWithService | IOKit | `IOAVServiceRef IOAVServiceCreateWithService(CFAllocatorRef allocator, io_service_t service)` | 소스 |
| IOAVServiceReadI2C | IOKit | `IOReturn IOAVServiceReadI2C(IOAVServiceRef service, uint32_t chipAddress, uint32_t offset, void *outputBuffer, uint32_t outputBufferSize)` | 소스 |
| IOAVServiceWriteI2C | IOKit | `IOReturn IOAVServiceWriteI2C(IOAVServiceRef service, uint32_t chipAddress, uint32_t dataAddress, void *inputBuffer, uint32_t inputBufferSize)` | 소스 |
| CoreDisplay_DisplayCreateInfoDictionary | CoreDisplay | `CFDictionaryRef CoreDisplay_DisplayCreateInfoDictionary(CGDirectDisplayID)` | 소스 |

- `IOAVServiceRef`는 `CFTypeRef`로 선언 (MonitorControl, m1ddc, fastfetch).
- Swift 선언 예시 (lumen 형식)

```swift
typealias AVCreate = @convention(c) (CFAllocator?, io_service_t) -> Unmanaged<CFTypeRef>?
typealias AVWrite = @convention(c) (CFTypeRef, UInt32, UInt32, UnsafeMutableRawPointer, UInt32) -> IOReturn
typealias AVRead = @convention(c) (CFTypeRef, UInt32, UInt32, UnsafeMutableRawPointer, UInt32) -> IOReturn
```

### 6.2 DCPAVServiceProxy 탐색

- MonitorControl 방식: IOService 평면 전체 순회. `AppleCLCD2` 또는 `IOMobileFramebufferShim` 노드에서 `EDID UUID`, `DisplayAttributes`, `Transport` 수집 후, 뒤따르는 `DCPAVServiceProxy` 노드의 `Location`이 `External`이면 `IOAVServiceCreateWithService` 호출. CGDirectDisplayID 매칭은 `CoreDisplay_DisplayCreateInfoDictionary`의 `IODisplayLocation`(10점), 제조 연도와 주, 벤더, 제품 ID, 화면 크기, 제품명, 시리얼(각 1점) 점수 방식.
- m1ddc 방식: `CoreDisplay_DisplayCreateInfoDictionary`의 `IODisplayLocation` 경로로 프레임버퍼 엔트리 획득. 순회 중 `IOMobileFramebuffer` 클래스 엔트리의 레지스트리 ID가 일치한 뒤 처음 나오는 `Location`이 `External`인 `DCPAVServiceProxy` 사용.
- fastfetch 방식: `IOServiceMatching("DCPAVServiceProxy")`. `IOAVServiceUserInterfaceSupported`가 false면 제외. `Location`이 `Embedded`면 내장 디스플레이로 제외.
- 레지스트리 계층 (공개 ioreg 덤프): `DCPAVControllerProxy`, `DCPDPControllerProxy`, `DCPAVDeviceProxy`, `DCPDPDeviceProxy`, `DCPAVServiceProxy`, `DCPDPServiceProxy`, `DCPAVVideoInterfaceProxy`가 `dispext` 계열 노드 아래에 위치.

### 6.3 패킷 형식

- 칩 주소 0x37, 데이터 주소 0x51.
- 쓰기 패킷: `[0x80 | (명령 길이 + 1), 명령 길이, 명령 바이트들, 체크섬]`. Set VCP는 `[0x84, 0x03, VCP 코드, 값 상위, 값 하위, 체크섬]`.
- 읽기 요청: `[0x82, 0x01, VCP 코드, 체크섬]` 쓰기 후 `IOAVServiceReadI2C(service, 0x37, 0, reply, 11 또는 12)`.
- 응답: 바이트 6-7이 최댓값, 8-9가 현재값 (빅엔디언). 응답 체크섬 초깃값 0x50.
- 체크섬: XOR. MonitorControl은 읽기 요청에서 초깃값 0x6E, 쓰기에서 0x6E XOR 0x51 사용. m1ddc는 2026-10-29 커밋에서 Get VCP 요청 체크섬에 소스 주소를 포함하도록 수정.
- 타이밍 기본값 (MonitorControl): 쓰기 전 대기 10 ms, 쓰기 반복 2회, 읽기 전 대기 50 ms, 재시도 4회, 재시도 간격 20 ms.

### 6.4 VCP 코드

| 코드 | 기능 | 비고 | 근거 |
|---|---|---|---|
| 0x10 | 밝기 (luminance) | | m1ddc |
| 0x12 | 대비 | | m1ddc |
| 0x16, 0x18, 0x1A | 적, 녹, 청 게인 | | m1ddc |
| 0x60 | 입력 소스 | DisplayPort 1: 15, DisplayPort 2: 16, HDMI 1: 17, HDMI 2: 18, USB-C: 27 | m1ddc |
| 0xF4 | 입력 소스 대체 코드 | 일부 LG 디스플레이. DisplayPort 1: 208, DisplayPort 2: 209, HDMI 1: 144, HDMI 2: 145, USB-C: 210 | m1ddc |
| 0x62 | 음량 | | m1ddc |
| 0x8D | 음소거 | 1 켬, 2 끔 | m1ddc |
| 0xD6 | 전원(대기) | 값 체계는 이번 조사에서 원문 미확인 | m1ddc (코드만) |
| 0xE7 | KVM | 일부 Dell | m1ddc |
| 0xE8, 0xE9 | PBP 입력, PBP 모드 | 일부 Dell | m1ddc |
| 0xF3 | KVM | 일부 ASUS | m1ddc |

### 6.5 내장 HDMI 포트 제약

- MonitorControl README: 모든 M1 Mac(MacBook Pro 14형과 16형, Mac mini, Mac Studio)의 내장 HDMI 포트와 보급형 M2 Mac mini의 내장 HDMI 포트에서 DDC 미지원. USB-C 사용 권고.
- m1ddc: 2026-08-02 커밋 "Add DDC support for M1 built-in HDMI"에서 지원 추가. `DCPAVServiceProxy` 부모 엔트리의 `EPICProviderClass`가 `AppleDCPMCDP29XX`이면 칩 주소 0xB7 사용, 읽기 전 대기 50 ms.
- AwesomeDisplay 노트: 해당 저자의 Mac에서 DCP가 0x37과 0xB7 양쪽에 같은 버퍼 응답을 반환. 응답 주소만으로 칩 종류 판별 불가.
- AppleSiliconDDC README(m1ddc README 인용): 공개 코드에는 M1 HDMI 지원 누락.
- DisplayLink 연결: DDC 불가 (MonitorControl README).

### 6.6 위험 보고

- Crisp 조사 노트: 진행 중인 DDC I2C 읽기 뒤에서 WindowServer의 디스플레이 활성화가 대기하면 시스템 전체 정지. 6초 음량 읽기가 재연결 시 6초 시스템 정지 유발, 12초 읽기 사례 기록. Crisp는 디스플레이별 직렬 큐, 구성 변경 시 채널 매핑 전체 폐기, 디스플레이 활성화 트랜잭션 동안 DDC 보류 적용.
- AwesomeDisplay 노트: 다수 모니터가 Set VCP에는 반응하고 Get VCP에는 응답하지 않음. 읽기 성공 여부로 DDC 가용성을 판정하면 제어 가능한 모니터를 놓침. 칩 0x50의 EDID EEPROM 읽기로 버스 정상 여부 구분.
- BetterDisplay 토론 5940: M5 Pro, macOS 27.0.1, 240 Hz HiDPI 모드에서 밝기 변경 뒤 디스플레이 코프로세서 정지와 커널 패닉 사용자 보고. 개발자 답변 기준 원인 미확정.

### 6.7 출처

- https://github.com/MonitorControl/MonitorControl/blob/main/MonitorControl/Support/Bridging-Header.h (소스)
- https://github.com/MonitorControl/MonitorControl/blob/main/MonitorControl/Support/Arm64DDC.swift (소스)
- https://github.com/MonitorControl/MonitorControl/blob/main/README.md (문서)
- https://github.com/waydabber/m1ddc/blob/main/headers/i2c.h (소스: VCP 코드, 타이밍 상수)
- https://github.com/waydabber/m1ddc/blob/main/headers/ioregistry.h (소스: 칩 주소 0x37, 0xB7)
- https://github.com/waydabber/m1ddc/blob/main/sources/ioregistry.m (소스: 탐색과 MCDP29XX 판별)
- https://github.com/waydabber/m1ddc/blob/main/README.md (문서: 입력 소스 값)
- https://github.com/waydabber/AppleSiliconDDC (문서: README)
- https://github.com/fastfetch-cli/fastfetch/blob/dev/src/detection/brightness/brightness_apple.c (소스)
- https://github.com/robre/ioreg-archive/blob/master/ioreg-MacBookPro18,3-A2442-13.1.txt (소스: 레지스트리 계층)
- https://github.com/didriksg/Crisp/blob/main/docs/ddc-notes.md (문서)
- https://github.com/didriksg/Crisp/blob/main/docs/display-notes.md (문서: PhysicalDisplayToggleService 항목)
- https://github.com/MehbubRashid/AwesomeDisplay/blob/main/DEVELOPMENT.md (문서)
- https://github.com/waydabber/BetterDisplay/discussions/5940 (문서)
- Lunar의 DDC 소스(Lunar/DDC/DDC.swift): 이번 조사에서 상세 미열람. 미확인.

## 7. 내장 및 Apple 디스플레이 밝기

### 7.1 API 목록

| API | 프레임워크 | 선언 | 확인 |
|---|---|---|---|
| DisplayServicesGetBrightness | DisplayServices | `int DisplayServicesGetBrightness(CGDirectDisplayID display, float *brightness)` | 소스 |
| DisplayServicesSetBrightness | DisplayServices | `int DisplayServicesSetBrightness(CGDirectDisplayID display, float brightness)` | 소스 |
| DisplayServicesSetBrightnessSmooth | DisplayServices | `int DisplayServicesSetBrightnessSmooth(CGDirectDisplayID display, float brightness)` | 소스 |
| DisplayServicesCanChangeBrightness | DisplayServices | `bool DisplayServicesCanChangeBrightness(CGDirectDisplayID display)` | 소스 |
| DisplayServicesGetLinearBrightness, DisplayServicesSetLinearBrightness | DisplayServices | `int ...(CGDirectDisplayID display, float *brightness)`, `int ...(CGDirectDisplayID display, float brightness)` | 소스 |
| DisplayServicesRegisterForBrightnessChangeNotifications | DisplayServices | `int ...(CGDirectDisplayID display, CGDirectDisplayID displayObserver, CFNotificationCallback callback)` | 소스 |
| CoreDisplay_Display_GetUserBrightness | CoreDisplay | `double CoreDisplay_Display_GetUserBrightness(CGDirectDisplayID display)` | 소스 |
| CoreDisplay_Display_SetUserBrightness | CoreDisplay | `void CoreDisplay_Display_SetUserBrightness(CGDirectDisplayID display, double brightness)` | 소스 |

- Swift 선언 예시 (lumen 형식)

```swift
typealias DSGet = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
typealias DSSet = @convention(c) (CGDirectDisplayID, Float) -> Int32
typealias DSCan = @convention(c) (CGDirectDisplayID) -> Bool
// dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices")
```

### 7.2 동작 보고

- DisplayServices 계열: lumen(macOS 26 대상), MonitorControl, Lunar, mac-utils, Crisp, AwesomeDisplay가 사용. 값 범위 0.0-1.0.
- macOS 26에서의 CoreDisplay 계열: Crisp 조사 노트 기준 `CoreDisplay_Display_GetUserBrightness`가 1.0으로 고정(슬라이더 변경 시 DisplayServices 값은 0.97에서 0.72로 변화, CoreDisplay 값은 1.0 유지). 조회는 `DisplayServicesGetBrightness`만 실제 값 추적.
- `CoreDisplay_Display_SetUserBrightness`의 macOS 26 동작: 미확인. 로컬 실측 필요.
- 대상 판별: `DisplayServicesCanChangeBrightness`로 제어 가능 여부 확인 (mac-utils). MonitorControl은 Apple 디스플레이를 별도 클래스(AppleDisplay.swift)에서 DisplayServices로 제어.
- 대체 경로: `IODisplayGetFloatParameter` (Crisp가 마지막 순위로 사용). Apple Silicon 동작 미확인.

### 7.3 출처

- https://github.com/alin23/Lunar/blob/master/Lunar/DDC/Lunar-Bridging-Header.h (소스: DisplayServices, CoreDisplay 선언 전체)
- https://github.com/MonitorControl/MonitorControl/blob/main/MonitorControl/Support/Bridging-Header.h (소스)
- https://github.com/MonitorControl/MonitorControl/blob/main/MonitorControl/Model/AppleDisplay.swift (소스)
- https://github.com/shashvat1965/lumen/blob/main/Sources/Private.swift (소스)
- https://github.com/alin23/mac-utils/blob/main/SetNativeBrightness.swift (소스)
- https://github.com/didriksg/Crisp/blob/main/docs/brightness-notes.md (문서: Auto brightness 항목)

## 8. 회전

### 8.1 API 목록

| API | 프레임워크 | 선언 | 확인 |
|---|---|---|---|
| MPDisplay orientation, canChangeOrientation | MonitorPanel | `@property(nonatomic) int orientation; - (BOOL)canChangeOrientation; - (id)initWithCGSDisplayID:(int)arg1;` | 소스 |
| SLSSetDisplayRotation (형태 A) | SkyLight | `CGError SLSSetDisplayRotation(CGDirectDisplayID display, int rotation)` | 소스 |
| SLSSetDisplayRotation (형태 B) | SkyLight | `CGError SLSSetDisplayRotation(CGSConnectionID cid, CGDirectDisplayID display, float rotation)` | 소스 |
| CGDisplayRotation | CoreGraphics (공개) | `double CGDisplayRotation(CGDirectDisplayID display)`. 조회 전용 | 문서 |
| CGSSetDisplayRotation | CoreGraphics | macOS 14.5, 15.5, 26.5 SDK의 CoreGraphics tbd에 없음 | 소스 |
| IOServiceRequestProbe(kIOFBSetTransform) | IOKit | DCP 구동 디스플레이에서 동작 없음 (Crisp 헤더 주석). 선언 원문은 이번 조사에서 미열람 | 소스 |
| IOAVVideoInterfaceSetRotation | IOKit | tbd 등재만 확인 | 미확인 |

### 8.2 동작 보고

- MPDisplay 방식: displayplacer가 `[[MPDisplay alloc] initWithCGSDisplayID:]` 후 `setOrientation:` 호출. 비동기 적용이라 `CGDisplayRotation`이 목표값이 될 때까지 최대 10초 대기. mac-utils의 RotateDisplay.swift도 `MPDisplayMgr`와 `MPDisplay.orientation` 사용. 값은 0, 90, 180, 270.
- SLSSetDisplayRotation 방식: Crisp와 knoll은 형태 A로 선언하고 호출. Crisp 헤더 주석은 "`CGBeginDisplayConfiguration` 트랜잭션 밖에서 호출", "기존 `IOServiceRequestProbe` 경로는 DCP 구동 디스플레이에서 아무 동작 없음"이라고 기재. AwesomeDisplay는 형태 B로 선언. 두 형태 중 실제 시그니처는 로컬 실측 필요.
- 내장 디스플레이 회전: displayplacer 도움말에 "컴퓨터가 충돌할 수 있으나 재부팅 뒤 회전 적용"이라는 경고.
- 회전과 미러: displayplacer 주석 기준 회전 변경 시 macOS가 미러링을 자동 활성화하는 경우가 있어 회전 뒤 미러 해제 수행.
- 회전과 모드 목록: 회전 상태에 따라 열거되는 해상도가 달라지므로 회전 적용 후 모드 설정 (displayplacer).

### 8.3 출처

- https://github.com/jakehilborn/displayplacer/blob/master/src/MonitorPanel.m (소스)
- https://github.com/jakehilborn/displayplacer/blob/master/src/DisplayPlacer.c (소스: 순서와 경고 문구)
- https://github.com/alin23/mac-utils/blob/main/RotateDisplay.swift (소스)
- https://github.com/didriksg/Crisp/blob/main/Crisp/Crisp-Bridging-Header.h (소스)
- https://github.com/didriksg/Crisp/blob/main/Crisp/Services/PhysicalDisplayToggleService.swift (소스: 호출부)
- https://github.com/gawashburn/knoll/blob/main/src/core_graphics.rs (소스)
- https://github.com/MehbubRashid/AwesomeDisplay/blob/main/Sources/AwesomeDisplayCore/PrivateAPI/SkyLight.swift (소스)
- https://developer.apple.com/documentation/coregraphics/cgdisplayrotation(_:) (문서)

## 9. 디스플레이 연결 해제, 재연결, 미러, 배치, 메인 지정

### 9.1 API 목록

| API | 프레임워크 | 선언 | 확인 |
|---|---|---|---|
| CGSConfigureDisplayEnabled | CoreGraphics | `CGError CGSConfigureDisplayEnabled(CGDisplayConfigRef config, CGDirectDisplayID display, bool enabled)` | 소스 |
| SLSConfigureDisplayEnabled | SkyLight | `CGError SLSConfigureDisplayEnabled(CGDisplayConfigRef config, CGDirectDisplayID display, bool enabled)` | 소스 |
| SLSGetDisplayList | SkyLight | `CGError SLSGetDisplayList(uint32_t maxDisplays, CGDirectDisplayID *displays, uint32_t *displayCount)` | 소스 |
| CGBeginDisplayConfiguration | CoreGraphics (공개) | `CGError CGBeginDisplayConfiguration(CGDisplayConfigRef *config)` | 문서 |
| CGConfigureDisplayOrigin | CoreGraphics (공개) | `CGError CGConfigureDisplayOrigin(CGDisplayConfigRef, CGDirectDisplayID, int32_t x, int32_t y)` | 문서 |
| CGConfigureDisplayMirrorOfDisplay | CoreGraphics (공개) | `CGError CGConfigureDisplayMirrorOfDisplay(CGDisplayConfigRef, CGDirectDisplayID display, CGDirectDisplayID master)` | 문서 |
| CGCompleteDisplayConfiguration | CoreGraphics (공개) | `CGError CGCompleteDisplayConfiguration(CGDisplayConfigRef, CGConfigureOption)` | 문서 |
| MPDisplayMgr 미러 메서드 | MonitorPanel | `createMirrorSet:`, `stopAllMirroring`, `setMirrorMaster:useBestMode:` 등 | 소스 |

- 호출 순서: `CGBeginDisplayConfiguration` 후 활성화 변경 또는 배치 변경 호출, `CGCompleteDisplayConfiguration(config, kCGConfigurePermanently)`.
- 메인 디스플레이 지정: 전역 좌표 원점 (0,0)에 놓인 디스플레이가 메인 (Apple 문서의 `CGConfigureDisplayOrigin` 설명).
- 미러 해제: `CGConfigureDisplayMirrorOfDisplay(config, display, kCGNullDirectDisplay)`.

### 9.2 연결 해제 동작 보고

- Apple Silicon: `SLSConfigureDisplayEnabled`로 비활성화하면 `CGGetOnlineDisplayList`, `CGGetActiveDisplayList`에서 제외. `SLSGetDisplayList`에는 계속 열거되어 재연결 시 ID 회수에 사용 (Crisp). Crisp 헤더 주석은 macOS 13 이상에서 클램셸과 동일한 실제 분리라고 기재.
- Intel: 실제 분리가 수행되지 않음 (Crisp). displayplacer 구조체 주석은 "화면을 끄지 않고 검게 만들 뿐"이라고 기재.
- 사용 저장소: displayplacer(CGS 이름), Crisp와 lumen(SLS 이름), AwesomeDisplay(CGS 이름).
- 위험 보고
  - 마지막 활성 디스플레이 비활성화: 노트북에서 `PreventSystemSleep` 어서션이 있어도 즉시 Clamshell Sleep 진입 (Crisp).
  - 내장 디스플레이를 끈 상태에서 외장 케이블 분리: 활성 디스플레이 0개 상태가 되며 macOS가 스스로 재활성화하지 않음. 앱 측 복구 로직 필요 (Crisp).
  - 덮개 닫힘 직전 활성화 요청: 성공 반환 후 디스플레이가 로그아웃 전까지 켜지지 않는 사례 (Crisp 이슈 246 기록).
  - `CGCompleteDisplayConfiguration` 지연: 링크 재학습 동안 약 10초 차단, WindowServer가 한 커밋을 29.5초 보유한 사례. 반환값은 양방향으로 신뢰 불가이며 열거 결과로만 판정 (Crisp).
  - 보급형 M3 칩 MacBook: 내장 디스플레이 연결 해제 후 재연결에 덮개 여닫기 또는 재시동 필요. BetterDisplay v5.0.6에서 해당 기종의 내장 디스플레이 연결 해제를 기본 비활성화 (이슈 4723).
  - 디스플레이 집합 변경 시 WindowServer가 집합별 저장 배치(모드, 회전, HDR)를 즉시 재적용. 다른 디스플레이의 모드가 바뀌는 사례 (Crisp 이슈 108 기록).
  - 비활성화 중 DDC I2C 진행: 6.6의 시스템 정지 보고.

### 9.3 출처

- https://github.com/jakehilborn/displayplacer/blob/master/src/Header.h (소스)
- https://github.com/jakehilborn/displayplacer/blob/master/src/DisplayPlacer.c (소스)
- https://github.com/didriksg/Crisp/blob/main/Crisp/Crisp-Bridging-Header.h (소스)
- https://github.com/didriksg/Crisp/blob/main/docs/display-notes.md (문서: PhysicalDisplayToggleService, restoreStates, softReconnect, restoreIfNoActiveDisplay 항목)
- https://github.com/shashvat1965/lumen/blob/main/Sources/Private.swift (소스)
- https://github.com/alin23/mac-utils/blob/main/MirrorMacBookToMonitor.swift (소스)
- https://github.com/jakehilborn/displayplacer/blob/master/src/Headers/MonitorPanel.framework/Headers/MPDisplayMgr.h (소스)
- https://github.com/waydabber/BetterDisplay/issues/4723 (문서)
- https://github.com/waydabber/BetterDisplay/releases/tag/v5.0.6 (문서)
- https://developer.apple.com/documentation/coregraphics/cgbegindisplayconfiguration(_:) (문서)
- https://developer.apple.com/documentation/coregraphics/cgconfiguredisplayorigin(_:_:_:_:) (문서)
- https://developer.apple.com/documentation/coregraphics/cgconfiguredisplaymirrorofdisplay(_:_:_:) (문서)
- https://developer.apple.com/documentation/coregraphics/cgcompletedisplayconfiguration(_:_:) (문서)

## 10. 색: ColorSync 프로파일, 감마 테이블, Night Shift, True Tone

### 10.1 ColorSync 프로파일 지정

- API (공개): `bool ColorSyncDeviceSetCustomProfiles(CFStringRef deviceClass, CFUUIDRef deviceID, CFDictionaryRef profileInfo)`.
- 인자 구성 (mac-utils의 ApplyColorProfile.swift): `deviceClass`는 `kColorSyncDisplayDeviceClass`, `deviceID`는 디스플레이 UUID(mac-utils는 `MPDisplay.uuid` 사용), `profileInfo`는 `kColorSyncDeviceDefaultProfileID` 키에 ICC 파일 URL. 프로파일 URL은 절대 경로 필요(ColorSync가 URL 자체를 보관).
- 공장 기본값 복귀: `kColorSyncDeviceDefaultProfileID` 키에 nil 값을 넣은 딕셔너리 전달 (mac-utils).
- 조회: `ColorSyncDeviceCopyDeviceInfo(deviceClass, uuid)`. 반환 딕셔너리의 `kColorSyncFactoryProfiles`, `kColorSyncCustomProfiles` 항목에서 공장 프로파일과 사용자 지정 프로파일 확인 (lumen).
- 사용 저장소: mac-utils, lumen(ColorProfiles.swift), Crisp(ColorProfileService.swift).
- macOS 26 동작: lumen이 macOS 26 대상 앱에서 사용. 그 외 검증 보고 미확인.

### 10.2 감마 테이블

- API (공개): `CGSetDisplayTransferByTable(display, tableSize, redTable, greenTable, blueTable)`, `CGGetDisplayTransferByTable`, `CGSetDisplayTransferByFormula`, `CGDisplayRestoreColorSyncSettings`.
- 동작 보고
  - 호출 프로세스 종료 시 보정된 원래 램프로 복구 (AwesomeDisplay 노트).
  - 깨어남 뒤 ICC 복원 과정에서 테이블이 덮어써지는 사례. ColorSync 분산 프로파일 변경 알림에 반응해 재적용 (Crisp 조사 노트). 알림 이름은 이번 조사에서 미확인.
  - `CGSetDisplayTransferByFormula`는 최솟값과 최댓값을 0-1 범위로 강제해 반전, 1 초과 게인을 표현 불가. 테이블 직접 구성 필요 (Crisp 조사 노트).
  - HDR 모드 모니터에서는 1.0 초과 테이블 값이 반영됨 (Crisp 조사 노트).
  - BetterDisplay v3.3.4 릴리스 노트: 색 테이블 조정 활성 시 VRR이 효과 없던 문제 수정 이력.

### 10.3 Night Shift

- 클래스: CoreBrightness의 `CBBlueLightClient` (비공개).
- 메서드 (Shifty 유래 헤더): `- (BOOL)setEnabled:(BOOL)enabled;`, `- (BOOL)setStrength:(float)strength commit:(BOOL)commit;`, `- (BOOL)getStrength:(float *)strength;`, `- (BOOL)getBlueLightStatus:(Status *)status;`, `- (BOOL)setMode:(int)mode;`, `- (BOOL)setSchedule:(CBSchedule *)schedule;`, `- (void)setStatusNotificationBlock:(void (^)(void))block;`, `+ (BOOL)supportsBlueLightReduction;`.
- `Status` 구조체 필드: `active`, `enabled`, `sunSchedulePermitted`, `mode`, `schedule`, `disableFlags`, `available`.
- 사용 저장소: Shifty, Lunar, Crisp, lumen, AwesomeDisplay.
- 로드 방식: `dlopen`으로 CoreBrightness 로드 후 `NSClassFromString` (Crisp 조사 노트).

### 10.4 True Tone

- 클래스: CoreBrightness의 `CBTrueToneClient` (비공개). 메서드: `- (BOOL)available;`, `- (BOOL)supported;`, `- (BOOL)enabled;`, `- (BOOL)setEnabled:(BOOL)arg1;`.
- 동작 보고 (Crisp 조사 노트): 클램셸 상태에서 `available`이 false. 깨어남 뒤 외장 디스플레이에 잘못된 색조가 남는 경우 끄기와 켜기 사이 약 0.3초 간격을 둔 재적용 필요.
- `CBAdaptationClient`: iOS 유래 class-dump 헤더가 Lunar 저장소에 존재하나 브리징 헤더에서 import가 주석 처리됨. macOS 26.5 SDK tbd에 클래스 등재. macOS에서의 사용 예 미확인.

### 10.5 출처

- https://developer.apple.com/documentation/colorsync/colorsyncdevicesetcustomprofiles(_:_:_:) (문서)
- https://developer.apple.com/documentation/coregraphics/cgsetdisplaytransferbytable(_:_:_:_:_:) (문서)
- https://developer.apple.com/documentation/coregraphics/cgdisplayrestorecolorsyncsettings() (문서)
- https://github.com/alin23/mac-utils/blob/main/ApplyColorProfile.swift (소스)
- https://github.com/shashvat1965/lumen/blob/main/Sources/ColorProfiles.swift (소스)
- https://github.com/shashvat1965/lumen/blob/main/Sources/System.swift (소스: CBBlueLightClient 사용)
- https://github.com/didriksg/Crisp/blob/main/Crisp/Services/ColorProfileService.swift (소스)
- https://github.com/alin23/Lunar/blob/master/Lunar/Headers/CBBlueLightClient.h (소스)
- https://github.com/alin23/Lunar/blob/master/Lunar/Headers/CBTrueToneClient.h (소스)
- https://github.com/alin23/Lunar/blob/master/Lunar/Headers/CBAdaptationClient.h (소스)
- https://github.com/thompsonate/Shifty (소스: 헤더 원출처)
- https://github.com/didriksg/Crisp/blob/main/docs/brightness-notes.md (문서: Gamma, CoreBrightness 항목)
- https://github.com/MehbubRashid/AwesomeDisplay/blob/main/DEVELOPMENT.md (문서)
- https://github.com/waydabber/BetterDisplay/releases/tag/v3.3.4 (문서)

## 11. EDID 원본 획득

### 11.1 경로별 정리

| 경로 | API 또는 키 | 선언 | 확인 |
|---|---|---|---|
| (a) IOAVService 복사 | IOAVServiceCopyEDID | `IOReturn IOAVServiceCopyEDID(IOAVServiceRef service, CFDataRef *edid)` | 소스 |
| (b) I2C 직접 읽기 | IOAVServiceReadI2C, 칩 주소 0x50, 오프셋 0x00 | 6.1과 같음. 128바이트 블록 단위 | 소스 |
| (c) 포트 전송 노드 | `IOPortTransportStateDisplayPort`의 `EDID`, 없으면 `Metadata` 하위 `EDID` | IORegistry 속성 (Data) | 소스 |
| (d) 정보 딕셔너리 | CoreDisplay_DisplayCreateInfoDictionary, SLSCopyDisplayInfoDictionary | `CFDictionaryRef ...(CGDirectDisplayID)` | 소스 |
| (e) 식별 키 | 디스플레이 노드의 `EDID UUID`, `IOMFBUUID` | IORegistry 속성 (String) | 소스 |
| (f) 가상 EDID 적용 | IOAVServiceSetVirtualEDIDMode | `IOReturn IOAVServiceSetVirtualEDIDMode(IOAVServiceRef service, int32_t mode, CFDataRef edid)` | 소스 |

### 11.2 동작 보고

- `IODisplayEDID`: fastfetch는 정보 딕셔너리에서 `kIODisplayEDIDKey`를 먼저 찾고, 없으면 `IODisplayLocation` 경로 노드의 `DisplayAttributes`로 대체. Apple Silicon에서 이 키의 존재 여부는 로컬 실측 필요.
- `DisplayAttributes.ProductAttributes` 키: `ManufacturerID`, `LegacyManufacturerID`, `ProductName`, `ProductID`, `SerialNumber`, `AlphanumericSerialNumber`, `YearOfManufacture`, `WeekOfManufacture` (MonitorControl, m1ddc, lumen, 공개 덤프 샘플).
- `EDID UUID` 구성: EDID 바이트 8-23을 UUID 형식으로 표기, 그중 시리얼 바이트 12-15는 0으로 채움. 433개 노드 전부에서 확인했다는 측정 기록 (WhatCable 주석). `IOMFBUUID`는 둘 다 있는 경우 같은 값.
- 정보 딕셔너리 키: `kDisplayVendorID`, `kDisplayProductID`, `kDisplaySerialNumber`, `kDisplayYearOfManufacture`, `kDisplayWeekOfManufacture`, `kDisplayHorizontalImageSize`, `kDisplayVerticalImageSize`, `DisplayProductName`, `IODisplayLocation`, `kCGDisplayUUID` (MonitorControl, m1ddc). 가상 디스플레이는 딕셔너리가 NULL이거나 UUID, 위치 키가 없는 경우 있음 (m1ddc).
- macOS 15 이후 OS 제공 EDID: BetterDisplay 이슈 3066에 "I2C로 직접 읽지 않은 EDID는 신뢰 불가이며 체크섬 오류. Apple이 저장된 EDID에서 시리얼을 제거"라고 기재. 원본이 필요하면 (b) 경로 사용.
- (b) 경로 한계: BetterDisplay v3.0.5 릴리스 노트에 256바이트 초과 EDID에 대한 I2C EDID 기능 비허용 기재. DDC가 막힌 연결(DisplayLink 등)에서는 불가.
- (c) 경로 조건: macOS 14 이상, Apple Silicon (WhatCable 요구 사항).
- (f) 경로: avedid.swift와 AwesomeDisplay가 사용. 패널 EEPROM을 바꾸지 않고 macOS가 인식하는 EDID만 교체. avedid.swift는 적용 시 `mode` 1과 EDID 데이터, 해제 시 `mode` 0과 nil을 전달하고 `SLSDetectDisplays` 심볼도 함께 사용. macOS 26 동작은 로컬 실측 필요.

### 11.3 출처

- https://github.com/fastfetch-cli/fastfetch/blob/dev/src/detection/brightness/brightness_apple.c (소스: IOAVServiceCopyEDID 선언, 0x50 읽기)
- https://github.com/fastfetch-cli/fastfetch/blob/dev/src/detection/displayserver/displayserver_apple.c (소스: 정보 딕셔너리와 DisplayAttributes 대체 경로)
- https://github.com/jqqqqqqqqqq/Make-M1-Great-Again/blob/main/avedid.swift (소스)
- https://github.com/darrylmorley/whatcable/blob/main/Sources/WhatCableDarwinBackend/Watchers/DisplayPortTransportWatcher.swift (소스)
- https://github.com/darrylmorley/whatcable/blob/main/Sources/WhatCableDarwinBackend/Reading/DisplayTimingReader.swift (소스: EDID UUID 구성)
- https://github.com/MonitorControl/MonitorControl/blob/main/MonitorControl/Support/Arm64DDC.swift (소스)
- https://github.com/waydabber/m1ddc/blob/main/sources/ioregistry.m (소스)
- https://github.com/waydabber/BetterDisplay/issues/3066 (문서)
- https://github.com/waydabber/BetterDisplay/releases/tag/v3.0.5 (문서)
- https://github.com/MehbubRashid/AwesomeDisplay/blob/main/DEVELOPMENT.md (문서)

## 12. 가변 주사율 조회와 설정

### 12.1 API 목록

| API | 프레임워크 | 선언 | 확인 |
|---|---|---|---|
| NSScreen minimumRefreshInterval, maximumRefreshInterval, displayUpdateGranularity | AppKit (공개, macOS 12 이상) | `var minimumRefreshInterval: TimeInterval` 외 | 문서 |
| CGDisplayMode refreshRate | CoreGraphics (공개) | `var refreshRate: Double` | 문서 |
| SLSIsDisplayModeVRR | SkyLight | `bool SLSIsDisplayModeVRR(CGDirectDisplayID display, uint32_t modeNum)` | 소스 |
| SLSIsDisplayModeProMotion | SkyLight | `bool SLSIsDisplayModeProMotion(CGDirectDisplayID display, uint32_t modeNum)` | 소스 |
| SLSGetDisplayModeMinRefreshRate | SkyLight | `CGError SLSGetDisplayModeMinRefreshRate(CGDirectDisplayID display, uint32_t modeNum, float *minRefreshRate)` | 소스 |

### 12.2 동작 보고

- 현재 상태 조회: `1 / maximumRefreshInterval`이 최소 Hz, `1 / minimumRefreshInterval`이 최대 Hz. 두 값이 다르면 가변 주사율 활성 (Crisp 프로브 스크립트).
- 모드 목록 구조: VRR 외장 디스플레이는 같은 명목 Hz에 고정 항목과 VRR 항목 2개를 가짐. Crisp가 해석한 `CGSDisplayModeDescription` 필드만으로는 둘을 구분 불가 (Crisp 프로브 스크립트 주석).
- 모드별 판별: `SLSIsDisplayModeVRR(display, modeNum)`. AllRez는 macOS 12 이상 가용으로 표기. AwesomeDisplay 노트는 `SLSGetDisplayModeMinRefreshRate`가 `float *`를 받으며 `double *` 전달 시 오류 없이 잘못된 값이 나온다고 보고.
- 설정: VRR 모드 번호를 `CGSConfigureDisplayMode`로 선택하는 방법이 위 구조에서 도출됨. 이 절차를 명시한 공개 소스는 미확인. 로컬 실측 필요.
- ioreg 키 (공개 덤프 샘플과 Asahi Linux 파서): `TimingElements[].MinimumVariableRefreshRate`, `MaximumVariableRefreshRate`, 그리고 `SupportsVariableRefreshRate`, `MinimumRefreshRate`, `MaximumRefreshRate`, `ContinuousFrequencySupport`, `QMSVRREnableConfig`. 뒤 5개 키의 소속 딕셔너리와 의미는 로컬 실측 필요.
- ProMotion 내장 디스플레이: 고정 주사율 선택은 모드 목록의 주사율 변형 선택으로 수행 (MPDisplay `scanRates`, `modeMatchingResolutionOfMode:withScanRate:` 헤더 근거). macOS 26 동작 미확인.
- 간섭: 감마 테이블 조정과 VRR의 간섭 이력 (10.2의 BetterDisplay v3.3.4 항목).

### 12.3 출처

- https://developer.apple.com/documentation/appkit/nsscreen/minimumrefreshinterval (문서)
- https://developer.apple.com/documentation/appkit/nsscreen/maximumrefreshinterval (문서)
- https://developer.apple.com/documentation/appkit/nsscreen/displayupdategranularity (문서)
- https://developer.apple.com/documentation/coregraphics/cgdisplaymode/refreshrate (문서)
- https://github.com/joevt/AllRez/blob/main/AllRez/AppleMisc.h (소스)
- https://github.com/joevt/AllRez/blob/main/AllRez/main.cpp (소스)
- https://github.com/didriksg/Crisp/blob/main/scripts/vrr-probe.swift (소스)
- https://github.com/MehbubRashid/AwesomeDisplay/blob/main/Sources/AwesomeDisplayCore/PrivateAPI/SkyLight.swift (소스)
- https://github.com/MehbubRashid/AwesomeDisplay/blob/main/DEVELOPMENT.md (문서)
- https://github.com/AsahiLinux/linux/blob/asahi/drivers/gpu/drm/apple/parser.c (소스)
- https://github.com/glpi-project/glpi-agent/blob/develop/resources/macos/ioreg/AppleCLCD2 (소스)

## 13. USB-C, Thunderbolt 포트와 케이블 정보

### 13.1 IOKit 클래스와 프로퍼티 (WhatCable이 읽는 항목)

| 클래스 | 용도 | 프로퍼티 |
|---|---|---|
| `AppleHPMInterfaceType10`, `Type11`, `Type12` (M3 세대), `AppleHPMInterfaceType18` (MacBook Neo), `AppleTCControllerType10`, `Type11` (M1, M2) | 포트별 상태 | `PortDescription`, `PortNumber`, `PortType`, `PortTypeDescription`, `ConnectionActive`, `ConnectionCount`, `ConnectionUUID`, `PlugOrientation`, `ActiveCable`, `OpticalCable`, `DisplayPortPinAssignment`, `Pin Configuration`, `TransportsSupported`, `TransportsProvisioned`, `TransportsActive`, `FeaturesEnabled`, `IOAccessoryUSBConnectString`, `IOAccessoryUSBSuperSpeedActive`, `Plug Event Count`, `Overcurrent Count`, `FW Version`, `UUID` |
| `IOPortFeaturePowerSource` | 연결된 전원의 PDO 목록과 현재 선택 PDO | README 기재. 키 이름은 이번 조사에서 미열람 |
| `IOPortTransportComponentCCUSBPDSOP`, `...SOPp`, `...SOPpp` | 포트 파트너, 케이블 근단 e-marker, 원단 e-marker의 PD Discover Identity VDO | README 기재. 키 이름은 이번 조사에서 미열람 |
| `IOPortTransportStateDisplayPort` | DP 링크와 모니터 정보 | 5.3 참조 |
| `IOPortTransportStateCIO`, `IOPortTransportStateUSB3`, `IOPortTransportStateUSB2` | Thunderbolt/USB4, USB3, USB2 전송 상태 | `Active`, `CableGeneration`, `CableSpeed`, `Generation`, `AsymmetricModeSupported`, `LegacyAdapter`, `LinkTrainingMode`, `Tunneled`, `TunneledTransportsProvisioned`, `SuperSpeedSignaling`, `SuperSpeedSignalingDescription`, `DataRole`, `TRM_State`, `TRM_TransportRestricted` 등 |
| `AppleTypeCPhy` | PHY 상태 | `AppleTypeCPhyID`, `AppleTypeCPhyLane`, `AppleTypeCPhyUSB2`, `AppleTypeCPhyDisplayPortPclk`, `AppleTypeCPhyDisplayPortTunnel`, `Link Rate`, `Power Level`, `Transport`, `Client` |
| `IOThunderboltSwitch` | Thunderbolt 패브릭 | `Port`, `UID` |
| `IOPortTransportProtocolAppleUVDM` | Apple 액세서리 식별 | `Manufacturer`, `Model`, `Product`, `Product ID`, `Vendor ID`, `Serial Number`, `Hardware Version` |
| 포트 진단 노드 | PD 컨트롤러 카운터 | `PortControllerAttachCount`, `PortControllerDetachCount`, `PortControllerHardResetCount`, `PortControllerMaxPower`, `PortControllerNPDOs`, `PortControllerPortPDO`, `PortControllerActiveContractRdo`, `PortControllerI2cErrCount` 등 |
| XHCI 컨트롤러 하위 트리 | USB 장치와 물리 포트 연결 | `UsbIOPort` 레지스트리 경로 |

### 13.2 동작 보고

- 요구 사항: macOS 14 이상, Apple Silicon 전용 (WhatCable README). Intel Mac은 포트 컨트롤러 서비스가 비어 있음.
- 접근 수단: 엔타이틀먼트, 비공개 API, 헬퍼 데몬 없이 IOKit 레지스트리 읽기. App Sandbox 안에서도 같은 값. SMC 접근만 샌드박스에서 차단 (WhatCable README).
- 클래스 이름은 칩 세대별로 다름. 열거 대상 클래스 목록을 고정하지 않는 설계 필요.
- 케이블 e-marker: e-marker가 있는 케이블만 정보 제공. 일부 케이블은 반대쪽에 장치가 연결된 뒤에만 응답 (WhatCable README).
- 데스크톱 전면 USB-C 포트(Mac mini, Mac Studio): 내부 허브 뒤의 일반 USB 포트. 케이블, 전원, PD 데이터 없음 (WhatCable README).
- 변경 감지: `IOServiceAddMatchingNotification`과 `IOServiceMatching(클래스 이름)` 조합 (WhatCable 워처).
- 디스플레이와 포트 연결: `IOPortTransportStateDisplayPort` 노드에서 부모 체인을 따라 `AppleHPMDeviceHALType3`의 UUID 획득 후 HPM 포트와 대조 (WhatCable 주석).

### 13.3 출처

- https://github.com/darrylmorley/whatcable/blob/main/README.md (문서)
- https://github.com/darrylmorley/whatcable/blob/main/Sources/WhatCableCore/Port/AppleHPMInterface.swift (소스)
- https://github.com/darrylmorley/whatcable/blob/main/Sources/WhatCableDarwinBackend/Watchers/HPMPortControllerClasses.swift (소스)
- https://github.com/darrylmorley/whatcable/blob/main/Sources/WhatCableDarwinBackend/Watchers/AppleTypeCPhyWatcher.swift (소스)
- https://github.com/darrylmorley/whatcable/blob/main/Sources/WhatCableDarwinBackend/Watchers/TRMTransportWatcher.swift (소스)
- https://github.com/darrylmorley/whatcable/blob/main/Sources/WhatCableDarwinBackend/Watchers/USB3TransportWatcher.swift (소스)
- https://github.com/darrylmorley/whatcable/blob/main/Sources/WhatCableDarwinBackend/Watchers/IOThunderboltSwitchWatcher.swift (소스)
- https://github.com/darrylmorley/whatcable/blob/main/Sources/WhatCableDarwinBackend/Watchers/AppleUVDMWatcher.swift (소스)
- https://github.com/darrylmorley/whatcable/blob/main/Sources/WhatCableDarwinBackend/Watchers/PortDiagnosticsWatcher.swift (소스)
- https://github.com/darrylmorley/whatcable/blob/main/Sources/WhatCableDarwinBackend/Watchers/DisplayPortTransportWatcher.swift (소스)

## 14. 디스플레이 구성 변경 알림

### 14.1 API 목록

| API | 프레임워크 | 선언 | 확인 |
|---|---|---|---|
| CGDisplayRegisterReconfigurationCallback | CoreGraphics (공개) | `CGError CGDisplayRegisterReconfigurationCallback(CGDisplayReconfigurationCallBack callback, void *userInfo)` | 문서 |
| NSApplication.didChangeScreenParametersNotification | AppKit (공개) | `class let didChangeScreenParametersNotification: NSNotification.Name` | 문서 |
| IOServiceAddMatchingNotification | IOKit (공개) | 포트 전송 노드의 생성과 종료 감지 | 소스 |
| DisplayServicesRegisterForBrightnessChangeNotifications | DisplayServices (비공개) | 7.1 참조 | 소스 |
| CBBlueLightClient setStatusNotificationBlock: | CoreBrightness (비공개) | 10.3 참조 | 소스 |
| kMPDisplaysReconfigureNotification, kMPDisplaysWillReconfigureNotification, kMPDisplaysHardwareChangeNotification | MonitorPanel (비공개) | tbd 등재만 확인. 사용 예 미확인 | 미확인 |

### 14.2 동작 보고 (Crisp 조사 노트)

- CoreGraphics 디스플레이 목록은 프로세스별 캐시. 재구성 콜백 전달로만 갱신. 다른 프로세스에서 보이는 상태보다 37-158 ms 늦게 반영된 측정 기록.
- `didChangeScreenParameters` 알림은 전환 도중 1회 발생할 수 있어 그 시점의 기하 정보와 EDR 헤드룸 값은 신뢰 불가. 알림 뒤 1초 디바운스 후 재적용.
- 디스플레이 잠자기 동안 재구성 콜백 미전달.
- 재구성 시 CGDirectDisplayID가 제거 이벤트 없이 재배정되는 경우 있음. 디스플레이별 저장 상태는 UUID 기준 필요.
- `kCGDisplayIsVirtualDevice` 플래그는 재열거 중인 실제 모니터에서도 1로 읽히는 사례.

### 14.3 출처

- https://developer.apple.com/documentation/coregraphics/cgdisplayregisterreconfigurationcallback(_:_:) (문서)
- https://developer.apple.com/documentation/appkit/nsapplication/didchangescreenparametersnotification (문서)
- https://github.com/didriksg/Crisp/blob/main/docs/display-notes.md (문서: restoreIfNoActiveDisplay, phantomAwareActiveDisplayCount 항목)
- https://github.com/didriksg/Crisp/blob/main/docs/brightness-notes.md (문서)
- https://github.com/didriksg/Crisp/blob/main/docs/ddc-notes.md (문서)
- https://github.com/darrylmorley/whatcable/blob/main/Sources/WhatCableDarwinBackend/Watchers/DisplayPortTransportWatcher.swift (소스)
- https://github.com/alexey-lysiuk/macos-sdk/blob/main/MacOSX26.5.sdk/System/Library/PrivateFrameworks/MonitorPanel.framework/Versions/A/MonitorPanel.tbd (소스)

## 15. 로컬 실측 필요 항목 모음

- (1) CGS 모드 번호와 `CGDisplayMode.ioDisplayModeID`의 관계 (1.2).
- (2) `CGSDisplayModeDescription` 212바이트 레이아웃의 macOS 26 유효성과 플래그 비트 의미 (1.2).
- (3) `ColorModes[].PixelEncoding` 1-3, `EOTF` 1-3의 실제 의미 (4.3).
- (4) `IOMobileFramebufferSetDigitalOutMode` 적용 뒤 유지 범위와 초기화 조건 (4.2).
- (5) `LinkDescription`의 `Range` 값 의미와 macOS 26 반영 여부 (4.4).
- (6) 현재 색 모드 ID와 `DSCRequiredColorElementIDs` 대조에 의한 DSC 판정의 정확성 (5.1).
- (7) `IOAVServiceGetLinkData`, `IOAVServiceGetFRLLinkData` 계열의 시그니처 (5.1, 5.4).
- (8) 빈 내장 HDMI 포트의 `IOPortTransportStateDisplayPort` 노드 존재 여부 (5.4).
- (9) `SLSSetDisplayRotation` 인자 형태 (8.2).
- (10) `SLSDisplaySetHDRModeEnabled` 인자 개수 (3.2).
- (11) `CoreDisplay_Display_SetUserBrightness`의 macOS 26 동작 (7.2).
- (12) Apple Silicon의 정보 딕셔너리 내 `IODisplayEDID` 존재 여부와 `IOAVServiceCopyEDID` 반환 데이터의 시리얼 보존 여부 (11.2).
- (13) VRR 모드 선택 절차와 `SLSIsDisplayModeVRR` 결과 (12.2).
- (14) 대상 기기의 디스플레이 노드 클래스(`AppleCLCD2` 또는 `IOMobileFramebufferShim`)와 포트 컨트롤러 클래스 이름 (4.1, 13.1).

## 16. 기능별 구현 경로 총괄표

| 기능 | 1순위 API | 대안 | 위험도 | 로컬 실측 필요 여부 |
|---|---|---|---|---|
| 모드 열거 | `CGDisplayCopyAllDisplayModes` + `kCGDisplayShowDuplicateLowResolutionModes` | `CGSGetNumberOfDisplayModes`, `CGSGetDisplayModeDescriptionOfLength` (숨은 HiDPI 모드 포함) | 낮음 (공개), 중간 (CGS 구조체 의존) | 필요: 구조체 레이아웃과 모드 번호 의미 |
| 모드 전환 | `CGConfigureDisplayWithDisplayMode` | `CGSConfigureDisplayMode` (설정 토큰 인자), `MPDisplay setModeNumber:` | 낮음 (공개), 중간 (CGS) | 필요: 숨은 모드 적용 경로 |
| HiDPI 강제 | 오버라이드 plist `scale-resolutions` + 디스플레이 재활성화 | `CGVirtualDisplay` + `CGConfigureDisplayMirrorOfDisplay` | 중간 | 필요: 대상 패널의 스케일 백킹 한도 |
| HDR 상태 조회 | `SLSDisplaySupportsHDRMode`, `SLSDisplayIsHDRModeEnabled` | `MPDisplay hasHDRModes`, `preferHDRModes`, `CGSIsHDRSupported` | 낮음 | 불필요 |
| HDR 켜기, 끄기 | `SLSDisplaySetHDRModeEnabled` | `MPDisplay setPreferHDRModes:` | 중간 | 필요: 인자 개수 |
| XDR 밝기 업스케일 | EDR 오버레이 (`CAMetalLayer` + 곱셈 블렌드) | `CGSetDisplayTransferByTable` 1.0 초과 테이블 | 중간. 프리셋 방식은 macOS 26.3에서 차단 보고로 높음 | 필요: 대상 패널의 헤드룸 동작 |
| 색 모드 조회 | 디스플레이 노드의 `TimingElements`, `ColorElements` + `IOMobileFramebufferGetDigitalOutMode` | `IOAVVideoInterfaceCopyColorElements` (시그니처 미확인) | 중간 | 필요: 열거값 의미 |
| 색 모드 설정 | `IOMobileFramebufferSetDigitalOutMode` | `LinkDescription` plist 수정 + 재부팅 | 높음 | 필요: 유지 범위, 검은 화면 복구 절차 |
| DSC 상태 조회 | `DSCRequiredColorElementIDs`, `SupportsDSC` + 현재 색 모드 ID 대조 | `IOAVServiceGetLinkData` 계열 (시그니처 미확인) | 중간 | 필요 |
| DSC 비활성화 | 미확인 | 색 모드 전환 또는 가상 EDID (모두 미확인) | 높음 | 필요 |
| DP 링크 속도, 레인 수 | `IOPortTransportStateDisplayPort`의 `LinkRate`, `LaneCount`, `MaxLaneCount` | `AppleTypeCPhy`의 `Link Rate` | 낮음 | 필요: 값 단위 확인 |
| HDMI FRL, TMDS 정보 | 미확인 (`IOAVServiceGetFRLLinkData` 심볼 등재만 확인) | `DownstreamFormat`, `UnsafeColorElementIDs` 간접 정보 | 높음 | 필요 |
| DDC/CI | `IOAVServiceCreateWithService` + `IOAVServiceWriteI2C`, `IOAVServiceReadI2C` | 감마 테이블 소프트웨어 디밍 | 중간. 동시 실행 시 시스템 정지 보고 | 필요: 내장 HDMI 칩 주소 0xB7 경로 |
| 내장, Apple 디스플레이 밝기 | `DisplayServicesGetBrightness`, `DisplayServicesSetBrightness` | `CoreDisplay_Display_SetUserBrightness` | 낮음 | 필요: CoreDisplay 대안의 macOS 26 동작만 |
| 회전 | `SLSSetDisplayRotation` | `MPDisplay setOrientation:` | 중간 | 필요: 인자 형태 |
| 연결 해제, 재연결 | `SLSConfigureDisplayEnabled` + `SLSGetDisplayList` | `CGSConfigureDisplayEnabled` | 높음 | 필요: 대상 기종의 복구 동작 |
| 미러, 배치, 메인 지정 | `CGBeginDisplayConfiguration`, `CGConfigureDisplayOrigin`, `CGConfigureDisplayMirrorOfDisplay`, `CGCompleteDisplayConfiguration` | `MPDisplayMgr` 미러 메서드 | 낮음 | 불필요 |
| ColorSync 프로파일 지정 | `ColorSyncDeviceSetCustomProfiles` | 없음 | 낮음 | 불필요 |
| 감마 테이블 | `CGSetDisplayTransferByTable` | `IOMobileFramebufferSetGammaTable` (시그니처 미확인) | 낮음 | 불필요 |
| Night Shift | `CBBlueLightClient` | 없음 | 중간 | 불필요 |
| True Tone | `CBTrueToneClient` | `CBAdaptationClient` (macOS 사용 예 미확인) | 중간 | 불필요 |
| EDID 원본 획득 | `IOAVServiceReadI2C` 칩 0x50 직접 읽기 | `IOAVServiceCopyEDID`, `IOPortTransportStateDisplayPort`의 `EDID` | 중간 | 필요: 경로별 시리얼 보존 여부 |
| 가변 주사율 조회 | `NSScreen.minimumRefreshInterval`, `maximumRefreshInterval` | `SLSIsDisplayModeVRR`, `SLSGetDisplayModeMinRefreshRate`, ioreg `MinimumVariableRefreshRate` | 낮음 | 불필요 |
| 가변 주사율 설정 | VRR 모드 번호를 `CGSConfigureDisplayMode`로 선택 (공개 근거 미확인) | 없음 | 중간 | 필요 |
| USB-C, Thunderbolt 포트와 케이블 정보 | IOKit 레지스트리 읽기 (`AppleHPMInterfaceType*`, `IOPortTransportState*`, `IOPortTransportComponentCCUSBPDSOP*`) | `AppleTypeCPhy`, `IOThunderboltSwitch` | 중간. 칩 세대별 클래스 이름 차이 | 필요: 대상 기기의 클래스 이름 |
| 구성 변경 알림 | `CGDisplayRegisterReconfigurationCallback` | `NSApplication.didChangeScreenParametersNotification`, `IOServiceAddMatchingNotification` | 낮음 | 불필요 |
