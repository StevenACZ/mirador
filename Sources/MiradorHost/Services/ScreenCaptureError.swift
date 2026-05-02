import Foundation

enum ScreenCaptureError: LocalizedError {
    case noDisplayAvailable
    case jpegEncodingFailed

    var errorDescription: String? {
        switch self {
        case .noDisplayAvailable:
            "No display is available for capture."
        case .jpegEncodingFailed:
            "The captured frame could not be encoded as JPEG."
        }
    }
}
