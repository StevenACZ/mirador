import CoreVideo
import Foundation
import MiradorCore

struct CapturedPreviewFrame: Sendable {
    let frame: PreviewFrame
    let waitDurationMilliseconds: Double
    let encodeDurationMilliseconds: Double
}

struct CapturedSourceFrame: @unchecked Sendable {
    let pixelBuffer: CVPixelBuffer
    let capturedAt: Date
    let width: Int
    let height: Int
    let displayID: UInt32?
    let qualityProfile: StreamQualityProfile
    let viewport: PreviewViewport
    let sourceFrameNumber: UInt64
    let sourceFramesDropped: Int
    let isRepeatedSourceFrame: Bool
    let waitDurationMilliseconds: Double
}
