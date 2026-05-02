import CoreGraphics
import CoreImage
import CoreVideo
import ImageIO
import MiradorCore

struct PreviewJPEGEncoder {
    private static let maximumAdaptiveAttempts = 6

    private let imageContext = CIContext()
    private let outputColorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()

    func jpegData(from pixelBuffer: CVPixelBuffer, settings: StreamVideoSettings) throws -> Data {
        var quality = settings.estimatedJPEGQuality

        for attempt in 1...Self.maximumAdaptiveAttempts {
            let data = try jpegData(from: pixelBuffer, quality: quality)
            guard data.count > StreamVideoSettings.maximumJPEGPayloadBytes else {
                if attempt > 1 {
                    MiradorHostLog.stream.debug(
                        "jpeg quality adapted attempts=\(attempt, privacy: .public) quality=\(quality, privacy: .public) bytes=\(data.count, privacy: .public)"
                    )
                }
                return data
            }

            let nextQuality = adaptedQuality(after: quality, byteCount: data.count)
            guard nextQuality < quality else { break }
            quality = nextQuality
        }

        MiradorHostLog.stream.error(
            "jpeg frame exceeds transport cap capBytes=\(StreamVideoSettings.maximumJPEGPayloadBytes, privacy: .public)"
        )
        throw ScreenCaptureError.jpegEncodingFailed
    }

    private func adaptedQuality(after quality: Double, byteCount: Int) -> Double {
        let ratio = Double(StreamVideoSettings.maximumJPEGPayloadBytes) / Double(max(byteCount, 1))
        let multiplier = min(max(ratio * 0.9, 0.45), 0.85)
        let scaledQuality = quality * multiplier
        let steppedQuality = quality - 0.08
        return max(
            StreamVideoSettings.minimumTransportJPEGQuality,
            min(scaledQuality, steppedQuality)
        )
    }

    private func jpegData(from pixelBuffer: CVPixelBuffer, quality: Double) throws -> Data {
        let image = CIImage(cvPixelBuffer: pixelBuffer)
        let qualityKey = CIImageRepresentationOption(
            rawValue: kCGImageDestinationLossyCompressionQuality as String
        )
        guard let data = imageContext.jpegRepresentation(
            of: image,
            colorSpace: outputColorSpace,
            options: [qualityKey: quality]
        ) else {
            throw ScreenCaptureError.jpegEncodingFailed
        }
        return data
    }
}
