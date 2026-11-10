import Foundation
import Testing
import TBDCore
@testable import TBDPlatform

/// 빌드된 tbdctl 실행 보조. 패키지 루트의 디버그 산출물 사용.
enum CLI {
    static let binary: URL = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(".build/debug/tbdctl")

    static func run(_ arguments: [String]) throws -> (status: Int32, stdout: Data, stderr: String) {
        let process = Process()
        process.executableURL = binary
        process.arguments = arguments
        let out = Pipe(), err = Pipe()
        process.standardOutput = out
        process.standardError = err
        process.standardInput = FileHandle.nullDevice
        try process.run()
        let stdout = out.fileHandleForReading.readDataToEndOfFile()
        let stderr = String(decoding: err.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        process.waitUntilExit()
        return (process.terminationStatus, stdout, stderr)
    }
}

/// TC-CLI-001: 조회 명령. 읽기 전용.
@Suite("TC-CLI-001 조회 명령")
struct CLIReadCommandTests {
    @Test func 전_조회_명령이_종료_코드_0과_유효한_JSON() throws {
        try #require(FileManager.default.isExecutableFile(atPath: CLI.binary.path), "tbdctl 미빌드: swift build 후 실행")
        let commands: [[String]] = [
            ["list"], ["capabilities"], ["info", "main"], ["modes", "main"], ["signal", "main"], ["link", "main"], ["hdr", "main"], ["ports"], ["diagnose"],
        ]
        for command in commands {
            let result = try CLI.run(command + ["--json"])
            #expect(result.status == 0, "\(command): \(result.stderr)")
            #expect((try? JSONSerialization.jsonObject(with: result.stdout)) != nil, "\(command): JSON 아님")
            // 사람이 읽는 출력도 종료 코드 0.
            #expect(try CLI.run(command).status == 0, "\(command)")
        }
    }

    @Test func 보고서_저장() throws {
        try #require(FileManager.default.isExecutableFile(atPath: CLI.binary.path))
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("tbd-cli-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let json = dir.appendingPathComponent("report.json")
        #expect(try CLI.run(["report", json.path, "--redact"]).status == 0)
        let report = try ReportExporter.decode(Data(contentsOf: json))
        #expect(report.redacted)
        #expect(report.snapshot.displays.count == DisplayCatalog.onlineDisplayIDs().count)
        #expect(report.snapshot.displays.allSatisfy { $0.summary.identity.serialNumber == 0 })
        let text = dir.appendingPathComponent("report.txt")
        #expect(try CLI.run(["report", text.path, "--text"]).status == 0)
        #expect(String(decoding: try Data(contentsOf: text), as: UTF8.self).contains("[포트 점검]"))
    }

    @Test func 사용법_오류와_대상_없음의_종료_코드() throws {
        try #require(FileManager.default.isExecutableFile(atPath: CLI.binary.path))
        #expect(try CLI.run(["없는명령"]).status == 2)
        #expect(try CLI.run(["info"]).status == 2)
        #expect(try CLI.run(["list", "--없는옵션"]).status == 2)
        #expect(try CLI.run(["info", "없는디스플레이"]).status == 3)
        #expect(try CLI.run(["set-mode", "main", "1x1"]).status == 3)
        #expect(try CLI.run(["set-mode", "main", "잘못된형식"]).status == 2)
        #expect(try CLI.run(["set-color", "main", "rgb:99"]).status == 2)
    }
}

/// TC-DGN-001 실측: 현재 연결 구성의 진단.
@Suite("TC-DGN-001 실제 구성 진단")
struct LiveDiagnosisTests {
    @Test func 온라인_외장_디스플레이의_포트는_전_단계_통과() throws {
        let snapshot = SnapshotBuilder.build()
        let result = DiagnosticEngine.evaluate(snapshot)
        #expect(snapshot.system.chipName.hasPrefix("Apple"))
        #expect(!snapshot.system.osVersion.isEmpty)
        for display in snapshot.displays where !display.summary.identity.isBuiltin {
            let path = try #require(snapshot.paths.first { $0.displayID == display.id }, "경로 없음: \(display.summary.identity.name)")
            let diagnosis = try #require(result.portDiagnoses.first { $0.port == path.port.key })
            #expect(diagnosis.isFullyPassed, "\(diagnosis.checks)")
        }
        // 온라인 디스플레이가 있는 포트에는 오류 등급 발견 항목 없음.
        let healthyPorts = Set(snapshot.paths.filter(\.reachesDisplay).map(\.port.key.label))
        #expect(!result.findings.contains { $0.severity == .error && healthyPorts.contains($0.subject ?? "") })
        for finding in result.findings {
            #expect(!finding.remedy.isEmpty)
        }
    }
}

/// TC-PRT-008: 충전 진단 출력. 읽기 전용.
@Suite("TC-PRT-008 충전 진단 출력")
struct ChargingDiagnosisTests {
    @Test func 포트_명령의_충전_진단() throws {
        try #require(FileManager.default.isExecutableFile(atPath: CLI.binary.path), "tbdctl 미빌드: swift build 후 실행")
        let result = try CLI.run(["ports", "--json"])
        #expect(result.status == 0)
        let root = try #require(JSONSerialization.jsonObject(with: result.stdout) as? [String: Any])
        let findings = try #require(root["chargingFindings"] as? [[String: Any]])
        let adapter = (root["inventory"] as? [String: Any])?["powerAdapter"] as? [String: Any]
        guard adapter?["isConnected"] as? Bool == true else {
            // 전원 미연결: 미연결 항목 1건 또는 배터리 없는 기기의 빈 목록.
            #expect(findings.allSatisfy { $0["code"] as? String == "CHG.NOT_CONNECTED" })
            return
        }
        // 전원 연결: 공급 전력 상한 판정 1건 포함, 충전 수치 포함.
        let codes = findings.compactMap { $0["code"] as? String }
        #expect(codes.contains("CHG.SOURCE_LIMIT") != codes.contains("CHG.CABLE_LIMIT"))
        #expect(root["charging"] is [String: Any])
        let text = String(decoding: try CLI.run(["ports"]).stdout, as: UTF8.self)
        #expect(text.contains("충전 진단"))
    }

    @Test func 서비스_판정은_어댑터_정보와_일치() {
        let inventory = PortService.inventory()
        let findings = PortService.chargingFindings(inventory: inventory)
        if inventory.powerAdapter?.isConnected == true {
            #expect(!findings.isEmpty)
        } else {
            #expect(findings.allSatisfy { $0.code == "CHG.NOT_CONNECTED" })
        }
    }
}
