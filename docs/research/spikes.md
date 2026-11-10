# 선행 검증 실험 결과

- 목적: 명세의 전제가 되는 기술 가정을 최소 코드로 실측
- 실험 환경: MacBook Pro (Apple M5), macOS 26.5.2 (25F84), Xcode 26.6, Swift 6.3.3
- 연결 구성: 내장 Liquid Retina XDR (3024x1964) + LG TV SSCR2 (3840x2160, 120 Hz, HDR) — USB-C 포트 4번, Thunderbolt 독(Parade PS9010) 경유, DisplayPort 터널링
- 범위: 읽기 전용 호출만 수행. 디스플레이 상태를 변경하는 쓰기 경로는 Phase 0에서 미검증이며 해당 기능 항목의 TC에서 검증
- 실험 결과는 제품 TC 통과로 간주하지 않음

## 1. 실험 목록

| 실험 | 코드 | 재현 명령 |
| --- | --- | --- |
| 01 읽기 전용 비공개 API 프로브 | `spikes/01_readonly_probe/probe.swift` | `swiftc -O spikes/01_readonly_probe/probe.swift -o /tmp/tbd_probe && /tmp/tbd_probe` |
| 02 링크 데이터와 DPCD 프로브 | `spikes/02_link_probe/probe.swift` | `swiftc -O spikes/02_link_probe/probe.swift -o /tmp/tbd_link && /tmp/tbd_link` |
| 03 IORegistry 키 조사 | 명령행 (`ioreg -l -w0`, `ioreg -r -c <클래스> -a`) | 3절 표의 클래스명으로 재현 |
| 04 프레임워크 심볼 조사 | 명령행 (`dyld_info -exports`, `dyld_info -disassemble`) | 4절 표의 프레임워크 경로로 재현 |

## 2. 실험 01, 02 결과

| 번호 | 가정 | 호출 | 결과 | 판정 |
| --- | --- | --- | --- | --- |
| S1 | 숨은 모드를 포함한 전체 모드 열거 가능 | `SLSGetNumberOfDisplayModes`, `SLSGetDisplayModeDescriptionOfLength` (212바이트 구조체), `SLSGetCurrentDisplayMode` | 외장 319개(HiDPI 186개), 내장 132개. 공개 API는 외장 277개 | 확인 |
| S1-2 | 모드별 VRR, ProMotion 여부 조회 가능 | `SLSIsDisplayModeVRR`, `SLSIsDisplayModeProMotion` | 내장 현재 모드 true, 외장 false | 확인 |
| S2 | HDR 지원과 활성 상태 조회 가능 | `SLSDisplaySupportsHDRMode`, `SLSDisplayIsHDRModeEnabled` | 외장 지원 true, 활성 true. 내장 false, false | 확인 |
| S3 | 링크 속도, 레인 수, HPD, EDID를 권한 상승 없이 조회 가능 | IORegistry `IOPortTransportStateDisplayPort` | `8.1 Gbps (HBR3)`, 4레인, HPD High, EDID 384바이트 | 확인 |
| S4 | 현재 타이밍 ID와 색 모드 ID 조회 가능 | `IOMobileFramebufferOpen`, `IOMobileFramebufferGetDigitalOutMode` | 외장 색 ID 122, 타이밍 ID 96. 내장 색 ID 1, 타이밍 ID 2. 엔타이틀먼트 불필요 | 확인 |
| S5 | IOAVService로 EDID와 DDC 접근 가능 | `IOAVServiceCreateWithService`, `IOAVServiceCopyEDID`, `IOAVServiceReadI2C`, `IOAVServiceWriteI2C` | EDID 384바이트 획득. DDC VCP 0x10, 0x12, 0x62, 0x60 응답 없음 (TV, 독 경유) | EDID 확인, DDC는 해당 TV 미지원으로 미검증 |
| S6 | 밝기 조회 가능 | `DisplayServicesGetBrightness`, `DisplayServicesCanChangeBrightness` | 내장 0.62, 외장 1.0 (canChange true) | 확인 |
| S7 | 가상 디스플레이와 보조 클래스 존재 | `NSClassFromString` | `CGVirtualDisplay`, `CGVirtualDisplayDescriptor`, `CGVirtualDisplaySettings`, `CGVirtualDisplayMode`, `MPDisplay`, `MPDisplayMgr`, `CBBlueLightClient`, `CBTrueToneClient`, `CBAdaptationClient` 모두 존재 | 확인 |
| L1 | 실제 송출 중인 신호 형식 조회 가능 | `IOAVServiceGetLinkData(service, 1, buf[0x110])` | 3840x2160, 120 Hz, 12 bpc, YCbCr 4:2:2, Limited, BT.2020, PQ, 픽셀 클록 1,071.36 MHz | 확인 |
| L2 | DPCD 레지스터 읽기 가능 | `IODPDeviceReadDPCD(dev, addr, buf, len)` | 내장 성공. 외장(독 터널링)은 0xe00002ca(kIOReturnIOError) | 내장 확인, 터널링 경로 불가 |
| L3 | 링크 훈련 데이터 조회 가능 | `IODPDeviceGetLinkTrainingData(dev, buf[0x98])` | 외장 레인 4, 속도 코드 0x1e(HBR3) | 확인 |
| L4 | 통합 진단 문자열 획득 가능 | `IOAVCreateDiagnosticsStringWithLocation(allocator, 0)`, `IOAVServiceCopyDiagnosticsString` | 빈 문자열, nil | 불가 (권한 필요 추정, 미확인) |
| L5 | HDMI FRL 링크 데이터 조회 가능 | `IOAVServiceGetFRLLinkData(service, buf[8])` | 호출 성공, 값 0 (DP 연결) | 호출 확인, HDMI 값은 미검증 |

### 2.1 링크 데이터 구조체 오프셋 (L1 실측)

| 오프셋 | 값 | 해석 |
| --- | --- | --- |
| 0x18 | 12 | 비트 심도 (bpc) |
| 0x1c | 2 | 픽셀 인코딩 (YCbCr 4:2:2) |
| 0x20 | 1 | 다이내믹 레인지 (Limited) |
| 0x24 | 7 | 색 공간 (BT.2020 YCbCr) |
| 0x28 | 2 | EOTF (SMPTE ST 2084) |
| 0x3c, 0x40 | 3968, 3840 | 수평 총 픽셀, 활성 픽셀 |
| 0x5c, 0x60 | 2250, 2160 | 수직 총 라인, 활성 라인 |
| 0x70 | 0x00780000 | 수직 주사율 (16.16 고정소수점, 120 Hz) |
| 0x7c | 1,071,360,000 | 픽셀 클록 (Hz) |

- 검산: 3968 x 2250 x 120 = 1,071,360,000
- 대역폭 해석: 4:2:2 12 bpc는 픽셀당 24비트이며 25.71 Gbps. HBR3 4레인의 유효 대역폭 25.92 Gbps 이내. RGB 10 bpc는 32.14 Gbps로 초과. 싱크의 DSC 미지원(`SupportsDSC` = 0)과 결합되어 RGB 10 bpc 120 Hz 선택 불가. 이 판정 절차가 진단 엔진(PRD-DGN)의 근거

### 2.2 열거형 값 (IOKit 문자열 함수로 확인)

| 항목 | 함수 | 값 |
| --- | --- | --- |
| 픽셀 인코딩 | `IOAVVideoPixelEncodingString` | 0 RGB 4:4:4, 1 YCbCr 4:2:0, 2 YCbCr 4:2:2, 3 YCbCr 4:4:4, 4 DolbyVision (native), 5 DolbyVision (HDMI tunneling), 6 YCbCr 4:2:2 (DP tunneling), 7 YCbCr 4:2:2 (HDMI tunneling), 8 DolbyVision LL YCbCr 4:2:2, 9 DolbyVision LL YCbCr 4:2:2 (DP tunneling) |
| EOTF | `IOAVVideoColorEOTFString` | 0 Traditional gamma (SDR), 1 Traditional gamma (HDR), 2 SMPTE ST 2084 (PQ), 3 BT.2100 HLG |
| 다이내믹 레인지 | `IOAVVideoColorDynamicRangeString` | 0 Full, 1 Limited |
| 색 공간 | `IOAVVideoColorimetryString` | 0 BT.601, 1 BT.709, 2 xvYCC601, 3 xvYCC709, 4 sYCC601, 5 AdobeYCC601, 6 BT.2020 (YcCbcCrc), 7 BT.2020 (YCbCr), 8 DolbyVision VSVDB, 9 BT.2020 (RGB), 10 sRGB, 11 scRGB, 12 scRGBfixed, 13 AdobeRGB, 14 DCI-P3 (D65), 15 DCI-P3 (Theater), 16 Default RGB |
| 전송 방식 | `IOAVTransportString` | 0 DP, 1 VGA, 2 DVI, 3 HDMI, 4 MIPI |
| 타이밍 표준 | `IOAVStandardTypeString` | 0 None, 1 VESA, 2 CEA |
| 타이밍 유형 | `IOAVVideoTimingTypeString` | 0 Established, 1 Standard, 2 Calculated, 3 Detailed, 4 CEAShortID |
| HDMI FRL 속도 | `IOAVHDMIFRLRateString` | 0 비활성, 1 9 Gbps, 2 18 Gbps, 3 24 Gbps, 4 32 Gbps, 5 40 Gbps, 6 48 Gbps |

## 3. 실험 03 결과: IORegistry 클래스와 키

| 클래스 | 용도 | 확인한 키 |
| --- | --- | --- |
| `IOMobileFramebufferShim` | 디스플레이별 프레임버퍼. 타이밍과 색 모드 목록의 원천 | `external`, `DisplayWidth`, `DisplayHeight`, `DPTimingModeId`, `TimingElements`(외장 58개), `ColorElements`(외장 37개), `PreferredTimingElements`, `DisplayAttributes`, `Transport`{Upstream, Downstream}, `EDID UUID`, `IOMFBDisplayRefresh`, `QMSVRREnableConfig`, `DCPIndex`, `IONameMatched` |
| `IOPortTransportStateDisplayPort` | 포트별 DisplayPort 전송 상태 | `Active`, `LinkRate`, `LinkRateDescription`, `LaneCount`, `MaxLaneCount`, `NominalSignalingFrequenciesHz`, `HPD_State`, `HPD_StateDescription`, `SinkCount`, `Tunneled`, `EDID`, `EDIDChanged`, `ProductName`, `ManufacturerName`, `ParentPortTypeDescription`, `ParentPortNumber`, `TransportDescription`, `DriverStatusDescription` |
| `IOPortTransportStateCIO` | Thunderbolt/USB4 전송 상태와 케이블 정보 | `CableGeneration`, `CableSpeed`, `Generation`, `LinkTrainingMode`, `AsymmetricModeSupported`, `LegacyAdapter`, `TunneledTransportsSupported`, `TunneledTransportsProvisioned`, `Device Vendor Name`, `Device Model Name`, `TRM_StateDescription` |
| `IOPortTransportStateCC`, `IOPortTransportStateUSB2` | USB-C CC와 USB 전송 상태 | `TransportDescription`, `TransportTypeDescription` |
| `AppleHPMInterfaceType10`, `AppleHPMInterfaceType11` | 포트 컨트롤러 (USB-C, MagSafe) | `TransportsSupported`, `TransportsActive`, `HPDAsserted` |
| `AppleHDMIPortController` | 내장 HDMI 포트 | `HDMI_HPD`, `TransportsSupported`, `TransportsActive` |
| `AppleDPTXController` | DP 송신기 | `LinkRate`, `LaneCount`, `MaxLinkRate`, `MaxLaneCount`, `MinLinkRate`, `SupportsDSC`, `DSCEnabled`, `FECEnabled`, `SupportsFEC`, `VideoStreamEnabled`, `Power`, `AUXTimeoutCount`, `DownstreamPortCount` |
| `AppleT8132TypeCPhy` | USB-C PHY 레인 할당 | `AppleTypeCPhyLane`{Lane 0, Lane 1: Transport, Power Level, Client} |
| `IOThunderboltPort` | Thunderbolt 포트 | `Link Bandwidth`, `Lane`, `Supported Link Modes` |
| `DCPAVServiceProxy`, `DCPDPDeviceProxy` | IOAVService, IODPDevice 생성 대상 | `Location`(External, Embedded), `SinkDeviceID`, `SinkIEEEOUI` |

### 3.1 타이밍 요소와 색 요소 구조

- 타이밍 요소 키: `ID`, `HorizontalAttributes`{Active, Total, FrontPorch, BackPorch, SyncWidth, SyncRate, PreciseSyncRate}, `VerticalAttributes`{동일 구성}, `ColorModes`(해당 타이밍에서 선택 가능한 색 요소 배열), `DSCRequiredColorElementIDs`, `UnsafeColorElementIDs`, `ValidPixelEncodings`, `IsPreferred`, `IsInterlaced`, `IsVirtual`, `IsOverscanned`, `MinimumVariableRefreshRate`, `MaximumVariableRefreshRate`, `StandardType`, `TimingType`, `Score`
- 색 요소 키: `ID`, `PixelEncoding`, `Depth`, `EOTF`, `DynamicRange`, `Colorimetry`, `SupportsDSC`, `IsVirtual`, `Score`, `HDRStaticMetadataTypes`, `Chromaticity`, `WhitePoint`
- 수직 주사율: `VerticalAttributes.PreciseSyncRate` / 65536 (예: 7864320 / 65536 = 120)
- 현재 타이밍 ID 96의 `ColorModes`는 17개. 현재 색 ID 122는 YCbCr 4:2:2, 12 bpc, PQ, Limited
- DSC 제어 근거: 색 요소의 `SupportsDSC`와 타이밍 요소의 `DSCRequiredColorElementIDs`로 모드별 DSC 사용 여부 판별. 실험 기기의 TV는 전 색 요소 `SupportsDSC` = 0으로 DSC 사용 모드 미검증
- `DisplayAttributes` 확인 키: `SupportsPQEOTF`, `SupportsHLGEOTF`, `SupportsHDRStaticMetadataType1`, `SupportsVariableRefreshRate`, `MinimumRefreshRate`, `MaximumRefreshRate`, `MinimumVariableRefreshRate`, `MaximumVariableRefreshRate`, `NativeFormatHorizontalPixels`, `NativeFormatVerticalPixels`, `ProductAttributes`, `Chromaticity`, `HasHDMILegacyEDID`
- 윈도우 서버 설정 파일(`com.apple.windowserver.displays`)의 디스플레이 항목에 `LinkDescription`{BitDepth, EOTF, PixelEncoding, Range} 존재 확인

## 4. 실험 04 결과: 프레임워크 심볼

| 프레임워크 | 확인한 심볼 (macOS 26.5.2) |
| --- | --- |
| SkyLight | `SLSGetNumberOfDisplayModes`, `SLSGetDisplayModeDescriptionOfLength`, `SLSGetCurrentDisplayMode`, `SLSConfigureDisplayMode`, `SLSConfigureDisplayEnabled`, `SLSConfigureDisplayMirrorOfDisplay`, `SLSConfigureDisplayOrigin`, `SLSDisplaySupportsHDRMode`, `SLSDisplayIsHDRModeEnabled`, `SLSDisplaySetHDRModeEnabled`, `SLSSetDisplayRotation`, `SLSDisplayGetUnderscan`, `SLSDisplaySetUnderscan`, `SLSIsDisplayModeVRR`, `SLSIsDisplayModeProMotion`, `SLSGetDisplayModeMinRefreshRate`, `SLSGetDisplayMaximumHDRValue` |
| IOMobileFramebuffer | `IOMobileFramebufferOpen`, `IOMobileFramebufferGetDigitalOutMode`, `IOMobileFramebufferSetDigitalOutMode`, `IOMobileFramebufferGetSupportedDigitalOutModes`, `IOMobileFramebufferGetDigitalOutState`, `IOMobileFramebufferGetLinkQuality`, `IOMobileFramebufferEnableHotPlugDetectNotifications`, `IOMobileFramebufferGetHotPlugRunLoopSource` |
| IOKit (IOAV, IODP 계열) | `IOAVServiceCreateWithService`, `IOAVServiceCopyEDID`, `IOAVServiceReadI2C`, `IOAVServiceWriteI2C`, `IOAVServiceGetLinkData`, `IOAVServiceGetFRLLinkData`, `IOAVVideoInterfaceCopyTimingElements`, `IOAVVideoInterfaceCopyColorElements`, `IODPDeviceCreateWithService`, `IODPDeviceReadDPCD`, `IODPDeviceGetLinkTrainingData`, `IODPDeviceGetSymbolErrorCount`, `IODPServiceGetSinkCount`, 열거형 문자열 함수 일체 |
| CoreDisplay | `CoreDisplay_Display_SetUserBrightness`, `CoreDisplay_Display_GetUserBrightness`, `CoreDisplay_DisplayCreateInfoDictionary`, `CoreDisplay_Display_IsHDRModeEnabled`, `CoreDisplay_Display_SetHDRModeEnabled`, `CoreDisplay_Display_SupportsHDRMode` |
| DisplayServices | `DisplayServicesGetBrightness`, `DisplayServicesSetBrightness`, `DisplayServicesCanChangeBrightness`, `DisplayServicesGetLinearBrightness`, `DisplayServicesSetLinearBrightness` |
| MonitorPanel | `MPDisplay`(메서드 107개: `setOrientation:`, `setPreferHDRModes:`, `setUnderscan:`, `setMirrorMaster:` 등), `MPDisplayMgr`, `MPDisplayMode` |
| CoreGraphics | `CGVirtualDisplay`(`initWithDescriptor:`, `applySettings:`), `CGVirtualDisplayDescriptor`, `CGVirtualDisplaySettings`(`setHiDPI:`, `setModes:`), `CGVirtualDisplayMode`(`initWithWidth:height:refreshRate:`) |

- 디스어셈블로 확인한 시그니처: `IOAVServiceGetLinkData(service, uint32 linkType, void *out /* 0x110 */)`, `IOAVVideoInterfaceGetLinkData(interface, void *out /* 0x100 */)`, `IODPDeviceReadDPCD(device, uint32 address, void *buffer, uint32 length /* 최대 0x1000 */)`, `IODPDeviceGetLinkTrainingData(device, void *out /* 0x98 */)`, `IOAVServiceGetFRLLinkData(service, void *out /* 8 */)`, `IOAVCreateDiagnosticsStringWithLocation(allocator, uint32 location)`

## 5. 미검증 항목

| 항목 | 사유 | 검증 시점 |
| --- | --- | --- |
| 모드 전환 (`SLSConfigureDisplayMode`) | 쓰기 경로. 사용자 화면 상태 변경 | 작업 항목 T04 |
| 색 모드 전환 (`IOMobileFramebufferSetDigitalOutMode`) | 쓰기 경로. 비권한 프로세스 허용 여부 미확인 | 작업 항목 T05 |
| HDR 전환 (`SLSDisplaySetHDRModeEnabled`) | 쓰기 경로 | 작업 항목 T06 |
| DDC 제어 | 실험 기기의 TV가 DDC 미응답. DDC 지원 모니터 필요 | 작업 항목 T09 (사용자 참여) |
| DSC 사용 모드 | 실험 기기의 싱크가 DSC 미지원 | DSC 지원 모니터 확보 시 (사용자 참여) |
| HDMI 직결 링크 정보 (FRL, TMDS) | 실험 구성이 DP 터널링 | HDMI 직결 시 (사용자 참여) |
| 가상 디스플레이 생성 | 쓰기 경로 | 작업 항목 T12 |
| 회전, 미러, 연결 해제 | 쓰기 경로 | 작업 항목 T11 |

## 6. 구현 중 추가 확인 사항

| 시점 | 내용 |
| --- | --- |
| T03 | 독의 DP 경로로 받은 LG TV EDID(384바이트)는 기본 블록, CTA-861 확장, DisplayID 1.2 확장으로 구성. HDMI VSDB와 HF-VSDB 없음. 3840x2160 120 Hz 타이밍은 DisplayID Type I 상세 타이밍에만 존재 (픽셀 클록 1,071.36 MHz, 링크 데이터 실측값과 일치) |
| T03 | EDID 기본 블록 바이트 20은 0xC5: 디지털, 12 bpc, DisplayPort |
| T04 | `MPDisplay`의 `allModes`가 윈도우 서버 모드와 같은 번호 체계로 319개 전체 제공. 모드별 `isUserVisible`(외장 219개), `isNativeMode`(외장 14개), `isDefaultMode`, `isSafeMode` 조회 가능. 공개 API 기본 열거는 HiDPI 변형을 숨겨 시스템 설정 목록 판정 근거로 부적합 |
| T04 | `MPDisplay` 메서드 형식 부호: `setModeNumber:` `i20@0:8i16`, `setOrientation:` `v20@0:8i16`, `setPreferHDRModes:` `v20@0:8B16`, `setUnderscan:` `v20@0:8i16`, `setMirrorMaster:` `v20@0:8B16` |
| T04 | 모드 전환 사고: SkyLight 직접 호출 경로(`SLSConfigureDisplayMode` + `.forSession`)로 LG TV를 120 Hz에서 60 Hz로 바꾼 뒤 TV 미출력. 상세는 ADR-0005. 사고 시점 IORegistry 자료를 `Tests/TBDCoreTests/Fixtures/ioreg_hpd_high_no_link/`에 보관 (HPD High, 싱크 수 0, No Link, 외장 프레임버퍼에 디스플레이 정보 없음) |
| T04 | 복구 시도 결과: `pmset displaysleepnow` 후 깨우기 2회 실패, `SLSConfigureDisplayEnabled(true)`는 `CGCompleteDisplayConfiguration`에서 1001, `IOAVControllerForceHotPlugDetect`는 0 반환 후 변화 없음. 케이블 재연결로 복구 |
| T04 | `SLSGetDisplayList`는 온라인이 아닌 디스플레이 ID도 반환 (사고 중 [1, 2, 3], 온라인 목록은 [1]) |
| T14 | 프로파일 적용 실측(가상 디스플레이를 두 번째 디스플레이로 사용): 저장 뒤 가상 디스플레이를 1280x720과 왼쪽 배치로 바꾸고 적용하자 모드와 배치 2단계 수행으로 1920x1080 HiDPI와 원래 위치 복원. 확인 없이 5초 경과 시 적용 전 구성으로 자동 복귀. 같은 구성에서는 변경 없음 보고 |
| T14 | 적용 단계 순서 결정 근거: 회전 상태에 따라 모드 목록이 달라지고(T04 조사), HDR 전환과 모드 전환 뒤에는 시스템이 색 모드를 다시 선택(T05, T06 실측)하므로 회전, 모드, HDR, 색 모드 순서 |
| T13 | `CGVirtualDisplay` 형식 부호: `initWithDescriptor:` `@24@0:8@16`, `applySettings:` `B24@0:8@16`, `CGVirtualDisplayMode initWithWidth:height:refreshRate:` `@32@0:8I16I20d24`, `CGVirtualDisplaySettings setHiDPI:` `v20@0:8I16`. 서술자의 `name`, `maxPixelsWide`, `maxPixelsHigh`, `sizeInMillimeters`, `vendorID`, `productID`, `serialNum`, `queue`는 키-값 설정 |
| T13 | 가상 디스플레이 생성 실측: 1920x1080 HiDPI 구성에서 모드 약 20개 이상 자동 제공(1920x1080 HiDPI의 백킹 3840x2160 포함). 생성 직후 HiDPI 모드로 맞추는 단계 필요. 객체 해제 시 온라인 목록에서 제거 |
| T13 | 서술자의 `queue`를 메인 큐로 주고 메인 스레드에서 온라인을 기다리면 디스플레이가 나타나지 않음. 전용 큐 사용과 백그라운드 생성으로 해결 |
| T13 | 실행 루프가 돌지 않는 프로세스(테스트)에서 `CGDisplayCopyDisplayMode`가 방금 추가된 디스플레이에 nil 반환. 윈도우 서버의 현재 모드 번호 조회는 정상이라 대체 경로로 사용. 통합 테스트는 서로 영향을 주지 않도록 `swift test --no-parallel`로 직렬 실행(`scripts/test.sh`) |
| T13 | 가상 디스플레이를 두 번째 디스플레이로 써서 배치 실측(T12 항목): 위치 이동과 맞닿는 위치 보정((5000, 300) 요청이 (1512, 300)으로 보정), 미러 설정과 5초 뒤 자동 해제, 메인 지정과 원복, `SLSConfigureDisplayEnabled` 연결 해제와 5초 뒤 자동 재연결 모두 정상 |
| T13 | HiDPI 스케일링(실제 디스플레이를 가상 디스플레이의 미러로 구성)의 실측은 온라인 실제 디스플레이가 내장 1대뿐이라 미실행 |
| T12 | `MPDisplay canChangeOrientation`은 내장 패널에도 참을 반환. 내장 패널 회전은 시스템 설정에 없는 동작이고 displayplacer에 충돌 경고가 있어 회전 대상에서 제외 |
| T12 | `SLSGetDisplayList`는 케이블을 분리한 디스플레이의 ID(2, 3)도 계속 반환. 온라인이 아닌 ID 목록만으로는 논리적 연결 해제와 물리적 분리를 구분할 수 없어, 창 앱의 재연결 목록은 이 앱에서 연결 해제한 디스플레이로 한정 |
| T12 | 마지막 온라인 디스플레이의 연결 해제 요청은 시스템 호출 전에 거부(종료 코드 3) 확인. 회전, 미러, 메인 지정, 위치, 연결 해제와 재연결의 실측은 LG TV 분리 상태라 미실행 |
| T11 | `CBBlueLightClient` 형식 부호: `getBlueLightStatus:` `B24@0:8^{?=BBBi{?={?=ii}{?=ii}}QB}16`, `setEnabled:` `B20@0:8B16`, `setStrength:commit:` `B24@0:8f16B20`, `getStrength:` `B24@0:8^f16`. 상태 구조체는 40바이트: 1번 바이트 켜짐, 4번 일정 모드, 32번 사용 가능 |
| T11 | Night Shift 상태 구조체의 0번 바이트는 Night Shift가 꺼진 상태에서도 참으로 관측. 의미 미확정으로 화면에 표시하지 않음 |
| T11 | `CBTrueToneClient`: `supported`, `available`, `enabled`, `setEnabled:`(모두 BOOL 반환). 내장 패널에서 반전과 복원 정상 |
| T11 | ColorSync: `ColorSyncDeviceCopyDeviceInfo`의 `FactoryProfiles`에서 기본 프로파일 ID와 경로, `ColorSyncDeviceSetCustomProfiles`로 지정, 값에 `kCFNull`을 주면 기본값 복귀. 내장 XDR 패널에서 sRGB 지정과 기본 프로파일 복원 정상. 지정 가능 프로파일 10개(기본 1개와 설치된 RGB 디스플레이 프로파일 9개) |
| T10 | DisplayServices 시그니처(디스어셈블): `DisplayServicesSetBrightness(디스플레이, float)`, `DisplayServicesHasAmbientLightCompensation(디스플레이)`, `DisplayServicesAmbientLightCompensationEnabled(디스플레이, bool *결과)`, `DisplayServicesEnableAmbientLightCompensation(디스플레이, bool)` |
| T10 | 내장 디스플레이 실측: 밝기 설정 후 재조회 오차 0.02 이내, 자동 밝기 반전과 복원 정상. 자동 밝기를 다시 켜면 시스템이 밝기를 새로 계산(72%에서 82%로 변함)하므로 반전 시험은 밝기도 함께 복원 |
| T10 | `DisplayServicesCanChangeBrightness`는 LG TV에도 참을 반환(Phase 0 S6)하므로 시스템 밝기 제어 대상은 내장 패널과 Apple 제조사 ID(0x610)로 한정 |
| T10 | 전달 테이블 실측(M5 내장 패널): `CGSetDisplayTransferByTable`로 디밍 0.8 적용 시 테이블 최댓값이 기준의 0.8배, 항등 값 적용 시 기준 테이블로 복원. 조사 문서의 M5 Pro, M5 Max 색 테이블 오동작 사례는 이 기기(M5)에서 재현되지 않음 |
| T10 | LG TV가 분리된 상태라 DDC 미응답 탐지(TC-DDC-002)와 TV 대상 소프트웨어 디밍 화면 확인은 미실행 |
| T09 | 실제 구성 진단 결과: USB-C 4번 포트 6단계 전부 통과. 발견 항목 3건(YCbCr 4:2:2 출력 주의, 대역폭 한계로 선택 불가한 색 형식 10개, 링크 사용률 99.2%). 수집과 진단 1회 0.8초 이내(프로세스 시작 포함) |
| T09 | 덮개 상태는 `IOPMrootDomain`의 `AppleClamshellState`, 칩 이름은 `machdep.cpu.brand_string`(Apple M5), 모델 식별자는 `hw.model`(Mac17,2) |
| T09 | 창 앱 실행 중 주사율 전환과 자동 복귀 1회에 모드 변경 이벤트 2건 기록 확인 |
| T08 | 포트 컨트롤러 노드: `AppleHPMInterfaceType10` 3개(USB-C 1, 2, 4번), `AppleHPMInterfaceType11` 1개(MagSafe 3), `AppleHDMIPortController` 1개(HDMI 3번). 전송 상태와 부속 노드는 `ParentPortTypeDescription`과 `ParentPortNumber`로 포트에 연결 |
| T08 | 케이블 e-marker(`IOPortTransportComponentCCUSBPDSOPp`)의 `Metadata.VDOs` 4번째 값이 케이블 VDO. 실험 케이블 0x000A6644: 속도 부호 4(USB4 Gen 4), 전류 부호 2(5 A), 전압 부호 3(50 V), EPR 지원. 필드 위치는 USB Power Delivery 규격의 Passive Cable VDO 정의 기준 |
| T08 | `IOPortTransportStateCIO`: 독 Parade Technologies PS9010, `Generation` 3, `CableGeneration` 2, `CableSpeed` 3, 터널 DisplayPort와 PCIe. `Generation`은 USB4 규격 명칭(Gen 3은 40 Gbps)으로 표시하며 `CableGeneration`과 `CableSpeed`의 값 체계는 근거 미확보로 미해석 |
| T08 | 구성 해석: 케이블은 80 Gbps 등급이나 독의 링크는 USB4 Gen 3이고 터널 안의 DP 링크는 HBR3 4레인(유효 25.92 Gbps). DPCD 기준 DP 수신 측은 128b/132b와 DSC 미지원 |
| T07 | 재연결 후에는 외장(독 터널링) 경로에서도 `IODPDeviceReadDPCD` 성공: DPCD 1.4, HBR3 x 4레인, 8b/10b만 지원, DSC 미지원, 4레인 훈련 완료. Phase 0의 0xe00002ca 실패는 일시 상태였으며 실패 허용 설계 유지 |
| T07 | 내장 패널의 링크 훈련 속도 부호는 0x17(6.21 Gbps/레인, 비표준). 4레인 유효 대역폭 19.87 Gbps, 현재 모드 필요 19.31 Gbps |
| T07 | LG TV 3840x2160 120 Hz: 유효 25.92 Gbps, 현재 모드(YCbCr 4:2:2 12 bpc) 25.71 Gbps, 사용률 99.2%. RGB 10 bpc는 32.14 Gbps로 초과. 시스템이 제공하는 색 모드 15개는 전부 유효 대역폭 이내이고 싱크 선언 형식 중 미제공 형식은 전부 초과 (계산과 시스템 목록 일치) |
| T07 | 터널링 구성에서 `AppleDPTXController` 노드는 전원 꺼짐 상태. FEC 상태를 특정할 수 없어 미확인으로 표시 |
| T06 | `SLSDisplaySetHDRModeEnabled`는 인자 2개(x0 디스플레이 ID, x1 켜기 여부), 조회 함수 2종은 인자 1개 (SkyLight 디스어셈블) |
| T06 | HDR 전환 실측: `MPDisplay setPreferHDRModes:` 경로로 LG TV의 HDR 끄기와 켜기 각 2회, 디스플레이 온라인 유지. `SLSDisplayIsHDRModeEnabled`와 `MPDisplay preferHDRModes` 값 일치 |
| T06 | HDR을 끄면 시스템이 3840x2160 120 Hz에서 RGB 4:4:4, 8 bpc, Full, SDR(ID 100)을 자동 선택. HDR을 켜면 YCbCr 4:2:2, 12 bpc, Limited, PQ(ID 122) 선택. HDR을 끈 상태에서 RGB Full과 Limited 간 색 모드 전환과 자동 복귀 정상 |
| T06 | EDR 헤드룸: LG TV 현재 1.00배, 최대 10.00배. 내장 XDR 패널은 HDR 전환 항목 없음(`SLSDisplaySupportsHDRMode` 거짓), 최대 16.00배 |
| T05 | 색 모드 전환 실측: `IOMobileFramebufferSetDigitalOutMode(색 ID, 타이밍 ID)`가 비권한 프로세스에서 0 반환. LG TV를 색 ID 117(YCbCr 4:2:2, 10 bpc, PQ)에서 122(12 bpc)로 전환하자 링크 데이터의 비트 심도가 12로 변경, 6초 뒤 자동 복귀로 10 확인. 디스플레이 온라인 유지 |
| T05 | 재연결 후 색 ID가 122에서 117로 바뀜. 색 모드는 연결마다 시스템이 다시 선택하므로 저장과 복귀는 ID가 아닌 서술(인코딩, 비트 심도, 레인지, EOTF, 색 공간)로 수행 |
| T05 | 3840x2160 120 Hz 타이밍(ID 96)의 선택 가능 색 모드 15개: RGB는 8 bpc SDR(Full, Limited)만, HDR(PQ, HLG)은 YCbCr 4:2:2 10 bpc와 12 bpc만 제공. 가상 형식 2개(ID 1, 2)는 프레임버퍼용이라 선택 목록에서 제외 |
| T05 | 내장 패널의 정밀 주사율은 120.0005 Hz (`PreciseSyncRate` 7864351) |
| T04 | MonitorPanel 경로 실측: 주사율 전환 3회, 해상도 전환 2회(2560x1440 HiDPI, 시스템 설정 목록 밖 1344x756 HiDPI), 창 앱 전환 1회 모두 디스플레이 온라인 유지와 자동 복귀 정상 |
| T16 | DSC 제어 심볼 조사 (`dyld_info -exports`): IOKit에 DSC 계산용 `IOAVDSCCapabilitiesGetMaxSlicesPerLine`, `IOAVDSCModeForPixelEncoding`, `IOAVVideoColorMinimumBitsPerPixelDSC`만 있고 DSC 설정 함수 없음. IOMobileFramebuffer, SkyLight, CoreDisplay, MonitorPanel, DisplayServices에는 DSC 이름의 심볼 없음. 관련 설정 계열로 `IOAVServiceSetVirtualEDIDMode`, `IODPPortSetVirtualEDID`, `IODPPortSetVirtualDPCD`, `IODPControllerSetMaxLinkRate`, `IODPControllerSetMaxLaneCount`, `IODPServiceRetrainLink`, `IOAVServiceSetFRLMaxRate` 존재 확인 (호출 가능 여부는 T17, T20에서 실측) |
| T17 | `IOAVServiceSetVirtualEDIDMode` 역어셈블: `IOConnectCallMethod` 선택자 0x17, 스칼라 입력 1개(둘째 인자, 32비트 모드), 구조체 입력은 셋째 인자 `CFData`의 바이트와 길이(nil이면 길이 0). 공개 소스 avedid.swift는 모드 1을 적용, 0을 해제로 사용하고 호출 뒤 `SLSDetectDisplays`(인자 없음)를 호출. 적용 상태는 재시동 시 소멸한다는 서술. 실제 적용은 외장 디스플레이 분리 상태라 미실행 (TC-EDO-003) |
| T17 | `SLSDetectDisplays` 실행: 내장 디스플레이만 온라인인 상태에서 반환값 0, 디스플레이 목록과 모드 유지 |
| T19 | 시스템 오버라이드 폴더(`/System/Library/Displays/Contents/Resources/Overrides`)의 `scale-resolutions` 항목은 12바이트(폭, 높이, 플래그 0x1) 형식. `/Library/Displays` 폴더는 실험 기기에 없음. 내장 패널 식별값은 제조사 0x610, 제품 0xa05e |
| T20 | 실험 03 (`spikes/03_xdr_probe`): 내장 XDR 패널의 잠재 EDR 헤드룸 16.0. EDR 창 표시와 1.4배 전달 테이블 지정 시 `CGGetDisplayTransferByTable` 최댓값 1.4 유지, 복원 뒤 1.0. `NSScreen`의 헤드룸 값은 프로세스가 화면 정보를 읽은 시점 값이라 적용 중 변화는 별도 프로세스로 측정: 적용 중 6.17배, 해제 약 25초 뒤 1.00배 |
| T24 | `MPDisplay` 프리셋 메서드 형식 부호: `hasPresets` B, `presets` @, `activePreset` @, `defaultPreset` @, `setActivePreset:` B(객체 인자). `MPDisplayPreset`: `presetIndex` Q, `presetName` @, `presetDescription` @, `presetGroup` q, `isValid` B, `isWritable` B. 내장 XDR 패널은 51개 자리 중 11개 사용 가능. P3-600 nits 전환과 복귀 실측 |
| T24 | 레지스트리 조사: `AppleT8132TypeCPhy` 노드 4개의 `AppleTypeCPhyLane`은 연결이 없으면 빈 사전. `AppleHDCPInterface` 노드에 `HDCPCapabilityMask`(2 또는 3)와 `HDCPChannel` 존재, 값의 의미는 미확인. 포트 노드의 `PlugOrientation`은 연결이 없을 때 0. 충전기 미연결 상태의 `AdapterDetails`는 `FamilyCode` 0뿐 |
| T36 | LG TV 재연결 후 읽기 전용 실측: DDC 탐지는 응답 없음(종료 코드 3). DPCD 기준 싱크 HDCP는 1.x 지원으로 읽힘, 다운스프레드 지원. 실기기의 플러그 방향 2, PHY 3 레인 2개 CIO, DP 터널 8.10Gbps/lane (HBR3)로 픽스처와 일치. TV의 잠재 EDR 헤드룸 10.0, 프리셋 없음 |
| T37 | LG TV(독 경유) 실측: `IOAVServiceSetVirtualEDIDMode`는 비권한 프로세스에서 성공. 적용 뒤 `IOAVServiceCopyEDID`가 가상 EDID를 반환하고 시스템이 HDR 미지원으로 인식. 해제 뒤 원본 복귀. 적용과 해제 과정에서 HDR 설정이 꺼짐 |
| T37 | 가상 EDID에 넣은 DisplayID 상세 타이밍(2560x1440 100 Hz, CVT-RB2)이 싱크 타이밍 목록(새 ID 98)과 윈도우 서버 모드 목록에 반영됨 |
| T37 | `IOMobileFramebufferSetDigitalOutMode`에 다른 타이밍 ID(60, 3840x2160 59.94 Hz)를 주면 링크가 그 타이밍으로 전환 (링크 데이터 59.94 Hz, 593.41 MHz). 디스플레이 온라인 유지. 윈도우 서버의 현재 모드 표기는 120 Hz로 남음 |
| T37 | `MPDisplay setOrientation:`으로 LG TV 90도 회전과 복귀 확인. LG TV의 `supportsUnderscan`은 거짓 |
| T38 | LG TV(독 경유)에서 `IOAVServiceReadI2C` 칩 주소 0x50으로 EDID 384바이트 전체 읽기 성공 (오프셋 256의 셋째 블록 포함). 시스템 제공 EDID(`IOAVServiceCopyEDID`)와 전 바이트 일치, 일련번호 바이트 포함. DDC/CI(칩 주소 0x37)는 같은 경로에서 응답 없음 |
| T39 | 창 앱의 메인 스레드에서 `usleep`으로 기다리면 새 가상 디스플레이가 다른 프로세스에는 온라인으로 보여도 앱 안의 온라인 목록에는 나타나지 않음. 메인 스레드에서는 런 루프를 돌리며 기다리도록 수정 뒤 정상 |
| T39 | LG TV 대상 HiDPI 스케일링 2560x1440: 가상 디스플레이(백킹 5120x2880)가 메인, TV가 미러 대상. 스케일링 중 TV 송출은 3840x2160 120 Hz, RGB 4:4:4 8 bpc SDR로 바뀌며 HDR은 꺼짐. 해제 뒤 YCbCr 4:2:2 12 bpc PQ와 HDR 켜짐으로 복귀 |
