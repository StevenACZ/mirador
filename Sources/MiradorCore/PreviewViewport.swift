import Foundation

public struct PreviewViewport: Codable, Equatable, Sendable {
    public static let full = PreviewViewport(
        normalizedX: 0,
        normalizedY: 0,
        normalizedWidth: 1,
        normalizedHeight: 1
    )

    public let normalizedX: Double
    public let normalizedY: Double
    public let normalizedWidth: Double
    public let normalizedHeight: Double

    public init(
        normalizedX: Double,
        normalizedY: Double,
        normalizedWidth: Double,
        normalizedHeight: Double
    ) {
        self.normalizedX = normalizedX
        self.normalizedY = normalizedY
        self.normalizedWidth = normalizedWidth
        self.normalizedHeight = normalizedHeight
    }

    public static func centered(zoomScale: Double) -> PreviewViewport {
        cropped(zoomScale: zoomScale, centerX: 0.5, centerY: 0.5)
    }

    public static func cropped(zoomScale: Double, centerX: Double, centerY: Double) -> PreviewViewport {
        let clampedScale = min(max(zoomScale, 1), 4)
        let size = 1 / clampedScale
        let halfSize = size / 2
        let clampedCenterX = min(max(centerX, halfSize), 1 - halfSize)
        let clampedCenterY = min(max(centerY, halfSize), 1 - halfSize)
        return PreviewViewport(
            normalizedX: clampedCenterX - halfSize,
            normalizedY: clampedCenterY - halfSize,
            normalizedWidth: size,
            normalizedHeight: size
        )
    }

    public var isValid: Bool {
        [normalizedX, normalizedY, normalizedWidth, normalizedHeight].allSatisfy(\.isFinite)
            && normalizedWidth > 0
            && normalizedHeight > 0
            && normalizedX >= 0
            && normalizedY >= 0
            && normalizedX + normalizedWidth <= 1
            && normalizedY + normalizedHeight <= 1
    }

    public var isFull: Bool {
        self == .full
    }

    public var zoomScale: Double {
        guard normalizedWidth > 0, normalizedHeight > 0 else { return 1 }
        return 1 / min(normalizedWidth, normalizedHeight)
    }
}
