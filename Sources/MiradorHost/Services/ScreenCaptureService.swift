import CoreGraphics
import Foundation
import ScreenCaptureKit
import MiradorCore

struct CapturedDisplay: Identifiable, Equatable {
    let id: UInt32
    let width: Int
    let height: Int

    var title: String {
        "Display \(id)"
    }
}

@MainActor
final class ScreenCaptureService {
    var permissionSummary: String {
        CGPreflightScreenCaptureAccess() ? "Granted" : "Not granted"
    }

    func requestPermission() {
        _ = CGRequestScreenCaptureAccess()
    }

    func loadDisplays() async throws -> [CapturedDisplay] {
        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )

        return content.displays.map { display in
            CapturedDisplay(
                id: display.displayID,
                width: display.width,
                height: display.height
            )
        }
    }
}
