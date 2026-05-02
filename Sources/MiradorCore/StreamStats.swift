import Foundation

public struct StreamStats: Codable, Equatable, Sendable {
    public let capturedAt: Date
    public let framesSent: Int
    public let bytesSent: Int
    public let effectiveFramesPerSecond: Double
    public let sourceFramesPerSecond: Double
    public let encodedFramesPerSecond: Double
    public let sentFramesPerSecond: Double
    public let bitrateKilobitsPerSecond: Double
    public let lastFrameBytes: Int
    public let captureDurationMilliseconds: Double
    public let captureWaitDurationMilliseconds: Double
    public let sendDurationMilliseconds: Double
    public let targetFrameRate: Int
    public let codec: StreamCodec
    public let qualityProfile: StreamQualityProfile
    public let displayID: UInt32?
    public let sourceFramesDropped: Int
    public let sourceDropRate: Double
    public let repeatedFrames: Int
    public let repeatedFrameRate: Double

    private enum CodingKeys: String, CodingKey {
        case capturedAt
        case framesSent
        case bytesSent
        case effectiveFramesPerSecond
        case sourceFramesPerSecond
        case encodedFramesPerSecond
        case sentFramesPerSecond
        case bitrateKilobitsPerSecond
        case lastFrameBytes
        case captureDurationMilliseconds
        case captureWaitDurationMilliseconds
        case sendDurationMilliseconds
        case targetFrameRate
        case codec
        case qualityProfile
        case displayID
        case sourceFramesDropped
        case sourceDropRate
        case repeatedFrames
        case repeatedFrameRate
    }

    public init(
        capturedAt: Date = Date(),
        framesSent: Int,
        bytesSent: Int,
        effectiveFramesPerSecond: Double,
        sourceFramesPerSecond: Double? = nil,
        encodedFramesPerSecond: Double? = nil,
        sentFramesPerSecond: Double? = nil,
        bitrateKilobitsPerSecond: Double,
        lastFrameBytes: Int,
        captureDurationMilliseconds: Double,
        captureWaitDurationMilliseconds: Double = 0,
        sendDurationMilliseconds: Double = 0,
        targetFrameRate: Int,
        codec: StreamCodec = .jpeg,
        qualityProfile: StreamQualityProfile,
        displayID: UInt32?,
        sourceFramesDropped: Int = 0,
        sourceDropRate: Double = 0,
        repeatedFrames: Int = 0,
        repeatedFrameRate: Double = 0
    ) {
        self.capturedAt = capturedAt
        self.framesSent = framesSent
        self.bytesSent = bytesSent
        self.effectiveFramesPerSecond = effectiveFramesPerSecond
        self.sourceFramesPerSecond = sourceFramesPerSecond ?? effectiveFramesPerSecond
        self.encodedFramesPerSecond = encodedFramesPerSecond ?? effectiveFramesPerSecond
        self.sentFramesPerSecond = sentFramesPerSecond ?? effectiveFramesPerSecond
        self.bitrateKilobitsPerSecond = bitrateKilobitsPerSecond
        self.lastFrameBytes = lastFrameBytes
        self.captureDurationMilliseconds = captureDurationMilliseconds
        self.captureWaitDurationMilliseconds = captureWaitDurationMilliseconds
        self.sendDurationMilliseconds = sendDurationMilliseconds
        self.targetFrameRate = targetFrameRate
        self.codec = codec
        self.qualityProfile = qualityProfile
        self.displayID = displayID
        self.sourceFramesDropped = sourceFramesDropped
        self.sourceDropRate = sourceDropRate
        self.repeatedFrames = repeatedFrames
        self.repeatedFrameRate = repeatedFrameRate
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let effectiveFramesPerSecond = try container.decode(
            Double.self,
            forKey: .effectiveFramesPerSecond
        )
        self.init(
            capturedAt: try container.decode(Date.self, forKey: .capturedAt),
            framesSent: try container.decode(Int.self, forKey: .framesSent),
            bytesSent: try container.decode(Int.self, forKey: .bytesSent),
            effectiveFramesPerSecond: effectiveFramesPerSecond,
            sourceFramesPerSecond: try container.decodeIfPresent(
                Double.self,
                forKey: .sourceFramesPerSecond
            ) ?? effectiveFramesPerSecond,
            encodedFramesPerSecond: try container.decodeIfPresent(
                Double.self,
                forKey: .encodedFramesPerSecond
            ) ?? effectiveFramesPerSecond,
            sentFramesPerSecond: try container.decodeIfPresent(
                Double.self,
                forKey: .sentFramesPerSecond
            ) ?? effectiveFramesPerSecond,
            bitrateKilobitsPerSecond: try container.decode(Double.self, forKey: .bitrateKilobitsPerSecond),
            lastFrameBytes: try container.decode(Int.self, forKey: .lastFrameBytes),
            captureDurationMilliseconds: try container.decode(Double.self, forKey: .captureDurationMilliseconds),
            captureWaitDurationMilliseconds: try container.decodeIfPresent(
                Double.self,
                forKey: .captureWaitDurationMilliseconds
            ) ?? 0,
            sendDurationMilliseconds: try container.decodeIfPresent(
                Double.self,
                forKey: .sendDurationMilliseconds
            ) ?? 0,
            targetFrameRate: try container.decode(Int.self, forKey: .targetFrameRate),
            codec: try container.decodeIfPresent(StreamCodec.self, forKey: .codec) ?? .jpeg,
            qualityProfile: try container.decode(StreamQualityProfile.self, forKey: .qualityProfile),
            displayID: try container.decodeIfPresent(UInt32.self, forKey: .displayID),
            sourceFramesDropped: try container.decodeIfPresent(Int.self, forKey: .sourceFramesDropped) ?? 0,
            sourceDropRate: try container.decodeIfPresent(Double.self, forKey: .sourceDropRate) ?? 0,
            repeatedFrames: try container.decodeIfPresent(Int.self, forKey: .repeatedFrames) ?? 0,
            repeatedFrameRate: try container.decodeIfPresent(Double.self, forKey: .repeatedFrameRate) ?? 0
        )
    }
}
