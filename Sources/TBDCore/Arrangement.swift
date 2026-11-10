import Foundation

/// 전역 좌표계의 디스플레이 사각형 (포인트). 메인 디스플레이의 원점이 (0, 0).
public struct DisplayFrame: Codable, Hashable, Sendable, Identifiable {
    public var id: UInt32
    public var x: Int
    public var y: Int
    public var width: Int
    public var height: Int

    public init(id: UInt32, x: Int, y: Int, width: Int, height: Int) {
        self.id = id
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public init(_ display: DisplaySummary) {
        self.init(id: display.id, x: display.originX, y: display.originY, width: display.pointWidth, height: display.pointHeight)
    }

    public var maxX: Int { x + width }
    public var maxY: Int { y + height }

    func overlaps(_ other: DisplayFrame) -> Bool {
        x < other.maxX && other.x < maxX && y < other.maxY && other.y < maxY
    }

    /// 변이 맞닿아 있는지 (겹치지 않고 한 변을 공유).
    func touches(_ other: DisplayFrame) -> Bool {
        let horizontalAdjacent = (maxX == other.x || other.maxX == x) && y < other.maxY && other.y < maxY
        let verticalAdjacent = (maxY == other.y || other.maxY == y) && x < other.maxX && other.x < maxX
        return horizontalAdjacent || verticalAdjacent
    }
}

/// 배치 계산. 순수 함수. (SRS-ARR-001)
public enum ArrangementPlanner {
    public static let rotations = [0, 90, 180, 270]

    public static func isValidRotation(_ degrees: Int) -> Bool { rotations.contains(degrees) }

    /// 메인 디스플레이 지정: 대상의 원점이 (0, 0)이 되도록 전체를 평행 이동. 상대 배치 유지.
    public static func makeMain(_ target: UInt32, frames: [DisplayFrame]) -> [DisplayFrame]? {
        guard let main = frames.first(where: { $0.id == target }) else { return nil }
        return frames.map { f in
            var moved = f
            moved.x -= main.x
            moved.y -= main.y
            return moved
        }
    }

    /// 디스플레이 이동: 요청 위치에서 가장 가까운 맞닿는 위치로 보정.
    /// macOS는 디스플레이가 서로 맞닿은 배치만 허용하므로 겹치거나 떨어진 위치는 가장 가까운 변으로 붙임.
    public static func move(_ target: UInt32, toX x: Int, y: Int, frames: [DisplayFrame]) -> [DisplayFrame]? {
        guard var moving = frames.first(where: { $0.id == target }) else { return nil }
        let others = frames.filter { $0.id != target }
        moving.x = x
        moving.y = y
        guard !others.isEmpty else {
            // 디스플레이가 1대면 원점 고정.
            moving.x = 0
            moving.y = 0
            return [moving]
        }
        let snapped = snap(moving, to: others)
        return frames.map { $0.id == target ? snapped : $0 }
    }

    /// 다른 디스플레이 중 하나의 변에 붙는 후보 위치 가운데 요청 위치와 가장 가까운 것 선택.
    static func snap(_ moving: DisplayFrame, to others: [DisplayFrame]) -> DisplayFrame {
        if !others.contains(where: { moving.overlaps($0) }), others.contains(where: { moving.touches($0) }) {
            return moving
        }
        var best: DisplayFrame?
        var bestDistance = Int.max
        for other in others {
            // 변에 붙인 뒤, 맞닿는 길이가 남도록 직교 방향 좌표를 범위 안으로 제한.
            let yRange = (other.y - moving.height + 1)...(other.maxY - 1)
            let xRange = (other.x - moving.width + 1)...(other.maxX - 1)
            let clampedY = min(max(moving.y, yRange.lowerBound), yRange.upperBound)
            let clampedX = min(max(moving.x, xRange.lowerBound), xRange.upperBound)
            let candidates = [
                (other.x - moving.width, clampedY),   // 왼쪽
                (other.maxX, clampedY),               // 오른쪽
                (clampedX, other.y - moving.height),  // 위
                (clampedX, other.maxY),               // 아래
            ]
            for (cx, cy) in candidates {
                var candidate = moving
                candidate.x = cx
                candidate.y = cy
                guard !others.contains(where: { candidate.overlaps($0) }) else { continue }
                let distance = (cx - moving.x) * (cx - moving.x) + (cy - moving.y) * (cy - moving.y)
                if distance < bestDistance {
                    bestDistance = distance
                    best = candidate
                }
            }
        }
        return best ?? moving
    }

    /// 메인 디스플레이(원점 0, 0)가 유지되도록 전체를 평행 이동. 메인이 움직였을 때 사용.
    public static func normalized(_ frames: [DisplayFrame], main: UInt32) -> [DisplayFrame] {
        makeMain(main, frames: frames) ?? frames
    }

    /// 연결 해제 허용 여부: 해제 뒤에도 온라인 디스플레이가 1대 이상 남아야 함. (PRD-SAF-003)
    public static func canDisconnect(_ target: UInt32, online: [UInt32]) -> Bool {
        online.contains(target) && online.filter { $0 != target }.count >= 1
    }

    /// 연결 해제 거부 사유. 허용이면 nil.
    public static func disconnectRefusal(_ target: UInt32, online: [UInt32]) -> String? {
        guard online.contains(target) else { return "온라인 상태가 아닌 디스플레이" }
        guard online.count > 1 else { return "마지막 온라인 디스플레이는 연결 해제 불가. 화면이 모두 꺼지면 복구 수단이 없음" }
        return nil
    }

    /// 미러 설정 허용 여부: 자기 자신이나 이미 다른 디스플레이를 미러 중인 대상은 원본으로 쓸 수 없음.
    public static func mirrorRefusal(display: UInt32, master: UInt32, displays: [DisplaySummary]) -> String? {
        guard display != master else { return "자기 자신은 미러 원본으로 지정 불가" }
        guard let masterDisplay = displays.first(where: { $0.id == master }) else { return "미러 원본 디스플레이가 온라인 상태가 아님" }
        guard displays.contains(where: { $0.id == display }) else { return "대상 디스플레이가 온라인 상태가 아님" }
        if masterDisplay.mirrorsDisplayID != nil { return "다른 디스플레이를 미러 중인 디스플레이는 미러 원본으로 지정 불가" }
        return nil
    }

    /// 배치 미리 보기용 축척: 전체 배치를 주어진 크기 안에 맞춤.
    public static func previewLayout(_ frames: [DisplayFrame], width: Double, height: Double, padding: Double = 12) -> (scale: Double, offsetX: Double, offsetY: Double) {
        guard let minX = frames.map(\.x).min(), let maxX = frames.map(\.maxX).max(), let minY = frames.map(\.y).min(), let maxY = frames.map(\.maxY).max(), maxX > minX, maxY > minY else {
            return (1, 0, 0)
        }
        let scale = min((width - padding * 2) / Double(maxX - minX), (height - padding * 2) / Double(maxY - minY))
        let offsetX = (width - Double(maxX - minX) * scale) / 2 - Double(minX) * scale
        let offsetY = (height - Double(maxY - minY) * scale) / 2 - Double(minY) * scale
        return (scale, offsetX, offsetY)
    }
}
