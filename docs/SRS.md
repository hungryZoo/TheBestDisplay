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
| SRS-UI-001 | `NavigationSplitView` 기반 사이드바와 상세 영역. 상세 영역은 기능별 탭 | PRD-APP-002, PRD-APP-003 | `Sources/TBDApp/Views/` |
| SRS-UI-002 | 앱 델리게이트에서 마지막 창 닫기 시 종료. `NSStatusItem` 미사용 | PRD-APP-001 | `Sources/TBDApp/TheBestDisplayApp.swift` |
| SRS-INF-001 | `DisplayCatalog`: `CGGetOnlineDisplayList`, CoreGraphics 속성, `CoreDisplay_DisplayCreateInfoDictionary`, 프레임버퍼 노드 대응으로 `DisplayIdentity`와 물리 정보 구성 | PRD-INF-001, PRD-PRF-003 | `Sources/TBDPlatform/DisplayCatalog.swift` |
| SRS-INF-002 | `EDIDParser`: 기본 블록, CTA-861 확장(데이터 블록 전체 순회, HDMI VSDB, HF-VSDB, HDR 정적 메타데이터, 색 공간), DisplayID 확장 해석. 블록별 체크섬 검증. 손상 입력에서 충돌 없이 부분 결과 반환 | PRD-INF-002, PRD-INF-004 | `Sources/TBDCore/EDID/` |
| SRS-INF-003 | EDID 원본 획득 순서: `IOAVServiceCopyEDID`, `IOPortTransportStateDisplayPort`의 `EDID` 키. 둘 다 실패 시 EDID 없음으로 표시. 디스플레이 대응은 EDID 머리의 제조사, 제품 코드, 일련번호와 CoreGraphics 값 대조. 일련번호 불일치 시 같은 제품이 1대일 때만 제조사와 제품 코드로 대응. 내장 패널은 EDID 없음 | PRD-INF-003 | `Sources/TBDPlatform/EDIDSource.swift` |
| SRS-MOD-001 | `ModeService` 열거: `SLSGetDisplayModeDescriptionOfLength`의 212바이트 구조체 해석(`DisplayMode.decode`). 심볼 미가용 시 `CGDisplayCopyAllDisplayModes` 대체. 모드별 시스템 설정 표시 여부, 원본, 기본 판정은 `MPDisplay`의 `allModes`에서 조회 | PRD-MOD-001, PRD-MOD-004 | `Sources/TBDPlatform/ModeService.swift` |
| SRS-MOD-002 | 모드 전환 경로 순서: `MPDisplay setModeNumber:`, 공개 API `CGConfigureDisplayWithDisplayMode`. `SLSConfigureDisplayMode` 직접 호출은 명시 지정 시에만 사용 (ADR-0005). 복귀와 확정은 모드 번호가 아닌 모드 서술(해상도, HiDPI, 주사율, 가변 여부)로 대상 모드 재탐색 | PRD-MOD-003, PRD-MOD-005 | `Sources/TBDPlatform/ModeService.swift`<br>`Sources/TBDPlatform/MPDisplayBridge.swift`<br>`Sources/TBDPlatform/DisplayChanges.swift` |
| SRS-MOD-003 | `ModeCatalog`: 해상도별 묶음, HiDPI 판정(배율 2 이상), 필터(배율, 주사율, 종횡비, 시스템 설정 목록 밖). 시스템 설정 목록 포함 여부는 `MPDisplay` 판정 사용, 조회 불가 시 공개 API 기본 열거 결과와 대조. 명령행 모드 지정 해석은 `ModeSpec` | PRD-MOD-002, PRD-MOD-006 | `Sources/TBDCore/ModeCatalog.swift` |
| SRS-MOD-004 | `DisplayOverrideFile`: `/Library/Displays/Contents/Resources/Overrides/DisplayVendorID-<16진수>/DisplayProductID-<16진수>` plist의 `scale-resolutions` 항목 해석과 생성. 추가 항목은 논리 해상도의 2배 크기를 4바이트 빅엔디언 2개로 기록. 플래그가 붙은 기존 항목과 다른 키는 보존. `DisplayOverrideService`: 직접 쓰기 실패 시 임시 파일에 준비하고 설치 명령(mkdir, cp, chmod) 반환. 창 앱은 시스템의 관리자 인증 창으로 실행, 명령행은 명령 출력 | PRD-MOD-007 | `Sources/TBDCore/DisplayOverride.swift`<br>`Sources/TBDPlatform/DisplayOverrideService.swift` |
| SRS-MOD-005 | `RefreshRateMeter`: `NSScreen.displayLink`의 콜백 시각과 보고 주기를 수집. `RefreshMeasurement.compute`: 측정값은 간격 수를 측정 시간으로 나눈 값, 보고값은 보고 주기의 중앙값. 표본 2개 미만이면 측정 불가 | PRD-MOD-008 | `Sources/TBDCore/RefreshMeasurement.swift`<br>`Sources/TBDPlatform/RefreshRateMeter.swift` |
| SRS-MOD-006 | `ModeCatalog.renderingLimits`: 전체 모드의 최대 백킹 폭과 높이, 백킹 면적이 가장 큰 HiDPI 모드. `ModeCatalog.sliderSteps`: 현재 모드와 배율이 같고 종횡비 차이가 2% 이내인 해상도를 폭 순으로 나열하고 단계마다 현재 주사율과 가장 가까운 모드 선택. `ModeFavoritesStore`: Application Support의 `mode-favorites.json`에 제조사, 제품 코드, 일련번호별 모드 서술자 목록 저장 | PRD-MOD-009, PRD-MOD-010 | `Sources/TBDCore/ModeExtras.swift` |
| SRS-COL-001 | `SignalDecoder`: 프레임버퍼 노드의 `TimingElements`, `ColorElements` 사전을 `TimingElement`, `ColorElement`로 변환. 열거형 값은 spikes 문서 2.2절 표 사용. 알 수 없는 값은 원시 값을 보존하여 표시. 선택 목록은 현재 타이밍의 `ColorModes`에서 가상 형식을 제외한 항목 | PRD-COL-002, PRD-COL-005 | `Sources/TBDCore/Signal.swift` |
| SRS-COL-002 | 현재 신호 조회: `IOMobileFramebufferGetDigitalOutMode`의 색 ID와 타이밍 ID, `IOAVServiceGetLinkData`의 0x110바이트 구조체 해석(`VideoLinkData.decode`, spikes 문서 2.1절 오프셋). 프레임버퍼 노드 대응은 SRS 3.2절 규칙. 내장 패널은 링크 데이터 없음 | PRD-COL-001 | `Sources/TBDPlatform/SignalService.swift`<br>`Sources/TBDCore/Signal.swift` |
| SRS-COL-003 | 색 모드 전환: `IOMobileFramebufferSetDigitalOutMode(색 ID, 타이밍 ID)`. 타이밍 ID는 현재 값 유지. 반환 코드 0 이외는 오류로 보고. 복귀와 프로파일 복원은 색 ID가 아닌 `ColorDescriptor`(인코딩, 비트 심도, 레인지, EOTF, 색 공간)로 대상 재탐색 | PRD-COL-003 | `Sources/TBDPlatform/SignalService.swift`<br>`Sources/TBDPlatform/DisplayChanges.swift` |
| SRS-COL-004 | DSC 판정: 색 요소의 `SupportsDSC`, 타이밍 요소의 `DSCRequiredColorElementIDs`, `AppleDPTXController`의 `SupportsDSC`와 `DSCEnabled`, EDID의 DSC 능력을 결합. 현재 DSC 사용 여부의 1차 근거는 현재 색 ID의 `DSCRequiredColorElementIDs` 포함 여부 | PRD-COL-004, PRD-LNK-003 | `Sources/TBDCore/DSCAssessment.swift` |
| SRS-COL-006 | `DSCControl.plan`: 현재 타이밍의 선택 가능 색 모드 중 DSC 필수 목록 포함 여부가 요청 상태와 같은 것을 후보로 삼고 가상 형식과 안전하지 않은 형식 제외. 현재와 같은 전달 함수만 대상. 선택 순서는 같은 서술, 시스템 점수, 같은 픽셀 인코딩, 비트 심도 차이, 같은 레인지. 적용은 SRS-COL-003의 색 모드 전환과 자동 복귀 사용 | PRD-COL-006 | `Sources/TBDCore/DSCControl.swift` |
| SRS-HDR-001 | `HDRService`: 조회는 `SLSDisplaySupportsHDRMode`, `SLSDisplayIsHDRModeEnabled`. 전환 경로 순서는 `MPDisplay setPreferHDRModes:`, `SLSDisplaySetHDRModeEnabled(디스플레이, 켜기 여부)`. EDR 헤드룸은 `NSScreen`의 EDR 속성, 지원 EOTF와 최대 휘도는 EDID. 색 모드의 전달 함수와 HDR 상태 불일치 판정은 `HDRStatus.isMismatched` | PRD-HDR-001, PRD-HDR-002, PRD-HDR-003 | `Sources/TBDPlatform/HDRService.swift` |
| SRS-LNK-001 | `LinkService`: `IOPortTransportStateDisplayPort` 노드를 `DPTransportState`로 해석하고 제품 코드, 일련번호, EDID 머리로 디스플레이에 대응. 레인당 속도는 `NominalSignalingFrequenciesHz` 우선. 내장 패널은 전송 상태 노드가 없어 링크 훈련 데이터로 구성. DSC 상태는 SRS-COL-004 판정, FEC는 전원이 켜진 송신기가 1개일 때만 표시 | PRD-LNK-001, PRD-LNK-003 | `Sources/TBDPlatform/LinkService.swift`<br>`Sources/TBDCore/Link.swift` |
| SRS-LNK-002 | `BandwidthCalculator`: 3.3절 계산식 구현. `LinkAnalyzer`: 링크 보고(원시, 유효, 필요 대역폭, 사용률)와 색 형식별 수용 판정(선택 가능, 대역폭 초과, 미제공) 구성 | PRD-LNK-002, PRD-DGN-002 | `Sources/TBDCore/Link.swift` |
| SRS-LNK-003 | HDMI 링크 조회: 프레임버퍼 `Transport`의 하류 종류와 전송 상태의 하류 포트 종류로 HDMI 판별. TMDS 문자 속도는 픽셀 클록과 색 형식으로 계산. `IOAVServiceGetFRLLinkData`는 구조 미확인으로 원시 8바이트 표시 | PRD-LNK-004 | `Sources/TBDPlatform/LinkService.swift`<br>`Sources/TBDCore/Link.swift` |
| SRS-LNK-004 | DPCD 읽기: `IODPDeviceReadDPCD`로 000h-00Fh, 060h-06Fh, 100h-107h, 160h, 200h-207h, 2200h-220Fh. 구간별 실패 허용, 수신기 능력을 읽지 못하면 nil. `DPCDDecoder`로 해석. `IODPDeviceGetLinkTrainingData`의 레인 수와 속도 부호는 `LinkTrainingData`로 해석 | PRD-LNK-005 | `Sources/TBDPlatform/LinkService.swift`<br>`Sources/TBDCore/DPCDDecoder.swift` |
| SRS-PRT-001 | `PortService`: 3.2절의 포트 컨트롤러 클래스와 `IOPortTransportState` 계열 노드 속성을 읽어 `PortInventory.decode`로 `PortInfo`, `CIOState`, `USBState`, `CableEMarker` 구성. 케이블 e-marker는 `IOPortTransportComponentCCUSBPDSOPp` 노드의 케이블 VDO 해석(속도, 전류, 전압, EPR). 부속 노드의 포트 연결은 부모 포트 종류와 번호 | PRD-PRT-001, PRD-PRT-002 | `Sources/TBDPlatform/PortService.swift`<br>`Sources/TBDCore/Ports.swift` |
| SRS-PRT-002 | `ConnectionPathBuilder`: 포트마다 포트, 케이블, 독 또는 허브, 영상 링크, 디스플레이 단계 구성. 단계 상태는 정상, 정보 없음, 끊김. HPD는 감지되나 링크가 없는 경우와 링크는 있으나 온라인 목록에 없는 경우를 끊김으로 표시 | PRD-PRT-003 | `Sources/TBDCore/Ports.swift` |
| SRS-PRT-003 | `PortInfo.plugOrientation`: 포트 노드의 `PlugOrientation` 원시 값 (연결 없음 0, 연결 시 1 또는 2). `PhyInfo`: 속성 `AppleTypeCPhyID`가 있는 노드에서 `AppleTypeCPhyLane`, `AppleTypeCPhyUSB2`, `AppleTypeCPhyDisplayPortTunnel`, `AppleTypeCPhyDisplayPortPclk` 해석. 클래스 이름이 칩마다 달라 속성 존재 매칭(`IOPropertyExistsMatch`)으로 수집. USB-C 포트 번호는 PHY 번호 + 1로 대응. 연결 경로에 PHY 단계 추가. `PowerAdapterInfo`: `AppleSmartBattery`의 `ExternalConnected`와 `AdapterDetails`(`Watts`, `AdapterVoltage`, `Current`, `Name`, `UsbHvcMenu`) 해석 | PRD-PRT-004, PRD-PRT-005 | `Sources/TBDCore/Ports.swift`<br>`Sources/TBDPlatform/PortService.swift` |
| SRS-DGN-001 | `DiagnosticEngine`: `DiagnosticSnapshot`을 받아 `DiagnosticResult`(발견 항목, 포트별 점검)를 반환하는 순수 함수. 포트 점검은 물리 연결, HPD, EDID, 링크, 프레임버퍼, 온라인 6단계이며 첫 실패 뒤는 생략 처리. 규칙별 부호, 심각도(정보, 주의, 문제), 근거 수치, 조치 문구 보유. 칩별 외장 디스플레이 한도는 추정값으로 표기. 스냅샷 수집은 `SnapshotBuilder` | PRD-DGN-001, PRD-DGN-002, PRD-DGN-003, PRD-DGN-006 | `Sources/TBDCore/Diagnostics/`<br>`Sources/TBDPlatform/SnapshotBuilder.swift` |
| SRS-DGN-002 | `EventLog`: 직전 `EventState`와 현재 상태의 차이로 이벤트 생성(디스플레이 연결과 해제, 모드, 색 모드, HDR, 링크, HPD, 포트 연결), 최근 1,000건 보관. 변화 감지는 CoreGraphics 재구성 콜백과 포트 상태 2초 주기 대조 | PRD-DGN-004 | `Sources/TBDCore/Diagnostics/EventLog.swift`<br>`Sources/TBDApp/DisplayStore.swift` |
| SRS-DGN-003 | `ReportExporter`: 스냅샷, 진단 결과, 이벤트를 JSON과 텍스트로 직렬화. 가림 옵션은 일련번호, UUID, EDID 일련번호 바이트 제거. 현재 타이밍 외의 색 모드 목록은 축약 | PRD-DGN-005 | `Sources/TBDCore/Diagnostics/ReportExporter.swift`<br>`Sources/TBDCore/Diagnostics/DiagnosticSnapshot.swift` |
| SRS-BRT-001 | `BrightnessService`: 제어 방식 선택 순서는 시스템 밝기 제어(DisplayServices, 내장 패널과 Apple 디스플레이 한정), DDC(탐지에서 밝기 코드 응답 시), 소프트웨어 디밍. 자동 밝기는 DisplayServices의 주변광 보정 함수 | PRD-BRT-001, PRD-BRT-003, PRD-BRT-004 | `Sources/TBDPlatform/BrightnessService.swift` |
| SRS-BRT-002 | `XDRBoostService`: 대상 화면 구석의 8포인트 창(`CAMetalLayer`, `rgba16Float`, `wantsExtendedDynamicRangeContent`)에 1.0을 넘는 값을 그려 EDR 헤드룸을 유지하고, `GammaService`가 기준 테이블 합성 뒤 전달 테이블에 배율을 곱함. 지원 판정은 `NSScreen`의 잠재 EDR 헤드룸 1 초과. 구성 변경 시 창 재배치, 종료 시 해제 | PRD-BRT-005 | `Sources/TBDPlatform/XDRBoostService.swift`<br>`Sources/TBDCore/GammaTable.swift` |
| SRS-BRT-003 | 밝기 동기화: `BrightnessSync.targetLevel`은 원본 밝기를 대상 방식의 범위로 변환(소프트웨어 디밍 하한 10%), `shouldApply`는 마지막 적용값과 1% 이상 차이일 때만 적용. `BrightnessSyncService`는 대상별 제어 방식을 한 번 판정해 두고 `syncOnce`마다 원본 밝기를 읽어 적용, 종료 시 소프트웨어 디밍 대상을 복원. 창 앱은 1초, 명령행은 0.5초 주기 | PRD-BRT-006 | `Sources/TBDCore/BrightnessSync.swift`<br>`Sources/TBDPlatform/BrightnessSyncService.swift` |
| SRS-DDC-001 | `DDCService`: `IOAVServiceWriteI2C`와 `IOAVServiceReadI2C`(주소 0x37, 오프셋 0x51), 패킷 체크섬 계산, 재시도 3회, 직렬 큐. 탐지는 밝기, 대비, 볼륨, 입력 소스 읽기이며 앞의 두 코드에 응답이 없으면 미지원 판정. 창 앱은 탐지와 쓰기를 메인 스레드 밖에서 수행하고 연속 쓰기는 150 ms 간격으로 묶음. `DDCPacket`, `VCPCode`, `DDCProbe`는 TBDCore에 배치 | PRD-DDC-001, PRD-DDC-002, PRD-DDC-003, PRD-BRT-002 | `Sources/TBDPlatform/DDCService.swift`<br>`Sources/TBDCore/DDCPacket.swift` |
| SRS-CLR-001 | `GammaService`: 디밍, 색온도, 게인, 대비, 감마를 하나의 전달 테이블로 합성(`GammaTable.make`)하고 조정 전 테이블(디스플레이 보정값) 위에 겹쳐 `CGSetDisplayTransferByTable` 적용. 전체 초기화는 `CGDisplayRestoreColorSyncSettings`. 재구성 뒤 현재 테이블이 마지막 적용값과 다를 때만 재적용. 앱 종료 시 복원 | PRD-CLR-002, PRD-BRT-003 | `Sources/TBDPlatform/GammaService.swift`<br>`Sources/TBDCore/GammaTable.swift` |
| SRS-CLR-002 | `ColorProfileService`: 현재 프로파일은 `ColorSyncProfileCreateWithDisplayID`, 목록은 공장 프로파일과 `ColorSyncIterateInstalledProfiles`의 RGB 디스플레이 클래스 프로파일, 지정은 `ColorSyncDeviceSetCustomProfiles`(기본값 복귀는 `kCFNull`). 정렬과 중복 제거는 `ColorProfileCatalog` | PRD-CLR-001 | `Sources/TBDPlatform/ColorProfileService.swift` |
| SRS-CLR-003 | `NightShiftService`(`CBBlueLightClient`의 상태, 켜기와 끄기, 강도), `TrueToneService`(`CBTrueToneClient`의 지원, 사용 가능, 켜기와 끄기): Objective-C 런타임 동적 호출. 상태 구조체 해석은 `NightShiftStatus.decodeStatus` | PRD-CLR-003, PRD-CLR-004 | `Sources/TBDPlatform/NightShiftService.swift` |
| SRS-CLR-004 | `PresetService`: `MPDisplay`의 `hasPresets`, `presets`, `activePreset`, `defaultPreset`으로 목록 구성, `setActivePreset:`으로 전환. 사용할 수 없는 빈 자리(`isValid` 거짓)는 표시에서 제외. 복귀 동작 `preset`은 프리셋 번호로 지정 | PRD-CLR-005 | `Sources/TBDPlatform/PresetService.swift`<br>`Sources/TBDCore/DisplayPreset.swift` |
| SRS-ARR-001 | `ArrangementService`: CoreGraphics 구성 트랜잭션으로 원점, 미러 처리. 계산은 `ArrangementPlanner`: 메인 지정은 대상을 원점 (0, 0)으로 옮기는 전체 평행 이동, 위치 이동은 다른 디스플레이와 맞닿는 가장 가까운 위치로 보정 후 메인 원점 정규화. 미러 대상은 배치 계산에서 제외 | PRD-ARR-002, PRD-ARR-003, PRD-ARR-004 | `Sources/TBDPlatform/ArrangementService.swift` |
| SRS-ARR-002 | 회전: `MPDisplay`의 `setOrientation:`. 적용은 비동기라 `CGDisplayRotation`이 목표값이 될 때까지 최대 10초 대기. 내장 디스플레이는 대상에서 제외. `SLSSetDisplayRotation`은 시그니처 불일치 보고가 있어 사용하지 않음 | PRD-ARR-001 | `Sources/TBDPlatform/ArrangementService.swift` |
| SRS-ARR-003 | 연결 해제와 재연결: 구성 트랜잭션 안의 `SLSConfigureDisplayEnabled`. 해제 대상을 제외한 온라인 디스플레이가 0개이면 시스템 호출 전에 거부. 재연결은 온라인 목록에 나타날 때까지 대기 후 판정. 창 앱은 이 앱에서 해제한 디스플레이 목록을 유지하고 자동 복귀의 복귀 동작은 재연결 | PRD-ARR-005, PRD-SAF-003 | `Sources/TBDPlatform/ArrangementService.swift` |
| SRS-ARR-004 | 언더스캔: `MPDisplay`의 `supportsUnderscan`, `underscan`, `minUnderscan`, `maxUnderscan`, `setUnderscan:` (시스템 설정과 같은 경로) | PRD-ARR-006 | `Sources/TBDPlatform/ArrangementService.swift` |
| SRS-VRT-001 | `VirtualDisplayService`: `CGVirtualDisplay` 생성(전용 콜백 큐), 모드 적용, HiDPI 모드 선택, 온라인 대기, 삭제. 프로세스 수명 동안 객체 유지. 구성(`VirtualDisplayConfig`)은 유효성 검사 후 생성하고 `VirtualDisplayStore`가 JSON으로 저장. 실행 시 복원 대상은 앱 시작 때 생성. 창 앱의 생성은 메인 스레드 밖에서 수행 | PRD-VRT-001, PRD-VRT-003 | `Sources/TBDPlatform/VirtualDisplayService.swift`<br>`Sources/TBDCore/VirtualDisplay.swift` |
| SRS-VRT-002 | HiDPI 스케일링: HiDPI 가상 디스플레이 생성 후 실제 디스플레이를 가상 디스플레이의 미러로 구성. 해제 시 미러 해제와 가상 디스플레이 삭제. 후보 해상도와 선명도 설명은 `HiDPIScaling`(원본 종횡비 유지, 백킹 폭 상한 7680픽셀). 적용과 해제는 자동 복귀 안전장치 경유 | PRD-VRT-002 | `Sources/TBDPlatform/VirtualDisplayService.swift` |
| SRS-PRF-001 | `ProfileStore`: Application Support의 JSON 파일. 판 번호 필드 보유(상위 판 항목은 읽지 않음). 이름 중복과 빈 이름 거부, 이름 변경, 삭제. 디스플레이 대응(`ProfilePlanner.match`)은 UUID, 제조사와 제품 코드와 일련번호 순이며 한 디스플레이는 한 항목에만 대응 | PRD-PRF-001, PRD-PRF-003 | `Sources/TBDCore/Profile.swift` |
| SRS-PRF-002 | 프로파일 적용: `ProfilePlanner.plan`이 저장 구성과 현재 구성의 차이만 단계로 산출. 순서는 미러, 회전, 모드, HDR, 색 모드, 배치, 밝기(회전이 모드 목록을 바꾸고, 모드와 HDR 전환이 색 모드를 다시 선택하게 하므로). 단계 실패 시 나머지 단계 계속 수행, 단계별 결과(적용, 변경 없음, 건너뜀, 실패) 수집. 적용 전체는 자동 복귀 안전장치 경유이며 복귀는 적용 전 구성 재적용 | PRD-PRF-002 | `Sources/TBDPlatform/ProfileApplier.swift`<br>`Sources/TBDCore/Profile.swift` |
| SRS-PRF-003 | 구성 보호: `ProtectionStore`는 Application Support의 `protection.json`에 프로파일 ID와 보호 대상 단계 저장. `ProtectionSetting.deviations`는 `ProfilePlanner.plan`의 단계 중 보호 대상만 산출. `ProtectionGuard`는 60초 창 안의 복원 횟수가 3회에 이르면 일시 중지. `ProtectionController`는 디스플레이 구성 변경 뒤 1.5초를 기다려 차이를 확인하고 `ProfileApplier.apply(only:)`로 복원, 설정 파일을 매번 다시 읽어 명령행 설정 반영, 복원이 일으킨 재구성 알림은 건너뜀 | PRD-PRF-004 | `Sources/TBDCore/Protection.swift`<br>`Sources/TBDApp/ProtectionController.swift` |
| SRS-SAF-001 | `RevertStateMachine`: PRD 3절 상태 전이의 순수 구현. `RevertCoordinator`: 효과 실행기. 타이머와 적용, 확정, 복귀 동작 주입으로 단위 테스트 가능. 창 앱은 `ChangeController`, 명령행은 `performGuardedChange`가 구동 | PRD-SAF-001 | `Sources/TBDCore/RevertGuard.swift` |
| SRS-SAF-002 | `PendingRevertStore`: 복귀 정보 파일 기록, 조회, 삭제. 손상 파일은 없음으로 처리. 앱 실행 시 파일이 있으면 복귀 제안, 명령행은 `revert-pending`. 복귀 동작 수행은 `PendingRevertApplier` | PRD-SAF-002 | `Sources/TBDCore/RevertGuard.swift`<br>`Sources/TBDPlatform/PendingRevertApplier.swift` |
| SRS-CLI-001 | `tbdctl`: 하위 명령 분기, `--json` 출력, PRD 5절 종료 코드. 인자 해석은 TBDCore의 `CommandLineParser` | PRD-CLI-001, PRD-CLI-002, PRD-CLI-003 | `Sources/tbdctl/`<br>`Sources/TBDCore/CommandLineParser.swift` |
| SRS-EDO-001 | `EDIDEditor`: 검증은 길이, 머리, 확장 블록 수, 블록별 체크섬 확인. 편집은 CTA 확장 블록을 머리, 데이터 블록, 18바이트 서술자로 분해한 뒤 다시 조립하여 상세 타이밍 시작 오프셋과 체크섬을 재계산. HDMI Forum 블록(VSDB와 SCDB)은 판 번호 기준 같은 오프셋으로 처리. 대상 선언이 없으면 변경 없음으로 보고 | PRD-EDO-001, PRD-EDO-002 | `Sources/TBDCore/EDID/EDIDEditor.swift` |
| SRS-EDO-002 | `EDIDOverrideService`: `IOAVServiceSetVirtualEDIDMode(서비스, 모드, EDID)` 호출 (모드 1 적용, 0 해제). 대상 서비스는 EDID가 읽히는 외장 `DCPAVServiceProxy` 중 제조사, 제품 코드, 일련번호가 일치하는 것. 적용과 해제 뒤 `SLSDetectDisplays`로 재감지. 복귀 동작 `edidReset`은 서비스의 레지스트리 항목 ID로 지정하고 서비스가 없으면 외장 서비스 전체 해제 | PRD-EDO-003, PRD-EDO-004 | `Sources/TBDPlatform/EDIDOverrideService.swift`<br>`Sources/TBDPlatform/DisplayChanges.swift` |
| SRS-EDO-003 | `DetailedTimingSpec`: CVT 축소 블랭킹 계산(최소 수직 블랭킹 460 µs, 1판은 수평 블랭킹 160과 클록 단계 0.25 MHz, 2판은 수평 블랭킹 80과 클록 단계 0.001 MHz), 18바이트 서술자와 DisplayID 20바이트 타이밍 부호화. 주입 자리 우선순위는 기본 블록의 더미 서술자, CTA 확장 블록의 여유 공간, DisplayID 확장 블록(없으면 새 확장 블록). 선호 지정은 기본 블록의 첫 서술자 교체와 기존 타이밍 이동. DisplayID 구역 체크섬과 블록 체크섬 재계산 | PRD-EDO-005 | `Sources/TBDCore/EDID/CustomTiming.swift`<br>`Sources/TBDCore/EDID/EDIDEditor.swift` |
