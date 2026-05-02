import Foundation
import Testing
@testable import MiradorCore

@Suite("Stream contracts")
struct StreamContractsTests {
    @Test("Video settings map to local LAN defaults")
    func videoSettings() {
        let settings = StreamVideoSettings(
            resolution: .p720,
            frameRate: .fps60,
            bitrateMegabitsPerSecond: 8
        )

        #expect(settings.targetFrameRate == 60)
        #expect(settings.resolution.maxPixelHeight == 720)
        #expect(settings.targetBitrateKilobitsPerSecond == 8_000)
        #expect(settings.estimatedJPEGQuality > 0.18)
        #expect(settings.estimatedJPEGQuality < 0.90)
        #expect(
            StreamVideoSettings(bitrateMegabitsPerSecond: 200).bitrateMegabitsPerSecond
                == StreamVideoSettings.maximumBitrateMegabitsPerSecond
        )
        #expect(StreamVideoSettings.maximumJPEGPayloadBytes < LengthPrefixedMessageCodec.maximumPayloadLength)
        #expect(StreamQualityProfile.sharp.videoSettings.resolution == .p1440)
    }

    @Test("Decoded video settings are clamped")
    func decodedVideoSettingsAreClamped() throws {
        let data = Data(
            #"{"resolution":"p2160","frameRate":60,"bitrateMegabitsPerSecond":999}"#.utf8
        )
        let settings = try JSONDecoder.mirador.decode(StreamVideoSettings.self, from: data)

        #expect(settings.resolution == .p2160)
        #expect(settings.frameRate == .fps60)
        #expect(settings.bitrateMegabitsPerSecond == StreamVideoSettings.maximumBitrateMegabitsPerSecond)
    }

    @Test("Display selection preserves custom video settings")
    func displaySelectionVideoSettings() throws {
        let settings = StreamVideoSettings(
            resolution: .p1440,
            frameRate: .fps60,
            bitrateMegabitsPerSecond: 35
        )
        let selection = DisplaySelection(displayID: 3, videoSettings: settings, viewport: .full)

        #expect(selection.videoSettings == settings)
        #expect(selection.qualityProfile == .smooth)

        let data = try JSONEncoder.mirador.encode(selection)
        let decoded = try JSONDecoder.mirador.decode(DisplaySelection.self, from: data)
        #expect(decoded == selection)
    }

    @Test("Preview viewport validates crop bounds")
    func viewportValidation() {
        let centered = PreviewViewport.centered(zoomScale: 2)
        #expect(centered.isValid)
        #expect(centered.zoomScale == 2)

        let cropped = PreviewViewport.cropped(zoomScale: 2, centerX: 0.9, centerY: 0.1)
        #expect(cropped.isValid)
        #expect(cropped.normalizedX == 0.5)
        #expect(cropped.normalizedY == 0)

        let invalid = PreviewViewport(
            normalizedX: 0.75,
            normalizedY: 0,
            normalizedWidth: 0.5,
            normalizedHeight: 1
        )
        #expect(invalid.isValid == false)
    }

    @Test("Round-trips stream stats messages")
    func statsRoundTrip() throws {
        let stats = StreamStats(
            capturedAt: Date(timeIntervalSince1970: 20),
            framesSent: 30,
            bytesSent: 900_000,
            effectiveFramesPerSecond: 29.8,
            bitrateKilobitsPerSecond: 720,
            lastFrameBytes: 30_000,
            captureDurationMilliseconds: 12,
            targetFrameRate: 30,
            qualityProfile: .balanced,
            displayID: 7
        )

        let message = SignalingMessage.streamStats(stats)
        let packet = try LengthPrefixedMessageCodec.encode(message)
        let payload = packet.dropFirst(LengthPrefixedMessageCodec.headerLength)
        let decoded = try LengthPrefixedMessageCodec.decode(SignalingMessage.self, from: Data(payload))
        #expect(decoded == message)
    }

    @Test("Round-trips host system audio status")
    func systemAudioStatusRoundTrip() throws {
        let audioStats = SystemAudioStats(
            capturedAt: Date(timeIntervalSince1970: 30),
            sampleRate: 48_000,
            channelCount: 2,
            capturedBuffers: 4,
            capturedSamples: 1_920,
            approximateBytesCaptured: 7_680
        )
        let audioStatus = SystemAudioStatus(
            captureState: .capturing,
            transportState: .hostCaptureOnly,
            isAvailable: true,
            isAllowedByHost: true,
            stats: audioStats
        )
        let status = HostStatus(
            hostName: "Test Mac",
            isCaptureActive: true,
            systemAudio: audioStatus
        )

        let message = SignalingMessage.hostStatus(status)
        let packet = try LengthPrefixedMessageCodec.encode(message)
        let payload = packet.dropFirst(LengthPrefixedMessageCodec.headerLength)
        let decoded = try LengthPrefixedMessageCodec.decode(SignalingMessage.self, from: Data(payload))
        #expect(decoded == message)
    }
}
