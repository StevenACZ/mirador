import Foundation

public enum SignalingMessage: Codable, Equatable, Sendable {
    case hello(ClientHello)
    case hostStatus(HostStatus)
    case authenticate(PINAuthentication)
    case authenticationResult(AuthenticationResult)
    case startPreview(DisplaySelection)
    case previewFrame(PreviewFrame)
    case stopPreview
    case error(ErrorMessage)

    private enum CodingKeys: String, CodingKey {
        case type
        case payload
    }

    private enum MessageType: String, Codable {
        case hello
        case hostStatus
        case authenticate
        case authenticationResult
        case startPreview
        case previewFrame
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
        case .authenticate:
            self = .authenticate(try container.decode(PINAuthentication.self, forKey: .payload))
        case .authenticationResult:
            self = .authenticationResult(try container.decode(AuthenticationResult.self, forKey: .payload))
        case .startPreview:
            self = .startPreview(try container.decode(DisplaySelection.self, forKey: .payload))
        case .previewFrame:
            self = .previewFrame(try container.decode(PreviewFrame.self, forKey: .payload))
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
        case let .authenticate(payload):
            try container.encode(MessageType.authenticate, forKey: .type)
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

    public init(
        hostName: String,
        protocolVersion: Int = MiradorConstants.protocolVersion,
        isCaptureActive: Bool,
        targetFrameRate: Int = MiradorConstants.mvpFrameRate
    ) {
        self.hostName = hostName
        self.protocolVersion = protocolVersion
        self.isCaptureActive = isCaptureActive
        self.targetFrameRate = targetFrameRate
    }
}

public struct PINAuthentication: Codable, Equatable, Sendable {
    public let pin: String

    public init(pin: String) {
        self.pin = pin
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

    public init(displayID: UInt32? = nil) {
        self.displayID = displayID
    }
}

public struct PreviewFrame: Codable, Equatable, Sendable {
    public let sequence: UInt64
    public let capturedAt: Date
    public let width: Int
    public let height: Int
    public let jpegData: Data

    public init(sequence: UInt64, capturedAt: Date, width: Int, height: Int, jpegData: Data) {
        self.sequence = sequence
        self.capturedAt = capturedAt
        self.width = width
        self.height = height
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
