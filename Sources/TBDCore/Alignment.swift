import Foundation

/// 기준 디스플레이에 대한 16방향 정렬 위치. 변 4개마다 시작, 가운데, 끝 3가지와 모서리 4가지. (PRD-ARR-007)
public enum AlignmentPosition: String, CaseIterable, Sendable {
    case leftTop = "left-top", leftCenter = "left-center", leftBottom = "left-bottom"
    case rightTop = "right-top", rightCenter = "right-center", rightBottom = "right-bottom"
    case topLeft = "top-left", topCenter = "top-center", topRight = "top-right"
    case bottomLeft = "bottom-left", bottomCenter = "bottom-center", bottomRight = "bottom-right"
    case cornerTopLeft = "corner-top-left", cornerTopRight = "corner-top-right"
    case cornerBottomLeft = "corner-bottom-left", cornerBottomRight = "corner-bottom-right"

    public var title: String {
        switch self {
        case .leftTop: "왼쪽, 위 맞춤"
        case .leftCenter: "왼쪽, 가운데 맞춤"
        case .leftBottom: "왼쪽, 아래 맞춤"
        case .rightTop: "오른쪽, 위 맞춤"
        case .rightCenter: "오른쪽, 가운데 맞춤"
        case .rightBottom: "오른쪽, 아래 맞춤"
        case .topLeft: "위쪽, 왼쪽 맞춤"
        case .topCenter: "위쪽, 가운데 맞춤"
        case .topRight: "위쪽, 오른쪽 맞춤"
        case .bottomLeft: "아래쪽, 왼쪽 맞춤"
        case .bottomCenter: "아래쪽, 가운데 맞춤"
        case .bottomRight: "아래쪽, 오른쪽 맞춤"
        case .cornerTopLeft: "왼쪽 위 모서리"
        case .cornerTopRight: "오른쪽 위 모서리"
        case .cornerBottomLeft: "왼쪽 아래 모서리"
        case .cornerBottomRight: "오른쪽 아래 모서리"
        }
    }

    /// 짧은 표기도 허용: `left`는 `left-center`, `top`은 `top-center` 등.
    public static func parse(_ text: String) -> AlignmentPosition? {
        let lower = text.lowercased()
        if let exact = AlignmentPosition(rawValue: lower) { return exact }
        return ["left": .leftCenter, "right": .rightCenter, "top": .topCenter, "bottom": .bottomCenter][lower]
    }
}

public extension ArrangementPlanner {
    /// 기준 디스플레이에 대해 정렬한 대상의 원점. 좌표계는 위가 음수 방향.
    /// 모서리 위치는 점으로만 맞닿으므로 적용 단계에서 가장 가까운 변으로 보정될 수 있음.
    static func alignedOrigin(target: DisplayFrame, reference: DisplayFrame, position: AlignmentPosition) -> (x: Int, y: Int) {
        let left = reference.x - target.width, right = reference.maxX
        let above = reference.y - target.height, below = reference.maxY
        let centerX = reference.x + (reference.width - target.width) / 2
        let centerY = reference.y + (reference.height - target.height) / 2
        let endX = reference.maxX - target.width, endY = reference.maxY - target.height
        switch position {
        case .leftTop: return (left, reference.y)
        case .leftCenter: return (left, centerY)
        case .leftBottom: return (left, endY)
        case .rightTop: return (right, reference.y)
        case .rightCenter: return (right, centerY)
        case .rightBottom: return (right, endY)
        case .topLeft: return (reference.x, above)
        case .topCenter: return (centerX, above)
        case .topRight: return (endX, above)
        case .bottomLeft: return (reference.x, below)
        case .bottomCenter: return (centerX, below)
        case .bottomRight: return (endX, below)
        case .cornerTopLeft: return (left, above)
        case .cornerTopRight: return (right, above)
        case .cornerBottomLeft: return (left, below)
        case .cornerBottomRight: return (right, below)
        }
    }
}
