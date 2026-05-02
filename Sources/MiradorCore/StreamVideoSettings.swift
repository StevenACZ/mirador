import Foundation

public enum StreamResolutionPreset: String, Codable, CaseIterable, Identifiable, Sendable {
    case p720
    case p1080
    case p1440
    case p2160

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .p720:
            "720p"
        case .p1080:
            "1080p"
        case .p1440:
            "2K"
        case .p2160:
            "4K"
        }
    }

    public var maxPixelHeight: Int {
        switch self {
        case .p720:
            720
        case .p1080:
            1_080
        case .p1440:
            1_440
        case .p2160:
            2_160
        }
    }

    public var approximateMaxPixelWidth: Int {
        Int((Double(maxPixelHeight) * 16.0 / 9.0).rounded())
    }
}

public enum StreamFrameRatePreset: Int, Codable, CaseIterable, Identifiable, Sendable {
    case fps30 = 30
    case fps60 = 60

    public var id: Int { rawValue }

    public var displayName: String {
        "\(rawValue) FPS"
    }
}

public struct StreamVideoSettings: Codable, Equatable, Sendable {
    public static let minimumBitrateMegabitsPerSecond = 0.5
    public static let maximumBitrateMegabitsPerSecond = 150.0

    public let resolution: StreamResolutionPreset
    public let frameRate: StreamFrameRatePreset
    public let bitrateMegabitsPerSecond: Double

    public init(
        resolution: StreamResolutionPreset = .p720,
        frameRate: StreamFrameRatePreset = .fps60,
        bitrateMegabitsPerSecond: Double = 8
    ) {
        self.resolution = resolution
        self.frameRate = frameRate
        self.bitrateMegabitsPerSecond = Self.clampedBitrate(bitrateMegabitsPerSecond)
    }

    public init(qualityProfile: StreamQualityProfile) {
        switch qualityProfile {
        case .balanced:
            self.init(resolution: .p1080, frameRate: .fps30, bitrateMegabitsPerSecond: 12)
        case .smooth:
            self.init(resolution: .p720, frameRate: .fps60, bitrateMegabitsPerSecond: 8)
        case .sharp:
            self.init(resolution: .p1440, frameRate: .fps30, bitrateMegabitsPerSecond: 25)
        }
    }

    public var targetFrameRate: Int {
        frameRate.rawValue
    }

    public var targetBitrateKilobitsPerSecond: Double {
        bitrateMegabitsPerSecond * 1_000
    }

    public var targetBytesPerFrame: Int {
        let bitsPerFrame = bitrateMegabitsPerSecond * 1_000_000 / Double(max(targetFrameRate, 1))
        return max(1, Int(bitsPerFrame / 8))
    }

    public var qualityProfile: StreamQualityProfile {
        if frameRate == .fps60 {
            return .smooth
        }
        return resolution == .p1440 || resolution == .p2160 ? .sharp : .balanced
    }

    public var estimatedJPEGQuality: Double {
        let pixelCount = Double(resolution.maxPixelHeight * resolution.approximateMaxPixelWidth)
        let bitsPerFrame = bitrateMegabitsPerSecond * 1_000_000 / Double(max(targetFrameRate, 1))
        let bitsPerPixel = bitsPerFrame / max(pixelCount, 1)
        let normalized = Self.normalizedLogScale(
            bitsPerPixel,
            lowerBound: 0.04,
            upperBound: 0.8
        )
        return 0.18 + normalized * 0.72
    }

    public var summary: String {
        "\(resolution.displayName) / \(frameRate.displayName) / \(Self.bitrateLabel(bitrateMegabitsPerSecond))"
    }

    public static func bitrateLabel(_ bitrate: Double) -> String {
        if bitrate < 10 {
            return String(format: "%.1f Mbps", bitrate)
        }
        return String(format: "%.0f Mbps", bitrate)
    }

    private static func clampedBitrate(_ bitrate: Double) -> Double {
        min(
            max(bitrate, minimumBitrateMegabitsPerSecond),
            maximumBitrateMegabitsPerSecond
        )
    }

    private static func normalizedLogScale(
        _ value: Double,
        lowerBound: Double,
        upperBound: Double
    ) -> Double {
        let clamped = min(max(value, lowerBound), upperBound)
        let lower = log2(lowerBound)
        let upper = log2(upperBound)
        return (log2(clamped) - lower) / max(upper - lower, 0.001)
    }
}
