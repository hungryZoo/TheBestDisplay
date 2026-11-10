# SRS: TheBestDisplay 설계 요구 문서

- 상위 문서: `docs/PRD.md`
- 근거 자료: `docs/research/spikes.md`, `docs/research/platform-apis.md`

## 1. 아키텍처

### 1.1 3단계 구조

```
TBDApp (SwiftUI 창 앱)          tbdctl (명령행 도구)
        \                          /
         TBDPlatform (시스템 연동: 비공개 API, IOKit, CoreGraphics)
                      |
         TBDCore (순수 로직: 모델, 파서, 계산, 진단 규칙, 직렬화)
```

- TBDCore: 시스템 호출 없음. 입력은 값 타입과 바이트열. 단위 테스트 대상
- TBDPlatform: 시스템 상태를 읽어 TBDCore 모델로 변환하고, 변경 요청을 시스템 호출로 수행
- TBDApp, tbdctl: 표시와 입력 처리. 로직 보유 금지

### 1.2 패키지 구성

| 타깃 | 종류 | 경로 | 의존 |
| --- | --- | --- | --- |
| TBDCore | 라이브러리 | `Sources/TBDCore` | 없음 |
| TBDPlatform | 라이브러리 | `Sources/TBDPlatform` | TBDCore |
| TheBestDisplay | 실행 파일 (앱) | `Sources/TBDApp` | TBDCore, TBDPlatform |
| tbdctl | 실행 파일 (CLI) | `Sources/tbdctl` | TBDCore, TBDPlatform |
| TBDCoreTests | 테스트 | `Tests/TBDCoreTests` | TBDCore |
| TBDPlatformTests | 테스트 | `Tests/TBDPlatformTests` | TBDPlatform |

- 빌드: `swift build`, 테스트: `swift test`, 앱 번들: `scripts/build_app.sh`
- 외부 패키지 의존성 없음

### 1.3 데이터 흐름

- 조회: 시스템 상태 → TBDPlatform 서비스 → `SystemSnapshot`(Codable 값 타입) → 화면 또는 JSON 출력
- 진단: `SystemSnapshot` → `DiagnosticEngine`(순수 함수) → `Finding` 목록
- 변경: 화면 입력 → `RevertGuard` → TBDPlatform 서비스의 적용 함수 → 재조회

## 2. 인터페이스 초안

```swift
// TBDCore
public struct DisplayIdentity: Codable, Hashable {
    public var displayID: UInt32
    public var uuid: String?
    public var vendorID: UInt32
    public var productID: UInt32
    public var serialNumber: UInt32
    public var name: String
    public var isBuiltin: Bool
}

public struct DisplayMode: Codable, Hashable, Identifiable {
    public var id: Int32            // SLS 모드 번호
    public var width: Int           // 논리 해상도
    public var height: Int
    public var scale: Double        // 2.0 = HiDPI
    public var refreshRate: Double
    public var isVRR: Bool
    public var isProMotion: Bool
    public var isInSystemDefaultList: Bool
}

public struct ColorElement: Codable, Hashable, Identifiable {
    public var id: Int
    public var pixelEncoding: PixelEncoding   // rgb444, ycbcr420, ycbcr422, ycbcr444, ...
    public var bitsPerComponent: Int
    public var eotf: EOTF                     // sdr, hdrGamma, pq, hlg
    public var dynamicRange: DynamicRange     // full, limited
    public var colorimetry: Int
    public var usesDSC: Bool
    public var isVirtual: Bool
}

public struct TimingElement: Codable, Hashable, Identifiable {
    public var id: Int
    public var hActive: Int, hTotal: Int, vActive: Int, vTotal: Int
    public var refreshRate: Double
    public var pixelClockHz: Double           // hTotal x vTotal x refreshRate
    public var colorElementIDs: [Int]
    public var dscRequiredColorElementIDs: [Int]
}

public struct LinkState: Codable, Hashable {
    public var transport: Transport           // displayPort, hdmi
    public var linkRateGbpsPerLane: Double?
    public var laneCount: Int?
    public var maxLaneCount: Int?
    public var isTunneled: Bool
    public var hpdAsserted: Bool?
    public var dscEnabled: Bool?
    public var fecEnabled: Bool?
}

public struct Finding: Codable, Hashable {
    public enum Severity: String, Codable { case info, warning, error }
    public var code: String                   // 예: "LINK.BANDWIDTH_EXCEEDED"
    public var severity: Severity
    public var title: String
    public var detail: String                 // 근거 수치 포함
    public var remedy: String?
}

public enum DiagnosticEngine {
    public static func evaluate(_ snapshot: DiagnosticSnapshot) -> DiagnosticResult
}

public enum BandwidthCalculator {
    public static func requiredGbps(pixelClockHz: Double, encoding: PixelEncoding, bpc: Int) -> Double
    public static func availableGbps(link: LinkState) -> Double?
}

// TBDPlatform
public protocol DisplayApplying {
    func captureState(of display: UInt32) throws -> DisplayStateToken
    func restore(_ token: DisplayStateToken) throws
}
```

## 3. 플랫폼 설계

### 3.1 비공개 심볼 접근

- 정적 링크 금지. `dlopen`과 `dlsym`으로 실행 시 조회하고 함수 포인터를 `@convention(c)` 타입으로 변환
- 조회 실패 심볼은 nil로 유지하고 해당 기능의 `Capability`를 미가용으로 판정
- 구조체 크기와 오프셋은 `docs/research/spikes.md`의 실측값 사용. 크기 가정은 테스트로 고정

### 3.2 디스플레이와 IORegistry 노드 대응

- 대응 키: EDID 바이트 8-23을 UUID 형식으로 표기하고 일련번호 바이트 12-15를 0으로 채운 값. 프레임버퍼 노드의 `EDID UUID`와 같은 형식 (`docs/research/competitors.md` 2.5.2절의 WhatCable 소스 근거, 실험 기기 값 `1E6DC8C0-0000-0000-011F-0104C5A05A78`로 확인)
- 프레임버퍼 노드 클래스: `IOMobileFramebufferShim`(M2 Pro 이후 상위 칩, M4, M5 계열)과 `AppleCLCD2`(M1 계열, M2, M3) 양쪽 조회
- `CGDirectDisplayID` → 프레임버퍼 노드: CoreGraphics의 제조사, 모델, 일련번호로 만든 대응 키와 `EDID UUID` 대조. 내장 디스플레이는 `external` 부재로 판별. 동일 제품 복수 연결 시 `DisplayAttributes.ProductAttributes.SerialNumber`와 해상도로 보조 판별
- 프레임버퍼 노드 → `IOPortTransportStateDisplayPort`: 전송 상태 노드의 `EDID` 바이트로 만든 대응 키 대조
- 전송 상태 → 포트: `ParentPortType`, `ParentPortNumber`, `TransportDescription` 경로 문자열
- 프레임버퍼 노드 → `DCPAVServiceProxy`: `Location`(External, Embedded)과 `IOAVServiceCopyEDID` 결과의 대응 키 대조
- 포트 컨트롤러 클래스: `AppleHPMInterfaceType10`, `AppleHPMInterfaceType11`, `AppleHPMInterfaceType12`, `AppleHPMInterfaceType18`, `AppleTCControllerType10`, `AppleTCControllerType11`, `AppleHDMIPortController`

### 3.3 대역폭 계산

- 필요 대역폭 = 픽셀 클록 x 픽셀당 비트 수. 픽셀당 비트 수: RGB와 YCbCr 4:4:4는 bpc x 3, YCbCr 4:2:2는 bpc x 2, YCbCr 4:2:0은 bpc x 1.5
- DP 가용 대역폭 = 레인당 속도 x 레인 수 x 부호화 효율. 8b/10b(RBR, HBR, HBR2, HBR3)는 0.8, 128b/132b(UHBR)는 0.9697
- HDMI 가용 대역폭: TMDS는 문자 속도 x 3 x 0.8, FRL은 레인당 속도 x 레인 수 x 16/18
- DSC 사용 모드는 압축 후 목표 bpp로 계산

### 3.4 안전장치

- `RevertGuard`는 상태 기계와 타이머만 보유. 실제 적용과 복귀는 `DisplayApplying` 구현 주입
- 복귀 정보 파일 경로: Application Support의 앱 폴더 아래 `pending-revert.json`

## 4. 설계 요구사항

| ID | 설계 요구사항 | 관련 PRD | 구현 위치 |
| --- | --- | --- | --- |
| SRS-ARC-001 | SwiftPM 단일 패키지에 TBDCore, TBDPlatform, TheBestDisplay, tbdctl 타깃 구성. 외부 의존성 없음 | PRD-APP-001 | `Package.swift` |
| SRS-ARC-002 | `PrivateSymbols`: 프레임워크별 `dlopen`, 심볼별 `dlsym` 조회와 캐시. 누락 심볼은 nil. `Capability` 집합으로 기능 가용성 노출 | PRD-APP-005 | `Sources/TBDPlatform/PrivateSymbols.swift` |
| SRS-ARC-003 | 앱 번들 조립 스크립트: 릴리스 빌드, `Info.plist` 생성(`LSUIElement` 미설정), ad-hoc 서명 | PRD-APP-001 | `scripts/build_app.sh` |
| SRS-ARC-004 | `DisplayStore`: 메인 액터의 관찰 가능 객체. `CGDisplayRegisterReconfigurationCallback`과 IOKit 서비스 알림 수신 후 300 ms 디바운스로 `SystemSnapshot` 재조회 | PRD-APP-004 | `Sources/TBDApp/DisplayStore.swift` |
| SRS-UI-001 | `NavigationSplitView` 기반 사이드바와 상세 영역. 상세 영역은 기능별 탭 (마지막으로 연 탭을 저장해 다음 실행에서 유지). 선택한 디스플레이가 사라지면 첫 디스플레이를 선택하고, 사라진 디스플레이가 돌아오면(재초기화, 재연결) 다시 선택. 해상도 탭의 도구 구역은 모드 목록과 같은 스크롤 영역에 배치 | PRD-APP-002, PRD-APP-003 | `Sources/TBDApp/Views/` |
| SRS-UI-002 | 앱 델리게이트에서 마지막 창 닫기 시 종료. `NSStatusItem` 미사용 | PRD-APP-001 | `Sources/TBDApp/TheBestDisplayApp.swift` |
| SRS-INF-001 | `DisplayCatalog`: `CGGetOnlineDisplayList`, CoreGraphics 속성, `CoreDisplay_DisplayCreateInfoDictionary`, 프레임버퍼 노드 대응으로 `DisplayIdentity`와 물리 정보 구성 | PRD-INF-001, PRD-PRF-003 | `Sources/TBDPlatform/DisplayCatalog.swift` |
| SRS-INF-002 | `EDIDParser`: 기본 블록, CTA-861 확장(데이터 블록 전체 순회, HDMI VSDB, HF-VSDB, HDR 정적 메타데이터, 색 공간), DisplayID 확장 해석. 블록별 체크섬 검증. 손상 입력에서 충돌 없이 부분 결과 반환 | PRD-INF-002, PRD-INF-004 | `Sources/TBDCore/EDID/` |
| SRS-INF-003 | EDID 원본 획득 순서: `IOAVServiceCopyEDID`, `IOPortTransportStateDisplayPort`의 `EDID` 키. 둘 다 실패 시 EDID 없음으로 표시. 디스플레이 대응은 EDID 머리의 제조사, 제품 코드, 일련번호와 CoreGraphics 값 대조. 일련번호 불일치 시 같은 제품이 1대일 때만 제조사와 제품 코드로 대응. 내장 패널은 EDID 없음 | PRD-INF-003 | `Sources/TBDPlatform/EDIDSource.swift` |
| SRS-INF-004 | I2C EDID 읽기: `IOAVServiceReadI2C(서비스, 0x50, 블록 번호 x 128, 버퍼, 128)`로 기본 블록과 선언된 확장 블록을 차례로 읽음. 머리 8바이트가 맞지 않으면 실패, 확장 블록은 체크섬이 맞는 블록까지만 포함 | PRD-INF-005 | `Sources/TBDPlatform/DDCService.swift` |
| SRS-INF-005 | DisplayID 타일 배치 블록(1.x 태그 0x12, 2.x 태그 0x28) 해석: 배치 3바이트에서 타일 수와 위치(각 6비트), 크기 4바이트에서 타일 폭과 높이, 능력 바이트의 단일 외함 비트, 묶음 식별자 | PRD-INF-006 | `Sources/TBDCore/EDID/EDIDParser.swift` |
| SRS-MOD-001 | `ModeService` 열거: `SLSGetDisplayModeDescriptionOfLength`의 212바이트 구조체 해석(`DisplayMode.decode`). 심볼 미가용 시 `CGDisplayCopyAllDisplayModes` 대체. 모드별 시스템 설정 표시 여부, 원본, 기본 판정은 `MPDisplay`의 `allModes`에서 조회 | PRD-MOD-001, PRD-MOD-004 | `Sources/TBDPlatform/ModeService.swift` |
| SRS-MOD-002 | 모드 전환 경로 순서: `MPDisplay setModeNumber:`, 공개 API `CGConfigureDisplayWithDisplayMode`. `SLSConfigureDisplayMode` 직접 호출은 명시 지정 시에만 사용 (ADR-0005). 복귀와 확정은 모드 번호가 아닌 모드 서술(해상도, HiDPI, 주사율, 가변 여부)로 대상 모드 재탐색 | PRD-MOD-003, PRD-MOD-005 | `Sources/TBDPlatform/ModeService.swift`<br>`Sources/TBDPlatform/MPDisplayBridge.swift`<br>`Sources/TBDPlatform/DisplayChanges.swift` |
| SRS-MOD-003 | `ModeCatalog`: 해상도별 묶음, HiDPI 판정(배율 2 이상), 필터(배율, 주사율, 종횡비, 시스템 설정 목록 밖). 시스템 설정 목록 포함 여부는 `MPDisplay` 판정 사용, 조회 불가 시 공개 API 기본 열거 결과와 대조. 명령행 모드 지정 해석은 `ModeSpec` | PRD-MOD-002, PRD-MOD-006 | `Sources/TBDCore/ModeCatalog.swift` |
| SRS-MOD-004 | `DisplayOverrideFile`: `/Library/Displays/Contents/Resources/Overrides/DisplayVendorID-<16진수>/DisplayProductID-<16진수>` plist의 `scale-resolutions` 항목 해석과 생성. 추가 항목은 논리 해상도의 2배 크기를 4바이트 빅엔디언 2개로 기록. 플래그가 붙은 기존 항목과 다른 키는 보존. `DisplayOverrideService`: 직접 쓰기 실패 시 임시 파일에 준비하고 설치 명령(mkdir, cp, chmod) 반환. 항목이 모두 없어지면 파일을 지우고 비게 된 제조사 폴더도 함께 정리 (권한이 없으면 rm과 빈 폴더 정리 명령 반환). 창 앱은 시스템의 관리자 인증 창으로 실행, 명령행은 명령 출력 | PRD-MOD-007 | `Sources/TBDCore/DisplayOverride.swift`<br>`Sources/TBDPlatform/DisplayOverrideService.swift` |
| SRS-MOD-005 | `RefreshRateMeter`: `NSScreen.displayLink`의 콜백 시각과 보고 주기를 수집. `RefreshMeasurement.compute`: 측정값은 간격 수를 측정 시간으로 나눈 값, 보고값은 보고 주기의 중앙값. 표본 2개 미만이면 측정 불가 | PRD-MOD-008 | `Sources/TBDCore/RefreshMeasurement.swift`<br>`Sources/TBDPlatform/RefreshRateMeter.swift` |
| SRS-MOD-006 | `ModeCatalog.renderingLimits`: 전체 모드의 최대 백킹 폭과 높이, 백킹 면적이 가장 큰 HiDPI 모드. `ModeCatalog.sliderSteps`: 현재 모드와 배율이 같고 종횡비 차이가 2% 이내인 해상도를 폭 순으로 나열하고 단계마다 현재 주사율과 가장 가까운 모드 선택. `ModeFavoritesStore`: Application Support의 `mode-favorites.json`에 제조사, 제품 코드, 일련번호별 모드 서술자 목록 저장 | PRD-MOD-009, PRD-MOD-010 | `Sources/TBDCore/ModeExtras.swift` |
| SRS-MOD-007 | `ModeCatalog.notchPair`: 현재 모드와 폭, 배율, 주사율, 가변 주사율 여부가 같은 모드 중 한쪽이 16:10이고 높이 차이가 폭의 5% 이내인 쌍 판정. 전환은 SRS-MOD-002의 모드 전환과 자동 복귀 사용 | PRD-MOD-011 | `Sources/TBDCore/ModeExtras.swift` |
| SRS-MOD-008 | `DisplayOverrideFile.ladder`: 패널 폭의 절반과 패널 폭 사이를 단계 수로 등분하고 폭은 짝수, 높이는 종횡비로 계산. `addLadder`는 중복과 범위 밖 항목을 건너뛰고 추가 개수 반환. 저장은 SRS-MOD-004의 경로 사용 | PRD-MOD-013 | `Sources/TBDCore/DisplayOverride.swift` |
| SRS-MOD-009 | `FramebufferLimits`: 프레임버퍼 노드의 `IOMFBMaxSrcPixels`(`MaxSrcRectWidthForPipe`, `MaxSrcRectHeightForPipe`, `MaxSrcBufferWidth`, `MaxSrcBufferHeight`, `MaxVideoSrcDownscalingWidth`)와 `IOMFBScalingLimits`(`RGBLayer_MaxScale`, `RGBLayer_MinScaleFraction`) 해석. 판정은 첫 파이프의 값 사용. `ModeService.framebufferLimits`는 디스플레이에 대응하는 노드에서 조회하고 노드가 없으면 값 없음 | PRD-MOD-014 | `Sources/TBDCore/FramebufferLimits.swift`<br>`Sources/TBDPlatform/ModeService.swift` |
| SRS-COL-001 | `SignalDecoder`: 프레임버퍼 노드의 `TimingElements`, `ColorElements` 사전을 `TimingElement`, `ColorElement`로 변환. 열거형 값은 spikes 문서 2.2절 표 사용. 알 수 없는 값은 원시 값을 보존하여 표시. 선택 목록은 현재 타이밍의 `ColorModes`에서 가상 형식을 제외한 항목 | PRD-COL-002, PRD-COL-005 | `Sources/TBDCore/Signal.swift` |
| SRS-COL-002 | 현재 신호 조회: `IOMobileFramebufferGetDigitalOutMode`의 색 ID와 타이밍 ID, `IOAVServiceGetLinkData`의 0x110바이트 구조체 해석(`VideoLinkData.decode`, spikes 문서 2.1절 오프셋). 프레임버퍼 노드 대응은 SRS 3.2절 규칙. 내장 패널은 링크 데이터 없음 | PRD-COL-001 | `Sources/TBDPlatform/SignalService.swift`<br>`Sources/TBDCore/Signal.swift` |
| SRS-COL-003 | 색 모드 전환: `IOMobileFramebufferSetDigitalOutMode(색 ID, 타이밍 ID)`. 타이밍 ID는 현재 값 유지. 반환 코드 0 이외는 오류로 보고. 복귀와 프로파일 복원은 색 ID가 아닌 `ColorDescriptor`(인코딩, 비트 심도, 레인지, EOTF, 색 공간)로 대상 재탐색 | PRD-COL-003 | `Sources/TBDPlatform/SignalService.swift`<br>`Sources/TBDPlatform/DisplayChanges.swift` |
| SRS-COL-004 | DSC 판정: 색 요소의 `SupportsDSC`, 타이밍 요소의 `DSCRequiredColorElementIDs`, `AppleDPTXController`의 `SupportsDSC`와 `DSCEnabled`, EDID의 DSC 능력을 결합. 현재 DSC 사용 여부의 1차 근거는 현재 색 ID의 `DSCRequiredColorElementIDs` 포함 여부 | PRD-COL-004, PRD-LNK-003 | `Sources/TBDCore/DSCAssessment.swift` |
| SRS-COL-006 | `DSCControl.plan`: 현재 타이밍의 선택 가능 색 모드 중 DSC 필수 목록 포함 여부가 요청 상태와 같은 것을 후보로 삼고 가상 형식과 안전하지 않은 형식 제외. 현재와 같은 전달 함수만 대상. 선택 순서는 같은 서술, 시스템 점수, 같은 픽셀 인코딩, 비트 심도 차이, 같은 레인지. 적용은 SRS-COL-003의 색 모드 전환과 자동 복귀 사용 | PRD-COL-006 | `Sources/TBDCore/DSCControl.swift` |
| SRS-COL-007 | 타이밍 직접 선택: `TimingSelection.resolve`는 타이밍 ID 또는 해상도와 주사율(0.05 Hz 이내)로 가상 형식이 아닌 타이밍을 찾음. `TimingSelection.plan`은 대상 타이밍의 색 모드 중 현재와 같은 서술, 같은 전달 함수, 시스템 점수 순으로 선택. 적용은 `IOMobileFramebufferSetDigitalOutMode(색 ID, 타이밍 ID)`. 복귀 동작 `timing`은 타이밍 서술(해상도, 주사율)과 색 모드 서술로 지정 | PRD-COL-007 | `Sources/TBDCore/TimingSelection.swift`<br>`Sources/TBDPlatform/SignalService.swift` |
| SRS-COL-008 | `DitherService`: 디스플레이에 대응하는 프레임버퍼 노드의 `enableDither` 속성을 읽고 `IORegistryEntrySetCFProperty`로 변경한 뒤 다시 읽어 확인. 속성이 없으면 미지원 | PRD-COL-008 | `Sources/TBDPlatform/DitherService.swift` |
| SRS-COL-009 | `DepthComparison.note`: 현재 모드의 채널당 비트(프레임버퍼)와 링크 데이터의 채널당 비트(연결)를 비교해 낮음, 높음, 같음의 안내 문구 생성. 해상도 탭의 용어 설명은 고정 문구의 팝오버 | PRD-COL-009, PRD-MOD-012 | `Sources/TBDCore/Signal.swift`<br>`Sources/TBDApp/Views/ResolutionTab.swift` |
| SRS-HDR-001 | `HDRService`: 조회는 `SLSDisplaySupportsHDRMode`, `SLSDisplayIsHDRModeEnabled`. 전환 경로 순서는 `MPDisplay setPreferHDRModes:`, `SLSDisplaySetHDRModeEnabled(디스플레이, 켜기 여부)`. EDR 헤드룸은 `NSScreen`의 EDR 속성, 지원 EOTF와 최대 휘도는 EDID. 색 모드의 전달 함수와 HDR 상태 불일치 판정은 `HDRStatus.isMismatched` | PRD-HDR-001, PRD-HDR-002, PRD-HDR-003 | `Sources/TBDPlatform/HDRService.swift` |
| SRS-LNK-001 | `LinkService`: `IOPortTransportStateDisplayPort` 노드를 `DPTransportState`로 해석하고 제품 코드, 일련번호, EDID 머리로 디스플레이에 대응. 레인당 속도는 `NominalSignalingFrequenciesHz` 우선. 내장 패널은 전송 상태 노드가 없어 링크 훈련 데이터로 구성. DSC 상태는 SRS-COL-004 판정, FEC는 전원이 켜진 송신기가 1개일 때만 표시 | PRD-LNK-001, PRD-LNK-003 | `Sources/TBDPlatform/LinkService.swift`<br>`Sources/TBDCore/Link.swift` |
| SRS-LNK-002 | `BandwidthCalculator`: 3.3절 계산식 구현. `LinkAnalyzer`: 링크 보고(원시, 유효, 필요 대역폭, 사용률)와 색 형식별 수용 판정(선택 가능, 대역폭 초과, 미제공) 구성 | PRD-LNK-002, PRD-DGN-002 | `Sources/TBDCore/Link.swift` |
| SRS-LNK-003 | HDMI 링크 조회: 프레임버퍼 `Transport`의 하류 종류와 전송 상태의 하류 포트 종류로 HDMI 판별. TMDS 문자 속도는 픽셀 클록과 색 형식으로 계산. `IOAVServiceGetFRLLinkData`는 구조 미확인으로 원시 8바이트 표시 | PRD-LNK-004 | `Sources/TBDPlatform/LinkService.swift`<br>`Sources/TBDCore/Link.swift` |
| SRS-LNK-004 | DPCD 읽기: `IODPDeviceReadDPCD`로 000h-00Fh, 060h-06Fh, 100h-107h, 160h, 200h-207h, 2200h-220Fh. 구간별 실패 허용, 수신기 능력을 읽지 못하면 nil. `DPCDDecoder`로 해석. `IODPDeviceGetLinkTrainingData`의 레인 수와 속도 부호는 `LinkTrainingData`로 해석 | PRD-LNK-005 | `Sources/TBDPlatform/LinkService.swift`<br>`Sources/TBDCore/DPCDDecoder.swift` |
| SRS-LNK-005 | HDCP 능력 해석: DPCD 0x68028(Bcaps 1바이트, 비트 0 HDCP_CAPABLE, 비트 1 REPEATER)과 0x6921D(RxCaps 3바이트, 첫 바이트 판 번호, 마지막 바이트 비트 1 HDCP_CAPABLE, 비트 0 REPEATER)를 `IODPDeviceReadDPCD`로 읽어 `DPCDInfo`에 반영. 읽기 실패는 읽기 불가로 표시 | PRD-LNK-006 | `Sources/TBDCore/DPCDDecoder.swift`<br>`Sources/TBDPlatform/LinkService.swift` |
| SRS-PRT-001 | `PortService`: 3.2절의 포트 컨트롤러 클래스와 `IOPortTransportState` 계열 노드 속성을 읽어 `PortInventory.decode`로 `PortInfo`, `CIOState`, `USBState`, `CableEMarker` 구성. 케이블 e-marker는 `IOPortTransportComponentCCUSBPDSOPp` 노드의 케이블 VDO 해석(속도, 전류, 전압, EPR). 부속 노드의 포트 연결은 부모 포트 종류와 번호 | PRD-PRT-001, PRD-PRT-002 | `Sources/TBDPlatform/PortService.swift`<br>`Sources/TBDCore/Ports.swift` |
| SRS-PRT-002 | `ConnectionPathBuilder`: 포트마다 포트, 케이블, 독 또는 허브, 영상 링크, 디스플레이 단계 구성. 단계 상태는 정상, 정보 없음, 끊김. HPD는 감지되나 링크가 없는 경우와 링크는 있으나 온라인 목록에 없는 경우를 끊김으로 표시 | PRD-PRT-003 | `Sources/TBDCore/Ports.swift` |
| SRS-PRT-003 | `PortInfo.plugOrientation`: 포트 노드의 `PlugOrientation` 원시 값 (연결 없음 0, 연결 시 1 또는 2). `PhyInfo`: 속성 `AppleTypeCPhyID`가 있는 노드에서 `AppleTypeCPhyLane`, `AppleTypeCPhyUSB2`, `AppleTypeCPhyDisplayPortTunnel`, `AppleTypeCPhyDisplayPortPclk` 해석. 클래스 이름이 칩마다 달라 속성 존재 매칭(`IOPropertyExistsMatch`)으로 수집. USB-C 포트 번호는 PHY 번호 + 1로 대응. 연결 경로에 PHY 단계 추가. `PowerAdapterInfo`: `AppleSmartBattery`의 `ExternalConnected`와 `AdapterDetails`(`Watts`, `AdapterVoltage`, `Current`, `Name`, `UsbHvcMenu`) 해석 | PRD-PRT-004, PRD-PRT-005 | `Sources/TBDCore/Ports.swift`<br>`Sources/TBDPlatform/PortService.swift` |
| SRS-PRT-004 | `ThunderboltSwitch`: `IOThunderboltSwitch` 계열 노드의 `Depth`, `Route String`(깊이마다 8비트 포트 번호), 제조사와 모델 이름, `Thunderbolt Version` 원시 값 해석. `PhyInfo.laneConfiguration`: PHY 레인의 전송 방식 조합으로 구성 판정 (레인 1개는 DP 레인 2개에 해당) | PRD-PRT-006 | `Sources/TBDCore/Ports.swift` |
| SRS-PRT-005 | `ChargingTelemetry`: `AppleSmartBattery` 노드의 `IsCharging`, `FullyCharged`, `CurrentCapacity`, `AvgTimeToFull`, `PowerTelemetryData`(`SystemPowerIn`, `SystemLoad`, mW), `ChargerData`(사유 부호, 온도 제한 누적 시간) 해석. 읽을 때마다 변하는 값이라 `PortInventory`와 분리. `ChargingAssessment.assess`: 케이블 최대 전압 이하의 전원 옵션에서 전류를 케이블 정격으로 제한한 최댓값이 충전기 최대보다 작으면 케이블 제한으로 판정. 전원 케이블은 연결된 포트의 e-marker가 1개일 때만 특정. `PortService.chargingFindings`가 조회와 판정을 묶음 | PRD-PRT-007 | `Sources/TBDCore/ChargingAssessment.swift`<br>`Sources/TBDPlatform/PortService.swift` |
| SRS-PRT-006 | `CableEMarker`: 인증 VDO의 인증 ID, 제품 VDO의 제품 ID와 장치 판, 케이블 VDO의 하드웨어 판(비트 31-28), 펌웨어 판(27-24), 지연 시간 부호(16-13) 해석. `CableTrust.identity`는 식별 정보 한 줄, `signals`는 기록 누락과 값 사이 불일치 목록. 제조사 이름은 내장 목록(20개)에서 조회. 연결 경로의 케이블 단계 설명에 식별 정보와 신뢰 신호 포함 | PRD-PRT-008 | `Sources/TBDCore/CableTrust.swift`<br>`Sources/TBDCore/Ports.swift` |
| SRS-DGN-001 | `DiagnosticEngine`: `DiagnosticSnapshot`을 받아 `DiagnosticResult`(발견 항목, 포트별 점검)를 반환하는 순수 함수. 포트 점검은 물리 연결, HPD, EDID, 링크, 프레임버퍼, 온라인 6단계이며 첫 실패 뒤는 생략 처리. 규칙별 부호, 심각도(정보, 주의, 문제), 근거 수치, 조치 문구 보유. 칩별 외장 디스플레이 한도는 추정값으로 표기. 스냅샷 수집은 `SnapshotBuilder` | PRD-DGN-001, PRD-DGN-002, PRD-DGN-003, PRD-DGN-006 | `Sources/TBDCore/Diagnostics/`<br>`Sources/TBDPlatform/SnapshotBuilder.swift` |
| SRS-DGN-002 | `EventLog`: 직전 `EventState`와 현재 상태의 차이로 이벤트 생성(디스플레이 연결과 해제, 모드, 색 모드, HDR, 링크, HPD, 포트 연결), 최근 1,000건 보관. 변화 감지는 CoreGraphics 재구성 콜백과 포트 상태 2초 주기 대조 | PRD-DGN-004 | `Sources/TBDCore/Diagnostics/EventLog.swift`<br>`Sources/TBDApp/DisplayStore.swift` |
| SRS-DGN-003 | `ReportExporter`: 스냅샷, 진단 결과, 이벤트를 JSON과 텍스트로 직렬화. 가림 옵션은 일련번호, UUID, EDID 일련번호 바이트 제거. 현재 타이밍 외의 색 모드 목록은 축약 | PRD-DGN-005 | `Sources/TBDCore/Diagnostics/ReportExporter.swift`<br>`Sources/TBDCore/Diagnostics/DiagnosticSnapshot.swift` |
| SRS-BRT-001 | `BrightnessService`: 제어 방식 선택 순서는 시스템 밝기 제어(DisplayServices, 내장 패널과 Apple 디스플레이 한정), DDC(탐지에서 밝기 코드 응답 시), 소프트웨어 디밍. 자동 밝기는 DisplayServices의 주변광 보정 함수 | PRD-BRT-001, PRD-BRT-003, PRD-BRT-004 | `Sources/TBDPlatform/BrightnessService.swift` |
| SRS-BRT-002 | `XDRBoostService`: 대상 화면 구석의 8포인트 창(`CAMetalLayer`, `rgba16Float`, `wantsExtendedDynamicRangeContent`)에 1.0을 넘는 값을 그려 EDR 헤드룸을 유지하고, `GammaService`가 기준 테이블 합성 뒤 전달 테이블에 배율을 곱함. 지원 판정은 `NSScreen`의 잠재 EDR 헤드룸 1 초과. 구성 변경 시 창 재배치, 종료 시 해제 | PRD-BRT-005 | `Sources/TBDPlatform/XDRBoostService.swift`<br>`Sources/TBDCore/GammaTable.swift` |
| SRS-BRT-003 | 밝기 동기화: `BrightnessSync.targetLevel`은 원본 밝기를 대상 방식의 범위로 변환(소프트웨어 디밍 하한 10%), `shouldApply`는 마지막 적용값과 1% 이상 차이일 때만 적용. `BrightnessSyncService`는 대상별 제어 방식을 한 번 판정해 두고 `syncOnce`마다 원본 밝기를 읽어 적용, 종료 시 소프트웨어 디밍 대상을 복원. 창 앱은 1초, 명령행은 0.5초 주기 | PRD-BRT-006 | `Sources/TBDCore/BrightnessSync.swift`<br>`Sources/TBDPlatform/BrightnessSyncService.swift` |
| SRS-BRT-004 | `OverlayDimService`: 대상 화면 크기의 테두리 없는 검은 창(화면 보호기 수준, 마우스 입력 통과, 모든 스페이스에 표시)의 불투명도로 디밍. 강도 상한 0.9. 구성 변경 시 창 크기 재조정, 종료 시 해제 | PRD-BRT-007 | `Sources/TBDPlatform/OverlayDimService.swift`<br>`Sources/TBDCore/OverlayDim.swift` |
| SRS-BRT-005 | `BacklightLuminance`: 프레임버퍼 노드(`IOMobileFramebufferShim`)의 `IOMFBBrightnessLevel`(현재), `BLNitsCap`(백라이트 상한), `IOMFBIndicatorNitsCap`(패널 최대)을 16.16 고정소수점 cd/m²로 해석. `BrightnessService.backlightLuminance`는 내장 디스플레이에 한해 조회 (외장의 같은 속성은 고정값). 밝기 탭은 1초 간격으로 다시 읽음. 밝기 탭 조회는 순번을 두어 늦게 끝난 DDC 탐지 결과가 다른 디스플레이의 상태를 덮어쓰지 않게 함 | PRD-BRT-008 | `Sources/TBDCore/BacklightLuminance.swift`<br>`Sources/TBDPlatform/BrightnessService.swift`<br>`Sources/TBDApp/Views/BrightnessTab.swift` |
| SRS-BRT-006 | `CombinedBrightness.levels`: 결합 값 0.25 이상은 하드웨어 밝기(하한에서 1까지 선형), 미만은 하드웨어 하한과 디밍(0.1에서 1까지 선형). 시스템 밝기 제어의 하드웨어 하한은 1/16 (0에서는 백라이트가 꺼짐), DDC는 0. `combined`는 역산. `BrightnessService.applyCombined`는 하드웨어 밝기 지정 뒤 `GammaService`의 다른 조정값을 유지한 채 디밍만 바꿈. 명령은 지정 시간 뒤 하드웨어 밝기와 전달 테이블 복원 | PRD-BRT-009 | `Sources/TBDCore/CombinedBrightness.swift`<br>`Sources/TBDPlatform/BrightnessService.swift`<br>`Sources/tbdctl/CombinedBrightnessCommand.swift` |
| SRS-BRT-007 | `LuminanceReferenceStore`: 디스플레이 식별 키별 최대 휘도 저장 (범위 10-10000 cd/m², 사용자 지정값이 EDID 값보다 우선). `LuminanceReference.estimatedNits`는 밝기 비율과 기준값의 곱. `BrightnessSync.normalizedLevel`은 원본 휘도를 대상 최대 휘도로 나눈 뒤 방식별 범위로 변환. `BrightnessSyncService`의 원본 휘도는 내장 패널이면 백라이트 보고 값, 그 밖은 추정값. 창 앱의 동기화는 메인 스레드 밖에서 실행하고 중지 시 진행 중인 1회가 끝난 뒤 디밍 복원 | PRD-BRT-010 | `Sources/TBDCore/LuminanceReference.swift`<br>`Sources/TBDCore/BrightnessSync.swift`<br>`Sources/TBDPlatform/BrightnessSyncService.swift`<br>`Sources/TBDApp/BrightnessSyncController.swift` |
| SRS-DDC-001 | `DDCService`: `IOAVServiceWriteI2C`와 `IOAVServiceReadI2C`(주소 0x37, 오프셋 0x51), 패킷 체크섬 계산, 재시도 3회, 직렬 큐. 탐지는 밝기, 대비, 볼륨, 입력 소스 읽기이며 앞의 두 코드에 응답이 없으면 미지원 판정. 첫 요청 1회가 1.5초를 넘겨 실패하면 재시도 없이 미응답 판정 (capabilities 조회도 같은 기준). 창 앱은 탐지와 쓰기를 메인 스레드 밖에서 수행하고 연속 쓰기는 150 ms 간격으로 묶음. `DDCPacket`, `VCPCode`, `DDCProbe`는 TBDCore에 배치 | PRD-DDC-001, PRD-DDC-002, PRD-DDC-003, PRD-BRT-002 | `Sources/TBDPlatform/DDCService.swift`<br>`Sources/TBDCore/DDCPacket.swift` |
| SRS-DDC-002 | `DDCCapabilities`: 요청 `83 F3 오프셋(2) 체크섬`, 응답 조각 `6E (0x80\|길이) E3 오프셋(2) 자료 체크섬` 해석, 빈 조각까지 이어 붙인 문자열의 괄호 구조 해석(`model`, `type`, `mccs_ver`, `cmds`, `vcp`와 코드별 선택값). `DDCService.capabilities`는 오프셋을 올리며 최대 4096바이트 수집 | PRD-DDC-004 | `Sources/TBDCore/DDCCapabilities.swift`<br>`Sources/TBDPlatform/DDCService.swift` |
| SRS-DDC-003 | `DDCControlPlan.controls`: 표준 코드 표의 순서로 지원 코드만 `DDCControl`(코드, 이름, 선택 항목, 화면 출력 중단 가능 여부)로 구성. 밝기(0x10)는 밝기 조절이 담당하므로 제외. 표준 이름이 없는 선택값은 숫자로 표기. `otherCodes`는 표에 없는 코드. 밝기 탭은 탐지 뒤 capabilities를 읽어 구성하고 탐지에서 읽지 않은 연속 값의 현재값을 읽음. 실행 인자 `-ddcCapabilitiesPreview <문자열>`은 응답 없는 외장 디스플레이에서 화면 구성만 표시 (쓰기 없음) | PRD-DDC-005 | `Sources/TBDCore/DDCControlPlan.swift`<br>`Sources/TBDApp/Views/BrightnessTab.swift`<br>`Sources/tbdctl/BrightnessCommands.swift` |
| SRS-CLR-001 | `GammaService`: 디밍, 색온도, 게인, 대비, 감마를 하나의 전달 테이블로 합성(`GammaTable.make`)하고 조정 전 테이블(디스플레이 보정값) 위에 겹쳐 `CGSetDisplayTransferByTable` 적용. 전체 초기화는 `CGDisplayRestoreColorSyncSettings`. 재구성 뒤 현재 테이블이 마지막 적용값과 다를 때만 재적용. 앱 종료 시 복원 | PRD-CLR-002, PRD-BRT-003 | `Sources/TBDPlatform/GammaService.swift`<br>`Sources/TBDCore/GammaTable.swift` |
| SRS-CLR-002 | `ColorProfileService`: 현재 프로파일은 `ColorSyncProfileCreateWithDisplayID`, 목록은 공장 프로파일과 `ColorSyncIterateInstalledProfiles`의 RGB 디스플레이 클래스 프로파일, 지정은 `ColorSyncDeviceSetCustomProfiles`(기본값 복귀는 `kCFNull`). 정렬과 중복 제거는 `ColorProfileCatalog` | PRD-CLR-001 | `Sources/TBDPlatform/ColorProfileService.swift` |
| SRS-CLR-003 | `NightShiftService`(`CBBlueLightClient`의 상태, 켜기와 끄기, 강도), `TrueToneService`(`CBTrueToneClient`의 지원, 사용 가능, 켜기와 끄기): Objective-C 런타임 동적 호출. 상태 구조체 해석은 `NightShiftStatus.decodeStatus` | PRD-CLR-003, PRD-CLR-004 | `Sources/TBDPlatform/NightShiftService.swift` |
| SRS-CLR-004 | `PresetService`: `MPDisplay`의 `hasPresets`, `presets`, `activePreset`, `defaultPreset`으로 목록 구성, `setActivePreset:`으로 전환. 사용할 수 없는 빈 자리(`isValid` 거짓)는 표시에서 제외. 복귀 동작 `preset`은 프리셋 번호로 지정 | PRD-CLR-005 | `Sources/TBDPlatform/PresetService.swift`<br>`Sources/TBDCore/DisplayPreset.swift` |
| SRS-CLR-005 | `NightShiftEmulation.kelvin`: Night Shift가 켜져 있으면 강도 0-1을 5200 K에서 2800 K로 선형 대응, 꺼져 있으면 6500 K. `adjusted`는 현재 조정 값과 1 K 이상 다를 때만 새 값 반환. 실행기는 3초 주기(명령행 0.5초)로 상태를 읽어 `GammaService`에 적용 | PRD-CLR-006 | `Sources/TBDCore/NightShiftEmulation.swift`<br>`Sources/TBDApp/NightShiftSyncController.swift` |
| SRS-CLR-006 | 상태별 색 프로파일: `HDRProfileStore`는 `hdr-profiles.json`에 디스플레이별 SDR과 HDR 프로파일 경로 저장. `HDRProfilePreference.target`은 현재 HDR 상태의 지정 경로가 현재 프로파일과 다를 때만 반환. `HDRProfileService.applyIfNeeded`가 `ColorProfileService.set`으로 전환, 창 앱은 3초 주기로 수행 | PRD-CLR-007 | `Sources/TBDCore/HDRProfile.swift`<br>`Sources/TBDPlatform/HDRProfileService.swift` |
| SRS-CLR-007 | `ICCProfile`: 머리, 태그 표, 태그 자료(공유 자료 포함) 해석과 직렬화, XYZ 태그와 이름 태그(`desc`, `dscm`) 쓰기. `SaturationAdjustment.adjustedColorants`: 색 좌표 행렬 `M`을 `M · S⁻¹`로 변경 (각 원색을 `1/s`배 하고 흰색 방향 성분을 더함). `SaturationService`: 현재 프로파일 자료로 프로파일 파일 생성, `ColorSyncProfileVerify` 검사 통과 뒤 사용자 지정 프로파일로 지정, `SaturationStore`에 조정 전 프로파일 기록, 해제 시 복귀와 파일 삭제. 다른 경로로 프로파일이 바뀐 경우 해제는 기록만 정리 | PRD-CLR-008 | `Sources/TBDCore/ICCProfile.swift`<br>`Sources/TBDCore/SaturationProfile.swift`<br>`Sources/TBDPlatform/SaturationService.swift` |
| SRS-ARR-001 | `ArrangementService`: CoreGraphics 구성 트랜잭션으로 원점, 미러 처리. 계산은 `ArrangementPlanner`: 메인 지정은 대상을 원점 (0, 0)으로 옮기는 전체 평행 이동, 위치 이동은 다른 디스플레이와 맞닿는 가장 가까운 위치로 보정 후 메인 원점 정규화. 미러 대상은 배치 계산에서 제외 | PRD-ARR-002, PRD-ARR-003, PRD-ARR-004 | `Sources/TBDPlatform/ArrangementService.swift` |
| SRS-ARR-002 | 회전: `MPDisplay`의 `setOrientation:`. 적용은 비동기라 `CGDisplayRotation`이 목표값이 될 때까지 최대 10초 대기. 내장 디스플레이는 대상에서 제외. `SLSSetDisplayRotation`은 시그니처 불일치 보고가 있어 사용하지 않음 | PRD-ARR-001 | `Sources/TBDPlatform/ArrangementService.swift` |
| SRS-ARR-003 | 연결 해제와 재연결: 구성 트랜잭션 안의 `SLSConfigureDisplayEnabled`. 해제 대상을 제외한 온라인 디스플레이가 0개이면 시스템 호출 전에 거부. 재연결은 온라인 목록에 나타날 때까지 대기 후 판정. 창 앱은 이 앱에서 해제한 디스플레이 목록을 유지하고 자동 복귀의 복귀 동작은 재연결 | PRD-ARR-005, PRD-SAF-003 | `Sources/TBDPlatform/ArrangementService.swift` |
| SRS-ARR-004 | 언더스캔: `MPDisplay`의 `supportsUnderscan`, `underscan`, `minUnderscan`, `maxUnderscan`, `setUnderscan:` (시스템 설정과 같은 경로) | PRD-ARR-006 | `Sources/TBDPlatform/ArrangementService.swift` |
| SRS-ARR-005 | `ArrangementPlanner.alignedOrigin`: 기준 사각형의 변과 대상 크기로 16개 위치의 원점 계산. 적용은 `ArrangementService.move`의 맞닿음 보정 경유 (모서리 위치는 1포인트 보정) | PRD-ARR-007 | `Sources/TBDCore/Alignment.swift` |
| SRS-ARR-006 | 내장 자동 해제: `AutoDisconnectPolicy.decide`는 설정, 온라인 목록(내장, 가상 여부), 해제해 둔 내장 ID로 해제, 재연결, 유지 판단. 가상 디스플레이는 외장으로 치지 않음. `AutoDisconnectController`는 2초 주기로 판단을 수행하고 해제 전에 상태 파일(`auto-disconnect.json`)에 내장 ID를 기록, 종료 시와 다음 실행 시작 시 재연결 | PRD-ARR-008 | `Sources/TBDCore/AutoDisconnect.swift`<br>`Sources/TBDApp/AutoDisconnectController.swift` |
| SRS-ARR-007 | `ArrangementService.reinitialize`: `SLSConfigureDisplayEnabled`로 해제한 뒤 온라인 목록에서 빠질 때까지 대기(최대 5초), 2초 뒤 재연결하고 제한 시간(20초) 안에 온라인이 되는지 확인 | PRD-ARR-009 | `Sources/TBDPlatform/ArrangementService.swift` |
| SRS-VRT-001 | `VirtualDisplayService`: `CGVirtualDisplay` 생성(전용 콜백 큐), 모드 적용, HiDPI 모드 선택, 온라인 대기, 삭제. 프로세스 수명 동안 객체 유지. 구성(`VirtualDisplayConfig`)은 유효성 검사 후 생성하고 `VirtualDisplayStore`가 JSON으로 저장. 실행 시 복원 대상은 앱 시작 때 생성. 창 앱의 생성은 메인 스레드 밖에서 수행 | PRD-VRT-001, PRD-VRT-003 | `Sources/TBDPlatform/VirtualDisplayService.swift`<br>`Sources/TBDCore/VirtualDisplay.swift` |
| SRS-VRT-002 | HiDPI 스케일링: HiDPI 가상 디스플레이 생성 후 실제 디스플레이를 가상 디스플레이의 미러로 구성. 해제 시 미러 해제와 가상 디스플레이 삭제. 후보 해상도와 선명도 설명은 `HiDPIScaling`(원본 종횡비 유지, 백킹 폭 상한 7680픽셀). 적용과 해제는 자동 복귀 안전장치 경유 | PRD-VRT-002 | `Sources/TBDPlatform/VirtualDisplayService.swift` |
| SRS-VRT-003 | 가상 디스플레이 HDR: `CGVirtualDisplayMode`의 `initWithWidth:height:refreshRate:transferFunction:`에 전달 함수 값 1 지정 (0과 2는 SDR로 인식, 실험 04). 구성의 `hdr` 값은 저장 파일에 없으면 거짓 | PRD-VRT-004 | `Sources/TBDPlatform/VirtualDisplayService.swift`<br>`Sources/TBDCore/VirtualDisplay.swift` |
| SRS-VRT-004 | 가상 디스플레이 크기 상한: `VirtualDisplayConfig.validationIssues`가 백킹 폭 7680과 백킹 높이 4320 초과를 거부하고, `VirtualDisplayService.create`가 같은 조건을 다시 확인한 뒤에만 `CGVirtualDisplay`를 생성. 근거는 T50 실측 (10240x5760은 1920x1080 모드로 대체, 16384x8640은 WindowServer 중단) | PRD-VRT-005 | `Sources/TBDCore/VirtualDisplay.swift`<br>`Sources/TBDPlatform/VirtualDisplayService.swift` |
| SRS-PRF-001 | `ProfileStore`: Application Support의 JSON 파일. 판 번호 필드 보유(상위 판 항목은 읽지 않음). 이름 중복과 빈 이름 거부, 이름 변경, 삭제. 디스플레이 대응(`ProfilePlanner.match`)은 UUID, 제조사와 제품 코드와 일련번호 순이며 한 디스플레이는 한 항목에만 대응 | PRD-PRF-001, PRD-PRF-003 | `Sources/TBDCore/Profile.swift` |
| SRS-PRF-002 | 프로파일 적용: `ProfilePlanner.plan`이 저장 구성과 현재 구성의 차이만 단계로 산출. 순서는 미러, 회전, 모드, HDR, 색 모드, 배치, 밝기(회전이 모드 목록을 바꾸고, 모드와 HDR 전환이 색 모드를 다시 선택하게 하므로). 단계 실패 시 나머지 단계 계속 수행, 단계별 결과(적용, 변경 없음, 건너뜀, 실패) 수집. 적용 전체는 자동 복귀 안전장치 경유이며 복귀는 적용 전 구성 재적용 | PRD-PRF-002 | `Sources/TBDPlatform/ProfileApplier.swift`<br>`Sources/TBDCore/Profile.swift` |
| SRS-PRF-003 | 구성 보호: `ProtectionStore`는 Application Support의 `protection.json`에 프로파일 ID와 보호 대상 단계 저장. `ProtectionSetting.deviations`는 `ProfilePlanner.plan`의 단계 중 보호 대상만 산출. `ProtectionGuard`는 60초 창 안의 복원 횟수가 3회에 이르면 일시 중지. `ProtectionController`는 디스플레이 구성 변경 뒤 1.5초를 기다려 차이를 확인하고 `ProfileApplier.apply(only:)`로 복원, 설정 파일을 매번 다시 읽어 명령행 설정 반영, 복원이 일으킨 재구성 알림은 건너뜀 | PRD-PRF-004 | `Sources/TBDCore/Protection.swift`<br>`Sources/TBDApp/ProtectionController.swift` |
| SRS-SAF-001 | `RevertStateMachine`: PRD 3절 상태 전이의 순수 구현. `RevertCoordinator`: 효과 실행기. 타이머와 적용, 확정, 복귀 동작 주입으로 단위 테스트 가능. 창 앱은 `ChangeController`, 명령행은 `performGuardedChange`가 구동 | PRD-SAF-001 | `Sources/TBDCore/RevertGuard.swift` |
| SRS-SAF-002 | `PendingRevertStore`: 복귀 정보 파일 기록, 조회, 삭제. 손상 파일은 없음으로 처리. 앱 실행 시 파일이 있으면 복귀 제안, 명령행은 `revert-pending`. 복귀 동작 수행은 `PendingRevertApplier` | PRD-SAF-002 | `Sources/TBDCore/RevertGuard.swift`<br>`Sources/TBDPlatform/PendingRevertApplier.swift` |
| SRS-CLI-001 | `tbdctl`: 하위 명령 분기, `--json` 출력, PRD 5절 종료 코드. 인자 해석은 TBDCore의 `CommandLineParser` | PRD-CLI-001, PRD-CLI-002, PRD-CLI-003 | `Sources/tbdctl/`<br>`Sources/TBDCore/CommandLineParser.swift` |
| SRS-EDO-001 | `EDIDEditor`: 검증은 길이, 머리, 확장 블록 수, 블록별 체크섬 확인. 편집은 CTA 확장 블록을 머리, 데이터 블록, 18바이트 서술자로 분해한 뒤 다시 조립하여 상세 타이밍 시작 오프셋과 체크섬을 재계산. HDMI Forum 블록(VSDB와 SCDB)은 판 번호 기준 같은 오프셋으로 처리. 대상 선언이 없으면 변경 없음으로 보고 | PRD-EDO-001, PRD-EDO-002 | `Sources/TBDCore/EDID/EDIDEditor.swift` |
| SRS-EDO-002 | `EDIDOverrideService`: `IOAVServiceSetVirtualEDIDMode(서비스, 모드, EDID)` 호출 (모드 1 적용, 0 해제). 대상 서비스는 EDID가 읽히는 외장 `DCPAVServiceProxy` 중 제조사, 제품 코드, 일련번호가 일치하는 것. 적용과 해제 뒤 `SLSDetectDisplays`로 재감지. 복귀 동작 `edidReset`은 서비스의 레지스트리 항목 ID로 지정하고 서비스가 없으면 외장 서비스 전체 해제 | PRD-EDO-003, PRD-EDO-004 | `Sources/TBDPlatform/EDIDOverrideService.swift`<br>`Sources/TBDPlatform/DisplayChanges.swift` |
| SRS-EDO-003 | `DetailedTimingSpec`: CVT 축소 블랭킹 계산(최소 수직 블랭킹 460 µs, 1판은 수평 블랭킹 160과 클록 단계 0.25 MHz, 2판은 수평 블랭킹 80과 클록 단계 0.001 MHz), 18바이트 서술자와 DisplayID 20바이트 타이밍 부호화. 주입 자리 우선순위는 기본 블록의 더미 서술자, CTA 확장 블록의 여유 공간, DisplayID 확장 블록(없으면 새 확장 블록). 선호 지정은 기본 블록의 첫 서술자 교체와 기존 타이밍 이동. DisplayID 구역 체크섬과 블록 체크섬 재계산 | PRD-EDO-005 | `Sources/TBDCore/EDID/CustomTiming.swift`<br>`Sources/TBDCore/EDID/EDIDEditor.swift` |
| SRS-UPD-001 | 업데이트 확인 계산 (Foundation 전용): `SemanticVersion`(세 정수, 접두사 v만 허용), `UpdateCacheStore`(`~/Library/Caches/TheBestDisplay/update-check.json`, 손상 시 기본값), `UpdatePolicy`(24시간 주기, 시계 역행 시 재확인, 현재와 건너뛴 버전보다 새 버전만 표시), `LatestReleaseParser`(초안, 사전 릴리스, 버전 형식이 아닌 태그 제외), `UpdateChecker`(REST API `releases/latest`, 제한 시간 5초), `ReleaseNotesFormatter`. 버전은 `AppVersion.current` 한 곳에서 관리하고 빌드 스크립트가 이 값을 Info.plist에 기록 | PRD-UPD-001, PRD-UPD-004 | `Sources/TBDCore/Update/`<br>`scripts/build_app.sh`<br>`Sources/tbdctl/UpdateCommand.swift` |
| SRS-UPD-002 | `UpdateController`: 요청 전에 시도 시각 기록, 조회 성공 시에만 캐시 갱신, 실행당 창 1회 표시. `InstallMethod.classify`는 앱 경로(`/Applications` 또는 `~/Applications`)와 Caskroom 기록, brew 실행 파일 존재로 Homebrew 설치본 판정 (`/opt/homebrew` 우선). `UpdateScript.homebrew`는 앱 PID 종료 대기, `brew update`, 전체 이름 `brew upgrade`, 격리 속성 제거, 앱 재실행, 자기 삭제. 설정 창(`Settings`)과 도움말 메뉴 연결 | PRD-UPD-002, PRD-UPD-003 | `Sources/TBDApp/UpdateController.swift`<br>`Sources/TBDApp/Views/UpdateView.swift`<br>`Sources/TBDCore/Update/InstallMethod.swift` |
| SRS-UPD-003 | `scripts/build_dmg.sh`: 릴리스 빌드 번들과 응용 프로그램 폴더 링크를 담은 압축 DMG(`dist/TheBestDisplay-<버전>.dmg`), `.sha256`, cask 파일(`dist/thebestdisplay.rb`: arm64, macOS 15 이상, `binary`로 `tbdctl` 연결, `zap` 경로) 생성. 버전은 번들의 Info.plist에서 읽음. `scripts/make_icon.swift`가 아이콘 PNG를 그려 `Resources/AppIcon.icns` 생성, 빌드 스크립트가 번들에 복사. 릴리스 노트는 `.github/release-notes/v<버전>.md` | PRD-UPD-005 | `scripts/build_dmg.sh`<br>`scripts/make_icon.swift`<br>`scripts/build_app.sh`<br>`.github/release-notes/` |
