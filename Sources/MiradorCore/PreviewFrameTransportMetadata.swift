import Foundation

struct PreviewFrameTransportMetadata: Codable, Equatable, Sendable {
    let sequence: UInt64
    let capturedAt: Date
    let width: Int
    let height: Int
    let displayID: UInt32?
    let qualityProfile: StreamQualityProfile
    let viewport: PreviewViewport
    let sourceFrameNumber: UInt64
    let sourceFramesDropped: Int

    init(frame: PreviewFrame) {
        sequence = frame.sequence
        capturedAt = frame.capturedAt
        width = frame.width
        height = frame.height
        displayID = frame.displayID
        qualityProfile = frame.qualityProfile
        viewport = frame.viewport
        sourceFrameNumber = frame.sourceFrameNumber
        sourceFramesDropped = frame.sourceFramesDropped
    }

    func previewFrame(jpegData: Data) -> PreviewFrame {
        PreviewFrame(
            sequence: sequence,
            capturedAt: capturedAt,
            width: width,
            height: height,
            displayID: displayID,
            qualityProfile: qualityProfile,
            viewport: viewport,
            sourceFrameNumber: sourceFrameNumber,
            sourceFramesDropped: sourceFramesDropped,
            jpegData: jpegData
        )
    }
}
