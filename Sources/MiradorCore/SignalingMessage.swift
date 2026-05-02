import Foundation

public enum SignalingMessage: Codable, Equatable, Sendable {
    case hello(ClientHello)
    case hostStatus(HostStatus)
    case authenticationResult(AuthenticationResult)
    case startPreview(DisplaySelection)
    case previewFrame(PreviewFrame)
    case streamStats(StreamStats)
    case remoteInput(RemoteInputEvent)
    case stopPreview
    case error(ErrorMessage)

    private enum CodingKeys: String, CodingKey {
        case type
        case payload
    }

    private enum MessageType: String, Codable {
        case hello
        case hostStatus
        case authenticationResult
        case startPreview
        case previewFrame
        case streamStats
        case remoteInput
        case stopPreview
        case error
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(MessageType.self, forKey: .type)

        switch type {
        case .hello:
            self = .hello(try container.decode(ClientHello.self, forKey: .payload))
        case .hostStatus:
            self = .hostStatus(try container.decode(HostStatus.self, forKey: .payload))
        case .authenticationResult:
            self = .authenticationResult(try container.decode(AuthenticationResult.self, forKey: .payload))
        case .startPreview:
            self = .startPreview(try container.decode(DisplaySelection.self, forKey: .payload))
        case .previewFrame:
            self = .previewFrame(try container.decode(PreviewFrame.self, forKey: .payload))
        case .streamStats:
            self = .streamStats(try container.decode(StreamStats.self, forKey: .payload))
        case .remoteInput:
            self = .remoteInput(try container.decode(RemoteInputEvent.self, forKey: .payload))
        case .stopPreview:
            self = .stopPreview
        case .error:
            self = .error(try container.decode(ErrorMessage.self, forKey: .payload))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case let .hello(payload):
            try container.encode(MessageType.hello, forKey: .type)
            try container.encode(payload, forKey: .payload)
        case let .hostStatus(payload):
            try container.encode(MessageType.hostStatus, forKey: .type)
            try container.encode(payload, forKey: .payload)
        case let .authenticationResult(payload):
            try container.encode(MessageType.authenticationResult, forKey: .type)
            try container.encode(payload, forKey: .payload)
        case let .startPreview(payload):
            try container.encode(MessageType.startPreview, forKey: .type)
            try container.encode(payload, forKey: .payload)
        case let .previewFrame(payload):
            try container.encode(MessageType.previewFrame, forKey: .type)
            try container.encode(payload, forKey: .payload)
        case let .streamStats(payload):
            try container.encode(MessageType.streamStats, forKey: .type)
            try container.encode(payload, forKey: .payload)
        case let .remoteInput(payload):
            try container.encode(MessageType.remoteInput, forKey: .type)
            try container.encode(payload, forKey: .payload)
        case .stopPreview:
            try container.encode(MessageType.stopPreview, forKey: .type)
            try container.encode(EmptyPayload(), forKey: .payload)
        case let .error(payload):
            try container.encode(MessageType.error, forKey: .type)
            try container.encode(payload, forKey: .payload)
        }
    }
}

public struct ClientHello: Codable, Equatable, Sendable {
    public let deviceName: String
    public let protocolVersion: Int

    public init(deviceName: String, protocolVersion: Int = MiradorConstants.protocolVersion) {
        self.deviceName = deviceName
        self.protocolVersion = protocolVersion
    }
}

public struct HostStatus: Codable, Equatable, Sendable {
    public let hostName: String
    public let protocolVersion: Int
    public let isCaptureActive: Bool
    public let targetFrameRate: Int
    public let availableDisplays: [DisplayDescriptor]
    public let selectedDisplayID: UInt32?
    public let qualityProfile: StreamQualityProfile
    public let isSystemAudioAvailable: Bool
    public let isSystemAudioEnabled: Bool
    public let systemAudio: SystemAudioStatus

    public init(
        hostName: String,
        protocolVersion: Int = MiradorConstants.protocolVersion,
        isCaptureActive: Bool,
        targetFrameRate: Int = MiradorConstants.defaultFrameRate,
        availableDisplays: [DisplayDescriptor] = [],
        selectedDisplayID: UInt32? = nil,
        qualityProfile: StreamQualityProfile = .balanced,
        isSystemAudioAvailable: Bool? = nil,
        isSystemAudioEnabled: Bool? = nil,
        systemAudio: SystemAudioStatus = .disabled(isAvailable: true)
    ) {
        self.hostName = hostName
        self.protocolVersion = protocolVersion
        self.isCaptureActive = isCaptureActive
        self.targetFrameRate = targetFrameRate
        self.availableDisplays = availableDisplays
        self.selectedDisplayID = selectedDisplayID
        self.qualityProfile = qualityProfile
        self.systemAudio = systemAudio
        self.isSystemAudioAvailable = isSystemAudioAvailable ?? systemAudio.isAvailable
        self.isSystemAudioEnabled = isSystemAudioEnabled ?? systemAudio.isAllowedByHost
    }
}

public struct AuthenticationResult: Codable, Equatable, Sendable {
    public let accepted: Bool
    public let reason: String?

    public init(accepted: Bool, reason: String? = nil) {
        self.accepted = accepted
        self.reason = reason
    }
}

public struct DisplaySelection: Codable, Equatable, Sendable {
    public let displayID: UInt32?
    public let qualityProfile: StreamQualityProfile
    public let videoSettings: StreamVideoSettings
    public let viewport: PreviewViewport

    public init(
        displayID: UInt32? = nil,
        qualityProfile: StreamQualityProfile = .balanced,
        videoSettings: StreamVideoSettings? = nil,
        viewport: PreviewViewport = .full
    ) {
        self.displayID = displayID
        let resolvedSettings = videoSettings ?? StreamVideoSettings(qualityProfile: qualityProfile)
        self.qualityProfile = resolvedSettings.qualityProfile
        self.videoSettings = resolvedSettings
        self.viewport = viewport
    }

    private enum CodingKeys: String, CodingKey {
        case displayID
        case qualityProfile
        case videoSettings
        case viewport
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        displayID = try container.decodeIfPresent(UInt32.self, forKey: .displayID)
        let legacyProfile = try container.decodeIfPresent(
            StreamQualityProfile.self,
            forKey: .qualityProfile
        ) ?? .balanced
        videoSettings = try container.decodeIfPresent(
            StreamVideoSettings.self,
            forKey: .videoSettings
        ) ?? StreamVideoSettings(qualityProfile: legacyProfile)
        qualityProfile = videoSettings.qualityProfile
        viewport = try container.decodeIfPresent(PreviewViewport.self, forKey: .viewport) ?? .full
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(displayID, forKey: .displayID)
        try container.encode(qualityProfile, forKey: .qualityProfile)
        try container.encode(videoSettings, forKey: .videoSettings)
        try container.encode(viewport, forKey: .viewport)
    }
}

public struct PreviewFrame: Codable, Equatable, Sendable {
    public let sequence: UInt64
    public let capturedAt: Date
    public let width: Int
    public let height: Int
    public let displayID: UInt32?
    public let qualityProfile: StreamQualityProfile
    public let viewport: PreviewViewport
    public let sourceFrameNumber: UInt64
    public let sourceFramesDropped: Int
    public let jpegData: Data

    public init(
        sequence: UInt64,
        capturedAt: Date,
        width: Int,
        height: Int,
        displayID: UInt32? = nil,
        qualityProfile: StreamQualityProfile = .balanced,
        viewport: PreviewViewport = .full,
        sourceFrameNumber: UInt64 = 0,
        sourceFramesDropped: Int = 0,
        jpegData: Data
    ) {
        self.sequence = sequence
        self.capturedAt = capturedAt
        self.width = width
        self.height = height
        self.displayID = displayID
        self.qualityProfile = qualityProfile
        self.viewport = viewport
        self.sourceFrameNumber = sourceFrameNumber
        self.sourceFramesDropped = sourceFramesDropped
        self.jpegData = jpegData
    }
}

public struct ErrorMessage: Codable, Equatable, Sendable {
    public let code: String
    public let message: String

    public init(code: String, message: String) {
        self.code = code
        self.message = message
    }
}

private struct EmptyPayload: Codable, Equatable, Sendable {}
