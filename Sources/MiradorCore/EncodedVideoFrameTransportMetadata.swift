import Foundation

struct EncodedVideoFrameTransportMetadata: Codable, Equatable, Sendable {
    let codec: StreamCodec
    let sequence: UInt64
    let capturedAt: Date
    let width: Int
    let height: Int
    let displayID: UInt32?
    let qualityProfile: StreamQualityProfile
    let viewport: PreviewViewport
    let sourceFrameNumber: UInt64
    let sourceFramesDropped: Int
    let isKeyframe: Bool
    let format: VideoFormatMetadata?

    init(frame: EncodedVideoFrame) {
        codec = frame.codec
        sequence = frame.sequence
        capturedAt = frame.capturedAt
        width = frame.width
        height = frame.height
        displayID = frame.displayID
        qualityProfile = frame.qualityProfile
        viewport = frame.viewport
        sourceFrameNumber = frame.sourceFrameNumber
        sourceFramesDropped = frame.sourceFramesDropped
        isKeyframe = frame.isKeyframe
        format = frame.format
    }

    func encodedVideoFrame(data: Data) -> EncodedVideoFrame {
        EncodedVideoFrame(
            codec: codec,
            sequence: sequence,
            capturedAt: capturedAt,
            width: width,
            height: height,
            displayID: displayID,
            qualityProfile: qualityProfile,
            viewport: viewport,
            sourceFrameNumber: sourceFrameNumber,
            sourceFramesDropped: sourceFramesDropped,
            isKeyframe: isKeyframe,
            format: format,
            data: data
        )
    }
}
