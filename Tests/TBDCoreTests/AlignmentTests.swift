import Foundation
import Testing
@testable import TBDCore

/// TC-ARR-006: 16방향 정렬 좌표 계산.
@Suite("TC-ARR-006 16방향 정렬")
struct AlignmentTests {
    // 기준: 1512 x 982 (원점 0, 0). 대상: 1920 x 1080.
    static let reference = DisplayFrame(id: 1, x: 0, y: 0, width: 1512, height: 982)
    static let target = DisplayFrame(id: 2, x: 5000, y: 5000, width: 1920, height: 1080)

    static func origin(_ p: AlignmentPosition) -> [Int] {
        let o = ArrangementPlanner.alignedOrigin(target: target, reference: reference, position: p)
        return [o.x, o.y]
    }

    @Test func 변별_세_가지_맞춤() {
        #expect(Self.origin(.rightTop) == [1512, 0])
        #expect(Self.origin(.rightCenter) == [1512, -49])
        #expect(Self.origin(.rightBottom) == [1512, -98])
        #expect(Self.origin(.leftTop) == [-1920, 0])
        #expect(Self.origin(.leftCenter) == [-1920, -49])
        #expect(Self.origin(.leftBottom) == [-1920, -98])
        #expect(Self.origin(.topLeft) == [0, -1080])
        #expect(Self.origin(.topCenter) == [-204, -1080])
        #expect(Self.origin(.topRight) == [-408, -1080])
        #expect(Self.origin(.bottomLeft) == [0, 982])
        #expect(Self.origin(.bottomCenter) == [-204, 982])
        #expect(Self.origin(.bottomRight) == [-408, 982])
    }

    @Test func 모서리_네_가지() {
        #expect(Self.origin(.cornerTopLeft) == [-1920, -1080])
        #expect(Self.origin(.cornerTopRight) == [1512, -1080])
        #expect(Self.origin(.cornerBottomLeft) == [-1920, 982])
        #expect(Self.origin(.cornerBottomRight) == [1512, 982])
    }

    @Test func 변_정렬_결과는_기준과_맞닿고_겹치지_않음() {
        for position in AlignmentPosition.allCases where !position.rawValue.hasPrefix("corner") {
            let o = ArrangementPlanner.alignedOrigin(target: Self.target, reference: Self.reference, position: position)
            let moved = DisplayFrame(id: 2, x: o.x, y: o.y, width: 1920, height: 1080)
            #expect(moved.touches(Self.reference), "\(position.rawValue)")
            #expect(!moved.overlaps(Self.reference), "\(position.rawValue)")
        }
        #expect(AlignmentPosition.allCases.count == 16)
    }

    @Test func 위치_표기_해석() {
        #expect(AlignmentPosition.parse("right-top") == .rightTop)
        #expect(AlignmentPosition.parse("LEFT") == .leftCenter)
        #expect(AlignmentPosition.parse("bottom") == .bottomCenter)
        #expect(AlignmentPosition.parse("corner-top-right") == .cornerTopRight)
        #expect(AlignmentPosition.parse("middle") == nil)
    }
}
