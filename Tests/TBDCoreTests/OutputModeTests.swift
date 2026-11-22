import Foundation
import Testing
@testable import TBDCore

/// TC-COL-013: 출력 모드(링크 서술) 해석과 색 모드 대응.
@Suite("TC-COL-013 출력 모드 해석과 색 모드 대응")
struct OutputModeTests {
    /// LG TV 4K 120 Hz, HDR 켜짐 상태의 목록 (T73 실측).
    static let tvBytes: [UInt8] = [
        0x0c, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 2, 0, 0, 0,
        0x0a, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 2, 0, 0, 0,
        0x08, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0x08, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0x08, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0,
    ]

    static var tvList: OutputModeList {
        OutputModeList(modes: LinkDescription.decodeList(tvBytes, count: 5), currentIndex: 1)
    }

    @Test func 목록_해석() {
        let list = Self.tvList
        #expect(list.modes.count == 5)
        #expect(list.modes[0] == LinkDescription(bitDepth: 12, range: 0, eotf: 2, pixelEncoding: 2))
        #expect(list.modes.map(\.label) == [
            "YCbCr 4:2:2, 12 bpc, Limited, PQ (HDR10)",
            "YCbCr 4:2:2, 10 bpc, Limited, PQ (HDR10)",
            "RGB 4:4:4, 8 bpc, Full, SDR",
            "RGB 4:4:4, 8 bpc, Limited, SDR",
            "YCbCr 4:4:4, 8 bpc, Limited, SDR",
        ])
        #expect(list.current?.bitDepth == 10)
    }

    @Test func 길이_부족과_범위_밖_현재_위치() {
        #expect(LinkDescription.decode([UInt8](repeating: 0, count: 15)) == nil)
        #expect(LinkDescription.decodeList(Self.tvBytes, count: 6).count == 5)
        #expect(LinkDescription.decodeList(Self.tvBytes, count: -1).isEmpty)
        #expect(OutputModeList(modes: LinkDescription.decodeList(Self.tvBytes, count: 5), currentIndex: 5).currentIndex == nil)
    }

    @Test func 레지스터_값() {
        let registers = LinkDescription(bitDepth: 10, range: 1, eotf: 2, pixelEncoding: 3).registers
        #expect(registers.first == 0x0000_0001_0000_000A)
        #expect(registers.second == 0x0000_0003_0000_0002)
    }

    @Test func 색_모드_서술과의_대응() {
        // 픽셀 인코딩과 범위의 번호가 프레임버퍼 색 요소와 다름: 4:4:4는 1 대 3, Full은 1 대 0.
        let ycbcr444 = ColorDescriptor(pixelEncoding: .ycbcr444, bitsPerComponent: 8, eotf: .sdr, dynamicRange: .limited, colorimetry: 1)
        #expect(LinkDescription(ycbcr444) == LinkDescription(bitDepth: 8, range: 0, eotf: 0, pixelEncoding: 1))
        let rgbFull = ColorDescriptor(pixelEncoding: .rgb444, bitsPerComponent: 8, eotf: .sdr, dynamicRange: .full)
        #expect(LinkDescription(rgbFull) == LinkDescription(bitDepth: 8, range: 1, eotf: 0, pixelEncoding: 0))
        #expect(LinkDescription(bitDepth: 10, range: 0, eotf: 2, pixelEncoding: 3).colorDescriptor == ColorDescriptor(pixelEncoding: .ycbcr420, bitsPerComponent: 10, eotf: .pq, dynamicRange: .limited))
        // 터널링과 Dolby Vision 계열은 대응 없음.
        #expect(LinkDescription(ColorDescriptor(pixelEncoding: PixelEncoding(rawValue: 6), bitsPerComponent: 12, eotf: .pq, dynamicRange: .limited)) == nil)
        #expect(LinkDescription(bitDepth: 12, range: 0, eotf: 2, pixelEncoding: 4).colorDescriptor == nil)
        #expect(LinkDescription(bitDepth: 12, range: 0, eotf: 2, pixelEncoding: 6).label == "Dolby Vision 저지연, 12 bpc, Limited, PQ (HDR10)")
    }

    @Test func 제공_여부_판정() {
        let list = Self.tvList
        let offered = ColorElement(id: 122, pixelEncoding: .ycbcr422, bitsPerComponent: 12, eotf: .pq, dynamicRange: .limited, colorimetry: 7)
        let sdr422 = ColorElement(id: 110, pixelEncoding: .ycbcr422, bitsPerComponent: 10, eotf: .sdr, dynamicRange: .limited, colorimetry: 0)
        let hlg = ColorElement(id: 128, pixelEncoding: .ycbcr422, bitsPerComponent: 10, eotf: .hlg, dynamicRange: .limited, colorimetry: 7)
        #expect(list.offers(offered))
        #expect(list.mode(matching: offered.descriptor) == list.modes[0])
        #expect(!list.offers(sdr422))
        #expect(!list.offers(hlg))
        #expect(list.summary.hasPrefix("YCbCr 4:2:2, 12 bpc, Limited, PQ (HDR10) / "))
    }
}
