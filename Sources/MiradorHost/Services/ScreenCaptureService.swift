import CoreGraphics
import Foundation
import ImageIO
import ScreenCaptureKit
import UniformTypeIdentifiers
import MiradorCore

public struct CapturedDisplay: Identifiable, Equatable, Sendable {
    public let id: UInt32
    public let width: Int
    public let height: Int

    public var title: String {
        "Display \(id)"
    }
}

actor ScreenCaptureService {
    nonisolated var permissionSummary: String {
        CGPreflightScreenCaptureAccess() ? "Granted" : "Not granted"
    }

    nonisolated func requestPermission() {
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

    func capturePreviewFrame(sequence: UInt64) async throws -> PreviewFrame {
        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )
        guard let display = content.displays.first else {
            throw ScreenCaptureError.noDisplayAvailable
        }

        let configuration = previewConfiguration(for: display)
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let image = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: configuration
        )
        let jpegData = try Self.jpegData(from: image, quality: MiradorConstants.previewJPEGQuality)

        return PreviewFrame(
            sequence: sequence,
            capturedAt: Date(),
            width: image.width,
            height: image.height,
            jpegData: jpegData
        )
    }

    private func previewConfiguration(for display: SCDisplay) -> SCStreamConfiguration {
        let scale = min(1, Double(MiradorConstants.previewMaxPixelWidth) / Double(display.width))
        let configuration = SCStreamConfiguration()
        configuration.width = max(1, Int(Double(display.width) * scale))
        configuration.height = max(1, Int(Double(display.height) * scale))
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(MiradorConstants.mvpFrameRate))
        configuration.showsCursor = true
        configuration.scalesToFit = true
        configuration.capturesAudio = false
        return configuration
    }

    private static func jpegData(from image: CGImage, quality: Double) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            throw ScreenCaptureError.jpegEncodingFailed
        }

        let options = [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary
        CGImageDestinationAddImage(destination, image, options)
        guard CGImageDestinationFinalize(destination) else {
            throw ScreenCaptureError.jpegEncodingFailed
        }

        return data as Data
    }
}

private enum ScreenCaptureError: LocalizedError {
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
