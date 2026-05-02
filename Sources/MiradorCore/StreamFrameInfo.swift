import Foundation

public struct StreamFrameInfo: Codable, Equatable, Sendable {
    public let codec: StreamCodec
    public let sequence: UInt64
    public let capturedAt: Date
    public let width: Int
    public let height: Int
    public let displayID: UInt32?
    public let qualityProfile: StreamQualityProfile
    public let viewport: PreviewViewport
    public let sourceFrameNumber: UInt64
    public let sourceFramesDropped: Int
    public let isKeyframe: Bool

    public init(
        codec: StreamCodec,
        sequence: UInt64,
        capturedAt: Date,
        width: Int,
        height: Int,
        displayID: UInt32? = nil,
        qualityProfile: StreamQualityProfile = .balanced,
        viewport: PreviewViewport = .full,
        sourceFrameNumber: UInt64 = 0,
        sourceFramesDropped: Int = 0,
        isKeyframe: Bool = false
    ) {
        self.codec = codec
        self.sequence = sequence
        self.capturedAt = capturedAt
        self.width = width
        self.height = height
        self.displayID = displayID
        self.qualityProfile = qualityProfile
        self.viewport = viewport
        self.sourceFrameNumber = sourceFrameNumber
        self.sourceFramesDropped = sourceFramesDropped
        self.isKeyframe = isKeyframe
    }

    public init(previewFrame frame: PreviewFrame) {
        self.init(
            codec: .jpeg,
            sequence: frame.sequence,
            capturedAt: frame.capturedAt,
            width: frame.width,
            height: frame.height,
            displayID: frame.displayID,
            qualityProfile: frame.qualityProfile,
            viewport: frame.viewport,
            sourceFrameNumber: frame.sourceFrameNumber,
            sourceFramesDropped: frame.sourceFramesDropped,
            isKeyframe: true
        )
    }

    public init(videoFrame frame: EncodedVideoFrame) {
        self.init(
            codec: frame.codec,
            sequence: frame.sequence,
            capturedAt: frame.capturedAt,
            width: frame.width,
            height: frame.height,
            displayID: frame.displayID,
            qualityProfile: frame.qualityProfile,
            viewport: frame.viewport,
            sourceFrameNumber: frame.sourceFrameNumber,
            sourceFramesDropped: frame.sourceFramesDropped,
            isKeyframe: frame.isKeyframe
        )
    }
}
