import CoreGraphics
import CoreVideo
@preconcurrency import ScreenCaptureKit
import MiradorCore

actor ScreenCaptureService {
    private struct StreamKey: Equatable {
        let displayID: UInt32
        let resolution: StreamResolutionPreset
        let frameRate: StreamFrameRatePreset
        let viewport: PreviewViewport
    }

    private final class ActiveScreenStream {
        let stream: SCStream
        let output: ScreenCaptureStreamOutput
        let sampleQueue: DispatchQueue
        var key: StreamKey

        init(
            stream: SCStream,
            output: ScreenCaptureStreamOutput,
            sampleQueue: DispatchQueue,
            key: StreamKey
        ) {
            self.stream = stream
            self.output = output
            self.sampleQueue = sampleQueue
            self.key = key
        }
    }

    private let frameBuffer = ScreenCaptureFrameBuffer()
    private let jpegEncoder = PreviewJPEGEncoder()
    private var shareableDisplays: [SCDisplay] = []
    private var activeStream: ActiveScreenStream?
    private var lastDeliveredFrameNumber: UInt64 = 0

    nonisolated var permissionSummary: String {
        CGPreflightScreenCaptureAccess() ? "Granted" : "Not granted"
    }

    nonisolated func requestPermission() {
        _ = CGRequestScreenCaptureAccess()
    }

    func loadDisplays() async throws -> [CapturedDisplay] {
        let displays = try await refreshShareableDisplays()
        MiradorHostLog.stream.info(
            "loaded displays count=\(displays.count, privacy: .public) primary=\(CGMainDisplayID(), privacy: .public)"
        )

        return displays.map { display in
            CapturedDisplay(
                id: display.displayID,
                width: display.width,
                height: display.height
            )
        }
    }

    func capturePreviewFrame(
        sequence: UInt64,
        displayID: UInt32?,
        videoSettings: StreamVideoSettings,
        viewport: PreviewViewport
    ) async throws -> CapturedPreviewFrame {
        let sourceFrame = try await captureSourceFrame(
            displayID: displayID,
            videoSettings: videoSettings,
            viewport: viewport
        )
        let encodeStartedAt = Date()
        let jpegData = try jpegEncoder.jpegData(from: sourceFrame.pixelBuffer, settings: videoSettings)
        let encodeDuration = Date().timeIntervalSince(encodeStartedAt) * 1_000

        let frame = PreviewFrame(
            sequence: sequence,
            capturedAt: sourceFrame.capturedAt,
            width: sourceFrame.width,
            height: sourceFrame.height,
            displayID: sourceFrame.displayID,
            qualityProfile: videoSettings.qualityProfile,
            viewport: viewport,
            sourceFrameNumber: sourceFrame.sourceFrameNumber,
            sourceFramesDropped: sourceFrame.sourceFramesDropped,
            jpegData: jpegData
        )
        return CapturedPreviewFrame(
            frame: frame,
            waitDurationMilliseconds: sourceFrame.waitDurationMilliseconds,
            encodeDurationMilliseconds: encodeDuration
        )
    }

    func captureSourceFrame(
        displayID: UInt32?,
        videoSettings: StreamVideoSettings,
        viewport: PreviewViewport,
        repeatsLatestFrame: Bool = false
    ) async throws -> CapturedSourceFrame {
        let display = try await shareableDisplay(displayID: displayID)
        try await prepareStream(for: display, videoSettings: videoSettings, viewport: viewport)

        let previousFrameNumber = lastDeliveredFrameNumber
        let waitStartedAt = Date()
        let sourceFrame = try await nextSourceFrame(
            after: previousFrameNumber,
            repeatsLatestFrame: repeatsLatestFrame
        )
        let waitDuration = Date().timeIntervalSince(waitStartedAt) * 1_000
        if !sourceFrame.isRepeated {
            lastDeliveredFrameNumber = sourceFrame.frame.number
        }

        return CapturedSourceFrame(
            pixelBuffer: sourceFrame.frame.pixelBuffer,
            capturedAt: sourceFrame.capturedAt,
            width: CVPixelBufferGetWidth(sourceFrame.frame.pixelBuffer),
            height: CVPixelBufferGetHeight(sourceFrame.frame.pixelBuffer),
            displayID: display.displayID,
            qualityProfile: videoSettings.qualityProfile,
            viewport: viewport,
            sourceFrameNumber: sourceFrame.frame.number,
            sourceFramesDropped: sourceFrame.isRepeated
                ? 0
                : max(0, Int(sourceFrame.frame.number - previousFrameNumber - 1)),
            isRepeatedSourceFrame: sourceFrame.isRepeated,
            waitDurationMilliseconds: waitDuration
        )
    }

    private func nextSourceFrame(
        after previousFrameNumber: UInt64,
        repeatsLatestFrame: Bool
    ) async throws -> DeliveredSourceFrame {
        if repeatsLatestFrame, let latestFrame = frameBuffer.latestPublishedFrame() {
            let isRepeated = latestFrame.number <= previousFrameNumber
            return DeliveredSourceFrame(
                frame: latestFrame,
                capturedAt: Date(),
                isRepeated: isRepeated
            )
        }

        let frame = try await frameBuffer.nextFrame(after: previousFrameNumber)
        return DeliveredSourceFrame(
            frame: frame,
            capturedAt: repeatsLatestFrame ? Date() : frame.capturedAt,
            isRepeated: false
        )
    }

    func stopCapture() async {
        await stopActiveStream(reason: "preview stopped")
    }

    private func prepareStream(
        for display: SCDisplay,
        videoSettings: StreamVideoSettings,
        viewport: PreviewViewport
    ) async throws {
        let key = StreamKey(
            displayID: display.displayID,
            resolution: videoSettings.resolution,
            frameRate: videoSettings.frameRate,
            viewport: viewport
        )
        let configuration = previewConfiguration(
            for: display,
            videoSettings: videoSettings,
            viewport: viewport
        )

        if let activeStream, activeStream.key.displayID == display.displayID {
            guard activeStream.key != key else { return }
            try await activeStream.stream.updateConfiguration(configuration)
            activeStream.key = key
            MiradorHostLog.stream.debug(
                "screen stream updated display=\(display.displayID, privacy: .public) settings=\(videoSettings.summary, privacy: .public) viewport=\(viewport.logSummary, privacy: .public)"
            )
            return
        }

        await stopActiveStream(reason: "display changed")
        frameBuffer.reset()
        lastDeliveredFrameNumber = 0

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let output = ScreenCaptureStreamOutput(frameBuffer: frameBuffer)
        let sampleQueue = DispatchQueue(
            label: "com.stevenacz.mirador.host.screen-stream",
            qos: .userInteractive
        )
        let stream = SCStream(filter: filter, configuration: configuration, delegate: nil)
        try stream.addStreamOutput(output, type: .screen, sampleHandlerQueue: sampleQueue)
        try await stream.startCapture()
        activeStream = ActiveScreenStream(
            stream: stream,
            output: output,
            sampleQueue: sampleQueue,
            key: key
        )
        MiradorHostLog.stream.info(
            "screen stream started display=\(display.displayID, privacy: .public) settings=\(videoSettings.summary, privacy: .public) size=\(configuration.width, privacy: .public)x\(configuration.height, privacy: .public) viewport=\(viewport.logSummary, privacy: .public)"
        )
    }

    private func stopActiveStream(reason: String) async {
        guard let activeStream else { return }
        self.activeStream = nil
        frameBuffer.reset()
        lastDeliveredFrameNumber = 0
        do {
            try await activeStream.stream.stopCapture()
            MiradorHostLog.stream.info("screen stream stopped reason=\(reason, privacy: .public)")
        } catch {
            MiradorHostLog.stream.error(
                "screen stream stop failed reason=\(reason, privacy: .public) error=\(error.localizedDescription, privacy: .public)"
            )
        }
    }

    private func shareableDisplay(displayID: UInt32?) async throws -> SCDisplay {
        if let display = selectedDisplay(in: shareableDisplays, displayID: displayID) {
            return display
        }

        let displays = try await refreshShareableDisplays()
        if let display = selectedDisplay(in: displays, displayID: displayID) {
            return display
        }

        MiradorHostLog.stream.error(
            "requested display unavailable display=\(String(describing: displayID), privacy: .public) available=\(displays.map(\.displayID).description, privacy: .public)"
        )
        throw ScreenCaptureError.noDisplayAvailable
    }

    private func refreshShareableDisplays() async throws -> [SCDisplay] {
        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )
        shareableDisplays = content.displays
        return content.displays
    }

    private func selectedDisplay(in displays: [SCDisplay], displayID: UInt32?) -> SCDisplay? {
        if let displayID {
            return displays.first { $0.displayID == displayID }
        }

        let primaryDisplayID = CGMainDisplayID()
        return displays.first { $0.displayID == primaryDisplayID } ?? displays.first
    }

    private func previewConfiguration(
        for display: SCDisplay,
        videoSettings: StreamVideoSettings,
        viewport: PreviewViewport
    ) -> SCStreamConfiguration {
        let cropWidth = max(1, Int(Double(display.width) * viewport.normalizedWidth))
        let cropHeight = max(1, Int(Double(display.height) * viewport.normalizedHeight))
        let scale = min(1, Double(videoSettings.resolution.maxPixelHeight) / Double(cropHeight))
        let configuration = SCStreamConfiguration()
        configuration.width = max(1, Int(Double(cropWidth) * scale))
        configuration.height = max(1, Int(Double(cropHeight) * scale))
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(videoSettings.targetFrameRate))
        configuration.queueDepth = 3
        configuration.showsCursor = true
        configuration.scalesToFit = true
        configuration.capturesAudio = false
        if !viewport.isFull {
            configuration.sourceRect = sourceRect(for: display, viewport: viewport)
        }
        return configuration
    }

    private func sourceRect(for display: SCDisplay, viewport: PreviewViewport) -> CGRect {
        let bounds = CGDisplayBounds(display.displayID)
        let width = bounds.isEmpty ? CGFloat(display.width) : bounds.width
        let height = bounds.isEmpty ? CGFloat(display.height) : bounds.height
        return CGRect(
            x: width * viewport.normalizedX,
            y: height * viewport.normalizedY,
            width: width * viewport.normalizedWidth,
            height: height * viewport.normalizedHeight
        )
    }

}

private struct DeliveredSourceFrame {
    let frame: ScreenCaptureSourceFrame
    let capturedAt: Date
    let isRepeated: Bool
}
