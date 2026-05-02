import Foundation

public struct StreamStats: Codable, Equatable, Sendable {
    public let capturedAt: Date
    public let framesSent: Int
    public let bytesSent: Int
    public let effectiveFramesPerSecond: Double
    public let bitrateKilobitsPerSecond: Double
    public let lastFrameBytes: Int
    public let captureDurationMilliseconds: Double
    public let captureWaitDurationMilliseconds: Double
    public let sendDurationMilliseconds: Double
    public let targetFrameRate: Int
    public let qualityProfile: StreamQualityProfile
    public let displayID: UInt32?
    public let sourceFramesDropped: Int
    public let sourceDropRate: Double

    public init(
        capturedAt: Date = Date(),
        framesSent: Int,
        bytesSent: Int,
        effectiveFramesPerSecond: Double,
        bitrateKilobitsPerSecond: Double,
        lastFrameBytes: Int,
        captureDurationMilliseconds: Double,
        captureWaitDurationMilliseconds: Double = 0,
        sendDurationMilliseconds: Double = 0,
        targetFrameRate: Int,
        qualityProfile: StreamQualityProfile,
        displayID: UInt32?,
        sourceFramesDropped: Int = 0,
        sourceDropRate: Double = 0
    ) {
        self.capturedAt = capturedAt
        self.framesSent = framesSent
        self.bytesSent = bytesSent
        self.effectiveFramesPerSecond = effectiveFramesPerSecond
        self.bitrateKilobitsPerSecond = bitrateKilobitsPerSecond
        self.lastFrameBytes = lastFrameBytes
        self.captureDurationMilliseconds = captureDurationMilliseconds
        self.captureWaitDurationMilliseconds = captureWaitDurationMilliseconds
        self.sendDurationMilliseconds = sendDurationMilliseconds
        self.targetFrameRate = targetFrameRate
        self.qualityProfile = qualityProfile
        self.displayID = displayID
        self.sourceFramesDropped = sourceFramesDropped
        self.sourceDropRate = sourceDropRate
    }
}
