import Foundation

public enum StreamCodec: String, Codable, CaseIterable, Identifiable, Sendable {
    case jpeg
    case h264
    case hevc

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .jpeg:
            "JPEG"
        case .h264:
            "H.264"
        case .hevc:
            "HEVC"
        }
    }

    public var isVideoToolboxCodec: Bool {
        self == .h264 || self == .hevc
    }
}
