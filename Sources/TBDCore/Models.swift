import Foundation

/// 디스플레이 식별 정보. (SRS-INF-001)
public struct DisplayIdentity: Codable, Hashable, Sendable {
    public var displayID: UInt32
    public var uuid: String?
    public var vendorID: UInt32
    public var productID: UInt32
    public var serialNumber: UInt32
    public var name: String
    public var isBuiltin: Bool

    public init(displayID: UInt32, uuid: String?, vendorID: UInt32, productID: UInt32, serialNumber: UInt32, name: String, isBuiltin: Bool) {
        self.displayID = displayID
        self.uuid = uuid
        self.vendorID = vendorID
        self.productID = productID
        self.serialNumber = serialNumber
        self.name = name
        self.isBuiltin = isBuiltin
    }
}

/// 디스플레이 1대의 현재 상태 요약. (PRD-APP-002, PRD-INF-001)
public struct DisplaySummary: Codable, Hashable, Sendable, Identifiable {
    public var identity: DisplayIdentity
    public var isMain: Bool
    public var isActive: Bool
    public var mirrorsDisplayID: UInt32?
    /// 논리 해상도 (포인트).
    public var pointWidth: Int
    public var pointHeight: Int
    /// 백킹 해상도 (픽셀).
    public var pixelWidth: Int
    public var pixelHeight: Int
    public var refreshRate: Double
    public var rotationDegrees: Double
    public var originX: Int
    public var originY: Int
    /// 물리 크기 (mm). 미보고 시 0.
    public var physicalWidthMM: Double
    public var physicalHeightMM: Double

    public var id: UInt32 { identity.displayID }

    public init(identity: DisplayIdentity, isMain: Bool, isActive: Bool, mirrorsDisplayID: UInt32?, pointWidth: Int, pointHeight: Int, pixelWidth: Int, pixelHeight: Int, refreshRate: Double, rotationDegrees: Double, originX: Int, originY: Int, physicalWidthMM: Double, physicalHeightMM: Double) {
        self.identity = identity
        self.isMain = isMain
        self.isActive = isActive
        self.mirrorsDisplayID = mirrorsDisplayID
        self.pointWidth = pointWidth
        self.pointHeight = pointHeight
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.refreshRate = refreshRate
        self.rotationDegrees = rotationDegrees
        self.originX = originX
        self.originY = originY
        self.physicalWidthMM = physicalWidthMM
        self.physicalHeightMM = physicalHeightMM
    }

    /// 배율. 2.0 이상이면 HiDPI.
    public var scale: Double {
        pointWidth > 0 ? Double(pixelWidth) / Double(pointWidth) : 1
    }

    public var isHiDPI: Bool { scale >= 2 }

    /// 대각 길이 (인치). 물리 크기 미보고 시 nil.
    public var diagonalInches: Double? {
        guard physicalWidthMM > 0, physicalHeightMM > 0 else { return nil }
        return (physicalWidthMM * physicalWidthMM + physicalHeightMM * physicalHeightMM).squareRoot() / 25.4
    }

    /// 백킹 해상도 기준 인치당 픽셀 수. 물리 크기 미보고 시 nil.
    public var pixelsPerInch: Double? {
        guard physicalWidthMM > 0 else { return nil }
        return Double(pixelWidth) / (physicalWidthMM / 25.4)
    }

    /// 사이드바 표시용 요약. 예: "2304 x 1296 HiDPI, 120 Hz"
    public var modeDescription: String {
        let hz = refreshRate > 0 ? ", \(Self.formatHz(refreshRate)) Hz" : ""
        return "\(pointWidth) x \(pointHeight)\(isHiDPI ? " HiDPI" : "")\(hz)"
    }

    public static func formatHz(_ value: Double) -> String {
        let rounded = (value * 100).rounded() / 100
        return rounded == rounded.rounded() ? String(Int(rounded)) : String(format: "%.2f", rounded)
    }
}

/// 한 시점의 시스템 디스플레이 상태. 조회 결과의 단일 전달 단위. (SRS 1.3절)
public struct SystemSnapshot: Codable, Hashable, Sendable {
    public var capturedAt: Date
    public var displays: [DisplaySummary]

    public init(capturedAt: Date, displays: [DisplaySummary]) {
        self.capturedAt = capturedAt
        self.displays = displays
    }
}
