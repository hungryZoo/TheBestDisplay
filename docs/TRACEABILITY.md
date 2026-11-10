# 요구사항 추적성 표

- 생성: `uv run scripts/trace_check.py` (수동 편집 금지, 원본은 MRD, PRD, SRS, TC 문서 표)
- 연결 구조: MRD -> PRD -> SRS -> TC -> 구현 위치 -> 테스트 결과

## 1. 요약

| 항목 | 값 |
| --- | --- |
| MRD 항목 | 52 |
| PRD 요구사항 | 66 |
| SRS 설계 요구사항 | 42 |
| TC | 53 |
| 오류 (누락, 불일치) | 0 |
| 경고 (TC 미연결 SRS) | 0 |

## 2. 검사 결과

- 오류와 경고 없음

## 3. PRD 기준 추적성

| PRD | 단계 | 우선순위 | MRD | SRS | TC | 구현 위치 | TC 결과 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| PRD-APP-001 | P1 | 필수 | MRD-SCP-001, MRD-DIF-001 | SRS-ARC-001, SRS-ARC-003, SRS-UI-002 | TC-APP-001 | `Package.swift`<br>`Sources/TBDApp/TheBestDisplayApp.swift`<br>`scripts/build_app.sh` | 통과 1 |
| PRD-APP-002 | P1 | 필수 | MRD-SCP-001 | SRS-UI-001 | TC-APP-002 | `Sources/TBDApp/Views/` | 통과 1 |
| PRD-APP-003 | P1 | 필수 | MRD-SCP-001, MRD-PRB-005 | SRS-UI-001 | TC-APP-002 | `Sources/TBDApp/Views/` | 통과 1 |
| PRD-APP-004 | P1 | 필수 | MRD-SCP-001 | SRS-ARC-004 | TC-APP-003 | `Sources/TBDApp/DisplayStore.swift` | 미실행 1 |
| PRD-APP-005 | P1 | 필수 | MRD-RSK-001, MRD-RSK-003 | SRS-ARC-002 | TC-APP-004 | `Sources/TBDPlatform/PrivateSymbols.swift` | 통과 1 |
| PRD-INF-001 | P1 | 필수 | MRD-SCP-002 | SRS-INF-001 | TC-INF-001 | `Sources/TBDPlatform/DisplayCatalog.swift` | 통과 1 |
| PRD-INF-002 | P1 | 필수 | MRD-SCP-002 | SRS-INF-002 | TC-INF-002, TC-INF-003 | `Sources/TBDCore/EDID/` | 통과 2 |
| PRD-INF-003 | P1 | 권장 | MRD-SCP-002, MRD-SCN-007 | SRS-INF-003 | TC-INF-005 | `Sources/TBDPlatform/EDIDSource.swift` | 통과 1 |
| PRD-INF-004 | P1 | 필수 | MRD-SCP-002, MRD-PRB-002 | SRS-INF-002 | TC-INF-003 | `Sources/TBDCore/EDID/` | 통과 1 |
| PRD-MOD-001 | P2 | 필수 | MRD-SCP-003, MRD-PRB-001 | SRS-MOD-001 | TC-MOD-001 | `Sources/TBDPlatform/ModeService.swift` | 미실행 1 |
| PRD-MOD-002 | P2 | 권장 | MRD-SCP-003 | SRS-MOD-003 | TC-MOD-002 | `Sources/TBDCore/ModeCatalog.swift` | 미실행 1 |
| PRD-MOD-003 | P2 | 필수 | MRD-SCP-003, MRD-KPI-001 | SRS-MOD-002 | TC-MOD-003 | `Sources/TBDPlatform/ModeService.swift` | 미실행 1 |
| PRD-MOD-004 | P2 | 필수 | MRD-SCP-003 | SRS-MOD-001 | TC-MOD-001 | `Sources/TBDPlatform/ModeService.swift` | 미실행 1 |
| PRD-MOD-005 | P2 | 필수 | MRD-SCP-003 | SRS-MOD-002 | TC-MOD-004 | `Sources/TBDPlatform/ModeService.swift` | 미실행 1 |
| PRD-MOD-006 | P2 | 권장 | MRD-PRB-001 | SRS-MOD-003 | TC-MOD-002 | `Sources/TBDCore/ModeCatalog.swift` | 미실행 1 |
| PRD-COL-001 | P2 | 필수 | MRD-SCP-004, MRD-PRB-002, MRD-KPI-002 | SRS-COL-002 | TC-COL-002 | `Sources/TBDPlatform/SignalService.swift` | 미실행 1 |
| PRD-COL-002 | P2 | 필수 | MRD-SCP-004 | SRS-COL-001 | TC-COL-001 | `Sources/TBDCore/SignalDecoder.swift` | 미실행 1 |
| PRD-COL-003 | P2 | 필수 | MRD-SCP-004, MRD-SCN-001 | SRS-COL-003 | TC-COL-004 | `Sources/TBDPlatform/SignalService.swift` | 미실행 1 |
| PRD-COL-004 | P2 | 필수 | MRD-SCP-004 | SRS-COL-004 | TC-COL-005 | `Sources/TBDCore/DSCAssessment.swift` | 미실행 1 |
| PRD-COL-005 | P2 | 권장 | MRD-SCP-004 | SRS-COL-001 | TC-COL-001 | `Sources/TBDCore/SignalDecoder.swift` | 미실행 1 |
| PRD-HDR-001 | P2 | 필수 | MRD-SCP-005 | SRS-HDR-001 | TC-HDR-001 | `Sources/TBDPlatform/HDRService.swift` | 미실행 1 |
| PRD-HDR-002 | P2 | 필수 | MRD-SCP-005 | SRS-HDR-001 | TC-HDR-002 | `Sources/TBDPlatform/HDRService.swift` | 미실행 1 |
| PRD-HDR-003 | P2 | 권장 | MRD-SCP-005 | SRS-HDR-001 | TC-HDR-001 | `Sources/TBDPlatform/HDRService.swift` | 미실행 1 |
| PRD-LNK-001 | P3 | 필수 | MRD-SCP-006, MRD-PRB-003, MRD-KPI-002 | SRS-LNK-001 | TC-LNK-001 | `Sources/TBDPlatform/LinkService.swift` | 미실행 1 |
| PRD-LNK-002 | P3 | 필수 | MRD-SCP-006, MRD-DIF-002 | SRS-LNK-002 | TC-LNK-002 | `Sources/TBDCore/BandwidthCalculator.swift` | 미실행 1 |
| PRD-LNK-003 | P3 | 필수 | MRD-SCP-006 | SRS-COL-004 | TC-COL-005 | `Sources/TBDCore/DSCAssessment.swift` | 미실행 1 |
| PRD-LNK-004 | P3 | 권장 | MRD-SCP-006 | SRS-LNK-003 | TC-LNK-003 | `Sources/TBDPlatform/LinkService.swift` | 미실행 1 |
| PRD-LNK-005 | P3 | 권장 | MRD-SCP-006, MRD-RSK-005 | SRS-LNK-004 | TC-LNK-004 | `Sources/TBDPlatform/DPCDReader.swift`<br>`Sources/TBDCore/DPCDDecoder.swift` | 미실행 1 |
| PRD-PRT-001 | P3 | 필수 | MRD-SCP-007 | SRS-PRT-001 | TC-PRT-001 | `Sources/TBDPlatform/PortService.swift` | 미실행 1 |
| PRD-PRT-002 | P3 | 필수 | MRD-SCP-007 | SRS-PRT-001 | TC-PRT-001 | `Sources/TBDPlatform/PortService.swift` | 미실행 1 |
| PRD-PRT-003 | P3 | 필수 | MRD-SCP-007, MRD-DIF-003 | SRS-PRT-002 | TC-PRT-002 | `Sources/TBDCore/ConnectionPath.swift` | 미실행 1 |
| PRD-DGN-001 | P3 | 필수 | MRD-SCP-008, MRD-PRB-004, MRD-SCN-002 | SRS-DGN-001 | TC-DGN-001 | `Sources/TBDCore/Diagnostics/` | 미실행 1 |
| PRD-DGN-002 | P3 | 필수 | MRD-SCP-008, MRD-DIF-002, MRD-KPI-003 | SRS-LNK-002, SRS-DGN-001 | TC-DGN-002 | `Sources/TBDCore/BandwidthCalculator.swift`<br>`Sources/TBDCore/Diagnostics/` | 미실행 1 |
| PRD-DGN-003 | P3 | 필수 | MRD-SCP-008 | SRS-DGN-001 | TC-DGN-001, TC-DGN-002 | `Sources/TBDCore/Diagnostics/` | 미실행 2 |
| PRD-DGN-004 | P3 | 필수 | MRD-SCP-008 | SRS-DGN-002 | TC-DGN-004 | `Sources/TBDPlatform/EventMonitor.swift` | 미실행 1 |
| PRD-DGN-005 | P3 | 필수 | MRD-SCP-008, MRD-SCN-007 | SRS-DGN-003 | TC-DGN-005 | `Sources/TBDCore/ReportExporter.swift` | 미실행 1 |
| PRD-DGN-006 | P3 | 권장 | MRD-SCP-008 | SRS-DGN-001 | TC-DGN-003 | `Sources/TBDCore/Diagnostics/` | 미실행 1 |
| PRD-BRT-001 | P4 | 필수 | MRD-SCP-009 | SRS-BRT-001 | TC-BRT-001 | `Sources/TBDPlatform/BrightnessService.swift` | 미실행 1 |
| PRD-BRT-002 | P4 | 필수 | MRD-SCP-009, MRD-SCN-005 | SRS-DDC-001 | TC-DDC-003 | `Sources/TBDPlatform/DDCService.swift`<br>`Sources/TBDCore/DDCPacket.swift` | 미실행 1 |
| PRD-BRT-003 | P4 | 필수 | MRD-SCP-009 | SRS-BRT-001, SRS-CLR-001 | TC-BRT-002 | `Sources/TBDPlatform/BrightnessService.swift`<br>`Sources/TBDPlatform/GammaService.swift`<br>`Sources/TBDCore/GammaTable.swift` | 미실행 1 |
| PRD-BRT-004 | P4 | 권장 | MRD-SCP-009 | SRS-BRT-001 | TC-BRT-003 | `Sources/TBDPlatform/BrightnessService.swift` | 미실행 1 |
| PRD-DDC-001 | P4 | 필수 | MRD-SCP-009 | SRS-DDC-001 | TC-DDC-002 | `Sources/TBDPlatform/DDCService.swift`<br>`Sources/TBDCore/DDCPacket.swift` | 미실행 1 |
| PRD-DDC-002 | P4 | 필수 | MRD-SCP-009, MRD-SCN-005 | SRS-DDC-001 | TC-DDC-003 | `Sources/TBDPlatform/DDCService.swift`<br>`Sources/TBDCore/DDCPacket.swift` | 미실행 1 |
| PRD-DDC-003 | P4 | 권장 | MRD-SCP-009 | SRS-DDC-001 | TC-DDC-001 | `Sources/TBDPlatform/DDCService.swift`<br>`Sources/TBDCore/DDCPacket.swift` | 미실행 1 |
| PRD-CLR-001 | P4 | 필수 | MRD-SCP-010 | SRS-CLR-002 | TC-CLR-001 | `Sources/TBDPlatform/ColorProfileService.swift` | 미실행 1 |
| PRD-CLR-002 | P4 | 필수 | MRD-SCP-010 | SRS-CLR-001 | TC-BRT-002 | `Sources/TBDPlatform/GammaService.swift`<br>`Sources/TBDCore/GammaTable.swift` | 미실행 1 |
| PRD-CLR-003 | P4 | 권장 | MRD-SCP-010 | SRS-CLR-003 | TC-CLR-002 | `Sources/TBDPlatform/NightShiftService.swift` | 미실행 1 |
| PRD-CLR-004 | P4 | 권장 | MRD-SCP-010 | SRS-CLR-003 | TC-CLR-002 | `Sources/TBDPlatform/NightShiftService.swift` | 미실행 1 |
| PRD-ARR-001 | P4 | 필수 | MRD-SCP-011 | SRS-ARR-002 | TC-ARR-001 | `Sources/TBDPlatform/ArrangementService.swift` | 미실행 1 |
| PRD-ARR-002 | P4 | 필수 | MRD-SCP-011 | SRS-ARR-001 | TC-ARR-002 | `Sources/TBDPlatform/ArrangementService.swift` | 미실행 1 |
| PRD-ARR-003 | P4 | 필수 | MRD-SCP-011 | SRS-ARR-001 | TC-ARR-003 | `Sources/TBDPlatform/ArrangementService.swift` | 미실행 1 |
| PRD-ARR-004 | P4 | 필수 | MRD-SCP-011 | SRS-ARR-001 | TC-ARR-003 | `Sources/TBDPlatform/ArrangementService.swift` | 미실행 1 |
| PRD-ARR-005 | P4 | 필수 | MRD-SCP-011 | SRS-ARR-003 | TC-ARR-004 | `Sources/TBDPlatform/ArrangementService.swift` | 미실행 1 |
| PRD-ARR-006 | P4 | 권장 | MRD-SCP-011 | SRS-ARR-004 | TC-ARR-005 | `Sources/TBDPlatform/ArrangementService.swift` | 미실행 1 |
| PRD-VRT-001 | P5 | 필수 | MRD-SCP-012 | SRS-VRT-001 | TC-VRT-001 | `Sources/TBDPlatform/VirtualDisplayService.swift` | 미실행 1 |
| PRD-VRT-002 | P5 | 필수 | MRD-SCP-012, MRD-SCN-003 | SRS-VRT-002 | TC-VRT-002 | `Sources/TBDPlatform/VirtualDisplayService.swift` | 미실행 1 |
| PRD-VRT-003 | P5 | 권장 | MRD-SCP-012 | SRS-VRT-001 | TC-VRT-001 | `Sources/TBDPlatform/VirtualDisplayService.swift` | 미실행 1 |
| PRD-PRF-001 | P5 | 필수 | MRD-SCP-013, MRD-SCN-006 | SRS-PRF-001 | TC-PRF-001 | `Sources/TBDCore/Profile.swift` | 미실행 1 |
| PRD-PRF-002 | P5 | 필수 | MRD-SCP-013 | SRS-PRF-002 | TC-PRF-002 | `Sources/TBDPlatform/ProfileApplier.swift` | 미실행 1 |
| PRD-PRF-003 | P5 | 필수 | MRD-SCP-013 | SRS-INF-001, SRS-PRF-001 | TC-PRF-001 | `Sources/TBDCore/Profile.swift`<br>`Sources/TBDPlatform/DisplayCatalog.swift` | 미실행 1 |
| PRD-SAF-001 | P2 | 필수 | MRD-SCP-014, MRD-DIF-004, MRD-RSK-002, MRD-SCN-004 | SRS-SAF-001 | TC-MOD-003, TC-COL-004, TC-HDR-002, TC-SAF-001 | `Sources/TBDCore/RevertGuard.swift` | 미실행 4 |
| PRD-SAF-002 | P2 | 권장 | MRD-SCP-014 | SRS-SAF-002 | TC-SAF-002 | `Sources/TBDPlatform/PendingRevertStore.swift` | 미실행 1 |
| PRD-SAF-003 | P4 | 필수 | MRD-SCP-014 | SRS-ARR-003 | TC-ARR-004 | `Sources/TBDPlatform/ArrangementService.swift` | 미실행 1 |
| PRD-CLI-001 | P1 | 필수 | MRD-SCP-015, MRD-USR-003 | SRS-CLI-001 | TC-CLI-001 | `Sources/tbdctl/`<br>`Sources/TBDCore/CommandLineParser.swift` | 미실행 1 |
| PRD-CLI-002 | P2 | 권장 | MRD-SCP-015, MRD-USR-003 | SRS-CLI-001 | TC-CLI-002 | `Sources/tbdctl/`<br>`Sources/TBDCore/CommandLineParser.swift` | 미실행 1 |
| PRD-CLI-003 | P1 | 필수 | MRD-SCP-015 | SRS-CLI-001 | TC-CLI-003 | `Sources/tbdctl/`<br>`Sources/TBDCore/CommandLineParser.swift` | 통과 1 |
