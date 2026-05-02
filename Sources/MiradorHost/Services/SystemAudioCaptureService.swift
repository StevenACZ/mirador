import CoreMedia
import Foundation
@preconcurrency import ScreenCaptureKit
import MiradorCore

actor SystemAudioCaptureService {
    private let audioQueue = DispatchQueue(label: "Mirador.SystemAudioCapture")
    private var stream: SCStream?
    private var streamOutput: SystemAudioStreamOutput?
    private var stats: SystemAudioStats?
    private var lastError: String?

    nonisolated var isAvailable: Bool {
        if #available(macOS 13.0, *) {
            true
        } else {
            false
        }
    }

    func start(displayID: UInt32?) async -> SystemAudioStatus {
        guard isAvailable else { return .unavailable }
        guard stream == nil else { return status(isAllowedByHost: true) }

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )
            guard let display = selectedDisplay(in: content.displays, displayID: displayID) else {
                throw ScreenCaptureError.noDisplayAvailable
            }

            let configuration = audioConfiguration()
            let filter = SCContentFilter(display: display, excludingWindows: [])
            let output = SystemAudioStreamOutput { [weak self] observation in
                Task { await self?.record(observation) }
            }
            let stream = SCStream(filter: filter, configuration: configuration, delegate: nil)
            try stream.addStreamOutput(output, type: .audio, sampleHandlerQueue: audioQueue)
            try await stream.startCapture()

            self.stream = stream
            streamOutput = output
            stats = SystemAudioStats(
                capturedAt: Date(),
                sampleRate: configuration.sampleRate,
                channelCount: configuration.channelCount,
                capturedBuffers: 0,
                capturedSamples: 0,
                approximateBytesCaptured: 0
            )
            lastError = nil
            return status(isAllowedByHost: true)
        } catch {
            self.stream = nil
            streamOutput = nil
            lastError = error.localizedDescription
            return status(isAllowedByHost: true)
        }
    }

    func stop(isAllowedByHost: Bool) async -> SystemAudioStatus {
        if let stream {
            try? await stream.stopCapture()
        }
        stream = nil
        streamOutput = nil
        stats = nil
        lastError = nil
        return status(isAllowedByHost: isAllowedByHost)
    }

    func status(isAllowedByHost: Bool) -> SystemAudioStatus {
        guard isAvailable else { return .unavailable }
        if let lastError {
            return .failed(isAllowedByHost: isAllowedByHost, message: lastError, stats: stats)
        }
        guard stream != nil else {
            return isAllowedByHost ? .ready(isAvailable: true) : .disabled(isAvailable: true)
        }
        return SystemAudioStatus(
            captureState: .capturing,
            transportState: .hostCaptureOnly,
            isAvailable: true,
            isAllowedByHost: isAllowedByHost,
            stats: stats
        )
    }

    private func record(_ observation: SystemAudioSampleObservation) {
        let previous = stats
        stats = SystemAudioStats(
            capturedAt: Date(),
            sampleRate: observation.sampleRate ?? previous?.sampleRate ?? 48_000,
            channelCount: observation.channelCount ?? previous?.channelCount ?? 2,
            capturedBuffers: (previous?.capturedBuffers ?? 0) + 1,
            capturedSamples: (previous?.capturedSamples ?? 0) + observation.sampleCount,
            approximateBytesCaptured: (previous?.approximateBytesCaptured ?? 0) + observation.byteCount
        )
        lastError = nil
    }

    private func selectedDisplay(in displays: [SCDisplay], displayID: UInt32?) -> SCDisplay? {
        guard let displayID else { return displays.first }
        return displays.first { $0.displayID == displayID } ?? displays.first
    }

    private func audioConfiguration() -> SCStreamConfiguration {
        let configuration = SCStreamConfiguration()
        configuration.width = 2
        configuration.height = 2
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 1)
        configuration.showsCursor = false
        configuration.capturesAudio = true
        configuration.sampleRate = 48_000
        configuration.channelCount = 2
        configuration.excludesCurrentProcessAudio = true
        return configuration
    }
}
