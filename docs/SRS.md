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
    public static func evaluate(_ snapshot: SystemSnapshot) -> [Finding]
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
| SRS-COL-001 | `SignalDecoder`: 프레임버퍼 노드의 `TimingElements`, `ColorElements` 사전을 `TimingElement`, `ColorElement`로 변환. 열거형 값은 spikes 문서 2.2절 표 사용 | PRD-COL-002, PRD-COL-005 | `Sources/TBDCore/SignalDecoder.swift` |
| SRS-COL-002 | 현재 신호 조회: `IOMobileFramebufferGetDigitalOutMode`의 색 ID와 타이밍 ID, `IOAVServiceGetLinkData`의 0x110바이트 구조체 해석(spikes 문서 2.1절 오프셋) | PRD-COL-001 | `Sources/TBDPlatform/SignalService.swift` |
| SRS-COL-003 | 색 모드 전환: `IOMobileFramebufferSetDigitalOutMode(색 ID, 타이밍 ID)`. 반환 코드 0 이외는 오류로 보고 | PRD-COL-003 | `Sources/TBDPlatform/SignalService.swift` |
| SRS-COL-004 | DSC 판정: 색 요소의 `SupportsDSC`, 타이밍 요소의 `DSCRequiredColorElementIDs`, `AppleDPTXController`의 `SupportsDSC`와 `DSCEnabled`, EDID의 DSC 능력을 결합. 현재 DSC 사용 여부의 1차 근거는 현재 색 ID의 `DSCRequiredColorElementIDs` 포함 여부 | PRD-COL-004, PRD-LNK-003 | `Sources/TBDCore/DSCAssessment.swift` |
| SRS-HDR-001 | `HDRService`: `SLSDisplaySupportsHDRMode`, `SLSDisplayIsHDRModeEnabled`, `SLSDisplaySetHDRModeEnabled`. EDR 헤드룸은 `NSScreen`의 EDR 속성 | PRD-HDR-001, PRD-HDR-002, PRD-HDR-003 | `Sources/TBDPlatform/HDRService.swift` |
| SRS-LNK-001 | `LinkService`: `IOPortTransportStateDisplayPort` 노드를 3.2절 규칙으로 디스플레이에 대응시키고 `LinkState` 구성 | PRD-LNK-001 | `Sources/TBDPlatform/LinkService.swift` |
| SRS-LNK-002 | `BandwidthCalculator`: 3.3절 계산식 구현 | PRD-LNK-002, PRD-DGN-002 | `Sources/TBDCore/BandwidthCalculator.swift` |
| SRS-LNK-003 | HDMI 링크 조회: `AppleHDMIPortController` 속성과 `IOAVServiceGetFRLLinkData` | PRD-LNK-004 | `Sources/TBDPlatform/LinkService.swift` |
| SRS-LNK-004 | `DPCDReader`: `IODPDeviceReadDPCD`로 000h-00Fh, 060h-06Fh, 100h-107h, 200h-207h, 2200h-220Fh 읽기. 실패 시 nil. `DPCDDecoder`로 해석 | PRD-LNK-005 | `Sources/TBDPlatform/DPCDReader.swift`<br>`Sources/TBDCore/DPCDDecoder.swift` |
| SRS-PRT-001 | `PortService`: 3.2절의 포트 컨트롤러 클래스와 `IOPortTransportState` 계열 노드에서 `Port`와 `TransportState` 구성. 케이블 e-marker는 `IOPortTransportComponentCCUSBPDSOPp` 노드 | PRD-PRT-001, PRD-PRT-002 | `Sources/TBDPlatform/PortService.swift` |
| SRS-PRT-002 | `ConnectionPath` 조립: 포트, CIO 전송(독과 케이블), DP 전송, 프레임버퍼, 디스플레이를 순서대로 연결 | PRD-PRT-003 | `Sources/TBDCore/ConnectionPath.swift` |
| SRS-DGN-001 | `DiagnosticEngine`: `SystemSnapshot`을 받아 `Finding` 목록을 반환하는 순수 함수. 규칙별 코드, 심각도, 근거 수치, 조치 문구 보유 | PRD-DGN-001, PRD-DGN-002, PRD-DGN-003, PRD-DGN-006 | `Sources/TBDCore/Diagnostics/` |
| SRS-DGN-002 | `EventMonitor`: CoreGraphics 재구성 콜백과 IOKit 서비스 알림 수신, 스냅샷 차이로 이벤트 생성, 최근 1,000건 보관 | PRD-DGN-004 | `Sources/TBDPlatform/EventMonitor.swift` |
| SRS-DGN-003 | `ReportExporter`: 스냅샷, 발견 항목, 이벤트를 JSON과 텍스트로 직렬화. 일련번호 가림 옵션 | PRD-DGN-005 | `Sources/TBDCore/ReportExporter.swift` |
| SRS-BRT-001 | `BrightnessService`: 제어 방식 선택 순서는 DisplayServices, DDC, 소프트웨어 디밍. 자동 밝기는 DisplayServices의 주변광 보정 함수 | PRD-BRT-001, PRD-BRT-003, PRD-BRT-004 | `Sources/TBDPlatform/BrightnessService.swift` |
| SRS-DDC-001 | `DDCService`: `IOAVServiceWriteI2C`와 `IOAVServiceReadI2C`(주소 0x37, 오프셋 0x51), 패킷 체크섬 계산, 재시도 3회, 직렬 큐. `DDCPacket`은 TBDCore에 배치 | PRD-DDC-001, PRD-DDC-002, PRD-DDC-003, PRD-BRT-002 | `Sources/TBDPlatform/DDCService.swift`<br>`Sources/TBDCore/DDCPacket.swift` |
| SRS-CLR-001 | `GammaService`: 디밍, 색온도, 게인, 대비, 감마를 하나의 전달 테이블로 합성하여 `CGSetDisplayTransferByTable` 적용. 초기화는 `CGDisplayRestoreColorSyncSettings`. 테이블 합성은 TBDCore의 `GammaTable` | PRD-CLR-002, PRD-BRT-003 | `Sources/TBDPlatform/GammaService.swift`<br>`Sources/TBDCore/GammaTable.swift` |
| SRS-CLR-002 | `ColorProfileService`: ColorSync 장치 프로파일 열거와 사용자 지정 프로파일 설정 | PRD-CLR-001 | `Sources/TBDPlatform/ColorProfileService.swift` |
| SRS-CLR-003 | `NightShiftService`(`CBBlueLightClient`), `TrueToneService`(`CBTrueToneClient`): Objective-C 런타임 동적 호출 | PRD-CLR-003, PRD-CLR-004 | `Sources/TBDPlatform/NightShiftService.swift` |
| SRS-ARR-001 | `ArrangementService`: CoreGraphics 구성 트랜잭션으로 원점, 미러, 메인 지정(대상을 원점 0,0으로 이동하고 나머지 상대 이동) 처리 | PRD-ARR-002, PRD-ARR-003, PRD-ARR-004 | `Sources/TBDPlatform/ArrangementService.swift` |
| SRS-ARR-002 | 회전: `MPDisplay`의 `setOrientation:` 우선, 대체 경로는 `SLSSetDisplayRotation` | PRD-ARR-001 | `Sources/TBDPlatform/ArrangementService.swift` |
| SRS-ARR-003 | 연결 해제와 재연결: `SLSConfigureDisplayEnabled`. 해제 대상을 제외한 온라인 디스플레이가 0개이면 거부. 해제된 디스플레이 목록 유지 | PRD-ARR-005, PRD-SAF-003 | `Sources/TBDPlatform/ArrangementService.swift` |
| SRS-ARR-004 | 언더스캔: `SLSDisplayGetUnderscan`과 `SLSDisplaySetUnderscan` | PRD-ARR-006 | `Sources/TBDPlatform/ArrangementService.swift` |
| SRS-VRT-001 | `VirtualDisplayService`: `CGVirtualDisplay` 생성, 모드 적용, 삭제. 프로세스 수명 동안 객체 유지. 구성은 JSON 저장 | PRD-VRT-001, PRD-VRT-003 | `Sources/TBDPlatform/VirtualDisplayService.swift` |
| SRS-VRT-002 | HiDPI 스케일링: HiDPI 가상 디스플레이 생성 후 실제 디스플레이를 가상 디스플레이의 미러로 구성. 해제 시 미러 해제와 가상 디스플레이 삭제 | PRD-VRT-002 | `Sources/TBDPlatform/VirtualDisplayService.swift` |
| SRS-PRF-001 | `ProfileStore`: Application Support의 JSON 파일. 판 번호 필드 보유. 디스플레이 대응 규칙은 UUID, 제조사와 제품 코드와 일련번호 순 | PRD-PRF-001, PRD-PRF-003 | `Sources/TBDCore/Profile.swift` |
| SRS-PRF-002 | 프로파일 적용 순서: 연결 활성, 미러, 모드, 색 모드, HDR, 회전, 배치, 밝기. 단계별 결과 수집 | PRD-PRF-002 | `Sources/TBDPlatform/ProfileApplier.swift` |
| SRS-SAF-001 | `RevertStateMachine`: PRD 3절 상태 전이의 순수 구현. `RevertCoordinator`: 효과 실행기. 타이머와 적용, 확정, 복귀 동작 주입으로 단위 테스트 가능. 창 앱은 `ChangeController`, 명령행은 `performGuardedChange`가 구동 | PRD-SAF-001 | `Sources/TBDCore/RevertGuard.swift` |
| SRS-SAF-002 | `PendingRevertStore`: 복귀 정보 파일 기록, 조회, 삭제. 손상 파일은 없음으로 처리. 앱 실행 시 파일이 있으면 복귀 제안, 명령행은 `revert-pending`. 복귀 동작 수행은 `PendingRevertApplier` | PRD-SAF-002 | `Sources/TBDCore/RevertGuard.swift`<br>`Sources/TBDPlatform/PendingRevertApplier.swift` |
| SRS-CLI-001 | `tbdctl`: 하위 명령 분기, `--json` 출력, PRD 5절 종료 코드. 인자 해석은 TBDCore의 `CommandLineParser` | PRD-CLI-001, PRD-CLI-002, PRD-CLI-003 | `Sources/tbdctl/`<br>`Sources/TBDCore/CommandLineParser.swift` |
