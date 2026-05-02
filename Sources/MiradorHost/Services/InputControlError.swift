import Foundation

enum InputControlError: LocalizedError {
    case accessibilityNotGranted
    case displayUnavailable
    case eventCreationFailed
    case invalidLocation
    case invalidScroll
    case invalidShortcut

    var errorDescription: String? {
        switch self {
        case .accessibilityNotGranted:
            "Accessibility permission is required before Mirador can control the pointer."
        case .displayUnavailable:
            "The target display is not available for remote input."
        case .eventCreationFailed:
            "The pointer event could not be created."
        case .invalidLocation:
            "The remote input location is outside the preview bounds."
        case .invalidScroll:
            "The remote scroll request is invalid."
        case .invalidShortcut:
            "The remote shortcut request is invalid."
        }
    }
}
