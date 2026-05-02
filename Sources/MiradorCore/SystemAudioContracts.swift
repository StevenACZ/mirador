import Foundation

public enum SystemAudioCaptureState: String, Codable, Equatable, Sendable {
    case unavailable
    case disabled
    case ready
    case capturing
    case failed
}

public enum SystemAudioTransportState: String, Codable, Equatable, Sendable {
    case notImplemented
    case hostCaptureOnly
    case streaming
}

public struct SystemAudioStats: Codable, Equatable, Sendable {
    public let capturedAt: Date
    public let sampleRate: Int
    public let channelCount: Int
    public let capturedBuffers: UInt64
    public let capturedSamples: UInt64
    public let approximateBytesCaptured: UInt64

    public init(
        capturedAt: Date,
        sampleRate: Int,
        channelCount: Int,
        capturedBuffers: UInt64,
        capturedSamples: UInt64,
        approximateBytesCaptured: UInt64
    ) {
        self.capturedAt = capturedAt
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.capturedBuffers = capturedBuffers
        self.capturedSamples = capturedSamples
        self.approximateBytesCaptured = approximateBytesCaptured
    }
}

public struct SystemAudioStatus: Codable, Equatable, Sendable {
    public let captureState: SystemAudioCaptureState
    public let transportState: SystemAudioTransportState
    public let isAvailable: Bool
    public let isAllowedByHost: Bool
    public let stats: SystemAudioStats?
    public let lastError: String?

    public init(
        captureState: SystemAudioCaptureState,
        transportState: SystemAudioTransportState = .notImplemented,
        isAvailable: Bool,
        isAllowedByHost: Bool,
        stats: SystemAudioStats? = nil,
        lastError: String? = nil
    ) {
        self.captureState = captureState
        self.transportState = transportState
        self.isAvailable = isAvailable
        self.isAllowedByHost = isAllowedByHost
        self.stats = stats
        self.lastError = lastError
    }

    public static let unavailable = SystemAudioStatus(
        captureState: .unavailable,
        isAvailable: false,
        isAllowedByHost: false
    )

    public static func disabled(isAvailable: Bool = true) -> SystemAudioStatus {
        SystemAudioStatus(
            captureState: isAvailable ? .disabled : .unavailable,
            isAvailable: isAvailable,
            isAllowedByHost: false
        )
    }

    public static func ready(isAvailable: Bool = true) -> SystemAudioStatus {
        SystemAudioStatus(
            captureState: isAvailable ? .ready : .unavailable,
            transportState: .hostCaptureOnly,
            isAvailable: isAvailable,
            isAllowedByHost: isAvailable
        )
    }

    public static func failed(
        isAllowedByHost: Bool,
        message: String,
        stats: SystemAudioStats? = nil
    ) -> SystemAudioStatus {
        SystemAudioStatus(
            captureState: .failed,
            transportState: .hostCaptureOnly,
            isAvailable: true,
            isAllowedByHost: isAllowedByHost,
            stats: stats,
            lastError: message
        )
    }

    public var isCapturing: Bool {
        captureState == .capturing
    }
}
