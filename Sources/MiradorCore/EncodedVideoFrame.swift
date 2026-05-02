import Foundation

public struct VideoFormatMetadata: Codable, Equatable, Sendable {
    public let parameterSets: [Data]
    public let nalUnitHeaderLength: Int

    public init(parameterSets: [Data], nalUnitHeaderLength: Int) {
        self.parameterSets = parameterSets
        self.nalUnitHeaderLength = nalUnitHeaderLength
    }
}

public struct EncodedVideoFrame: Codable, Equatable, Sendable {
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
    public let format: VideoFormatMetadata?
    public let data: Data

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
        isKeyframe: Bool,
        format: VideoFormatMetadata? = nil,
        data: Data
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
        self.format = format
        self.data = data
    }
}
