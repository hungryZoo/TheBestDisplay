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
| T06 | `SLSDisplaySetHDRModeEnabled`는 인자 2개(x0 디스플레이 ID, x1 켜기 여부), 조회 함수 2종은 인자 1개 (SkyLight 디스어셈블) |
| T06 | HDR 전환 실측: `MPDisplay setPreferHDRModes:` 경로로 LG TV의 HDR 끄기와 켜기 각 2회, 디스플레이 온라인 유지. `SLSDisplayIsHDRModeEnabled`와 `MPDisplay preferHDRModes` 값 일치 |
| T06 | HDR을 끄면 시스템이 3840x2160 120 Hz에서 RGB 4:4:4, 8 bpc, Full, SDR(ID 100)을 자동 선택. HDR을 켜면 YCbCr 4:2:2, 12 bpc, Limited, PQ(ID 122) 선택. HDR을 끈 상태에서 RGB Full과 Limited 간 색 모드 전환과 자동 복귀 정상 |
| T06 | EDR 헤드룸: LG TV 현재 1.00배, 최대 10.00배. 내장 XDR 패널은 HDR 전환 항목 없음(`SLSDisplaySupportsHDRMode` 거짓), 최대 16.00배 |
| T05 | 색 모드 전환 실측: `IOMobileFramebufferSetDigitalOutMode(색 ID, 타이밍 ID)`가 비권한 프로세스에서 0 반환. LG TV를 색 ID 117(YCbCr 4:2:2, 10 bpc, PQ)에서 122(12 bpc)로 전환하자 링크 데이터의 비트 심도가 12로 변경, 6초 뒤 자동 복귀로 10 확인. 디스플레이 온라인 유지 |
| T05 | 재연결 후 색 ID가 122에서 117로 바뀜. 색 모드는 연결마다 시스템이 다시 선택하므로 저장과 복귀는 ID가 아닌 서술(인코딩, 비트 심도, 레인지, EOTF, 색 공간)로 수행 |
| T05 | 3840x2160 120 Hz 타이밍(ID 96)의 선택 가능 색 모드 15개: RGB는 8 bpc SDR(Full, Limited)만, HDR(PQ, HLG)은 YCbCr 4:2:2 10 bpc와 12 bpc만 제공. 가상 형식 2개(ID 1, 2)는 프레임버퍼용이라 선택 목록에서 제외 |
| T05 | 내장 패널의 정밀 주사율은 120.0005 Hz (`PreciseSyncRate` 7864351) |
| T04 | MonitorPanel 경로 실측: 주사율 전환 3회, 해상도 전환 2회(2560x1440 HiDPI, 시스템 설정 목록 밖 1344x756 HiDPI), 창 앱 전환 1회 모두 디스플레이 온라인 유지와 자동 복귀 정상 |
