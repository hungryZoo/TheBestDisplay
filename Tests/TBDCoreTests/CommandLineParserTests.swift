import Testing
@testable import TBDCore

/// TC-CLI-003: 인자 해석과 종료 코드.
@Suite("TC-CLI-003 명령행 해석")
struct CommandLineParserTests {
    let parser = CommandLineParser(specs: [
        CommandSpec(name: "list", summary: "목록"),
        CommandSpec(name: "info", summary: "정보", positionals: ["디스플레이"], valueOptions: ["--edid-out"]),
        CommandSpec(name: "ddc", summary: "DDC", positionals: ["디스플레이", "동작", "값"], optionalPositionals: 1),
    ])

    @Test func 정상_명령_해석() throws {
        let cmd = try parser.parse(["info", "external", "--json", "--edid-out", "/tmp/e.bin"])
        #expect(cmd.name == "info")
        #expect(cmd.positionals == ["external"])
        #expect(cmd.has("--json"))
        #expect(cmd.options["--edid-out"] == "/tmp/e.bin")
    }

    @Test func 생략_가능_위치_인자() throws {
        #expect(try parser.parse(["ddc", "1", "probe"]).positionals == ["1", "probe"])
        #expect(try parser.parse(["ddc", "1", "set", "50"]).positionals == ["1", "set", "50"])
    }

    @Test func 옵션_종료_표시_뒤는_위치_인자() throws {
        let cmd = try parser.parse(["info", "--", "--json"])
        #expect(cmd.positionals == ["--json"])
        #expect(!cmd.has("--json"))
    }

    @Test func 사용법_오류는_종료_코드_2() {
        let cases: [([String], CommandLineError)] = [
            ([], .noCommand),
            (["nope"], .unknownCommand("nope")),
            (["list", "--bogus"], .unknownOption(command: "list", option: "--bogus")),
            (["info"], .missingArgument(command: "info", argument: "디스플레이")),
            (["info", "1", "--edid-out"], .missingOptionValue(command: "info", option: "--edid-out")),
            (["list", "extra"], .tooManyArguments(command: "list")),
        ]
        for (args, expected) in cases {
            #expect(throws: expected) { try parser.parse(args) }
            #expect(expected.exitCode == .usage)
            #expect(expected.exitCode.rawValue == 2)
        }
    }

    @Test func 종료_코드_값() {
        #expect(ExitCode.success.rawValue == 0)
        #expect(ExitCode.failure.rawValue == 1)
        #expect(ExitCode.usage.rawValue == 2)
        #expect(ExitCode.unsupported.rawValue == 3)
    }

    @Test func 사용법_문구에_전_명령_포함() {
        for name in ["list", "info", "ddc"] {
            #expect(parser.usage.contains(name))
        }
        #expect(parser.specs[2].usageLine == "tbdctl ddc <디스플레이> <동작> [값]")
    }
}

/// TC-CLI-003: 디스플레이 지정자 해석. 대상 없음은 종료 코드 3.
@Suite("TC-CLI-003 디스플레이 지정자")
struct DisplaySelectorTests {
    static func display(_ id: UInt32, _ name: String, builtin: Bool = false, main: Bool = false) -> DisplaySummary {
        DisplaySummary(
            identity: DisplayIdentity(displayID: id, uuid: nil, vendorID: 1, productID: 2, serialNumber: 3, name: name, isBuiltin: builtin),
            isMain: main, isActive: true, mirrorsDisplayID: nil,
            pointWidth: 1920, pointHeight: 1080, pixelWidth: 3840, pixelHeight: 2160,
            refreshRate: 60, rotationDegrees: 0, originX: 0, originY: 0, physicalWidthMM: 600, physicalHeightMM: 340
        )
    }

    let displays = [
        display(2, "LG TV SSCR2", main: true),
        display(1, "내장 Retina 디스플레이", builtin: true),
        display(5, "LG UltraFine"),
    ]

    @Test func 순번_ID_역할_이름으로_선택() throws {
        #expect(try DisplaySelector.resolve("1", in: displays).id == 2)
        #expect(try DisplaySelector.resolve("3", in: displays).id == 5)
        #expect(try DisplaySelector.resolve("id:1", in: displays).id == 1)
        #expect(try DisplaySelector.resolve("main", in: displays).id == 2)
        #expect(try DisplaySelector.resolve("builtin", in: displays).id == 1)
        #expect(try DisplaySelector.resolve("ultrafine", in: displays).id == 5)
    }

    @Test func 없는_대상은_종료_코드_3() {
        for selector in ["0", "4", "id:99", "dell"] {
            #expect(throws: DisplaySelector.SelectionError.notFound(selector)) {
                try DisplaySelector.resolve(selector, in: displays)
            }
        }
        #expect(DisplaySelector.SelectionError.notFound("x").exitCode.rawValue == 3)
        #expect(throws: DisplaySelector.SelectionError.notFound("main")) {
            try DisplaySelector.resolve("main", in: [])
        }
    }

    @Test func 여러_대에_해당하면_거부() {
        #expect(throws: DisplaySelector.SelectionError.ambiguous("lg", matches: ["LG TV SSCR2", "LG UltraFine"])) {
            try DisplaySelector.resolve("lg", in: displays)
        }
        #expect(throws: DisplaySelector.SelectionError.ambiguous("external", matches: ["LG TV SSCR2", "LG UltraFine"])) {
            try DisplaySelector.resolve("external", in: displays)
        }
    }
}

@Suite("디스플레이 요약 계산")
struct DisplaySummaryTests {
    @Test func 배율과_표시_문구() {
        let d = DisplaySelectorTests.display(2, "TV")
        #expect(d.scale == 2)
        #expect(d.isHiDPI)
        #expect(d.modeDescription == "1920 x 1080 HiDPI, 60 Hz")
        #expect(DisplaySummary.formatHz(59.94) == "59.94")
        #expect(DisplaySummary.formatHz(120) == "120")
    }

    @Test func 물리_크기_계산() throws {
        let d = DisplaySelectorTests.display(2, "TV")
        let inches = try #require(d.diagonalInches)
        #expect(abs(inches - 27.15) < 0.05)
        let ppi = try #require(d.pixelsPerInch)
        #expect(abs(ppi - 162.56) < 0.05)
        var unknown = d
        unknown.physicalWidthMM = 0
        #expect(unknown.diagonalInches == nil)
        #expect(unknown.pixelsPerInch == nil)
    }
}
