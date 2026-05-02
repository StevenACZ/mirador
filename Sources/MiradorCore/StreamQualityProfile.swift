import Foundation

public enum StreamQualityProfile: String, Codable, CaseIterable, Identifiable, Sendable {
    case balanced
    case smooth
    case sharp

    public var id: String {
        rawValue
    }

    public var targetFrameRate: Int {
        videoSettings.targetFrameRate
    }

    public var maxPixelWidth: Int {
        videoSettings.resolution.approximateMaxPixelWidth
    }

    public var jpegQuality: Double {
        videoSettings.estimatedJPEGQuality
    }

    public var videoSettings: StreamVideoSettings {
        StreamVideoSettings(qualityProfile: self)
    }
}
