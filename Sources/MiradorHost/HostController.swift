import Foundation
import Observation
import MiradorCore

@MainActor
@Observable
public final class HostController {
    public var isAdvertising = false
    public var networkStatus = "Idle"
    public var captureStatus = "Idle"
    public var permissionStatus = "Unknown"
    public var sessionPIN = SessionPIN.generate()
    public var authenticatedSessions = 0
    public var streamedFrames = 0
    public var displays: [CapturedDisplay] = []

    @ObservationIgnored private let advertiser = BonjourHostAdvertiser()
    @ObservationIgnored private let captureService = ScreenCaptureService()
    @ObservationIgnored private var previewTask: Task<Void, Never>?
    @ObservationIgnored private var nextFrameSequence: UInt64 = 0

    public init() {
        permissionStatus = captureService.permissionSummary

        advertiser.onStateChange = { [weak self] status in
            Task { @MainActor in
                self?.networkStatus = status
                self?.isAdvertising = status == "Listening"
            }
        }

        advertiser.onAuthenticated = { [weak self] session in
            Task { @MainActor in
                await self?.startPreviewAfterAuthentication(for: session)
            }
        }

        advertiser.onPreviewStopped = { [weak self] in
            Task { @MainActor in
                self?.stopPreview()
            }
        }

        advertiser.onConnectionClosed = { [weak self] _ in
            Task { @MainActor in
                self?.stopPreview()
            }
        }
    }

    public func toggleAdvertising() {
        isAdvertising ? stopAdvertising() : startAdvertising()
    }

    public func startAdvertising() {
        do {
            try advertiser.start(pin: sessionPIN)
            isAdvertising = true
            networkStatus = "Listening"
        } catch {
            networkStatus = "Failed: \(error.localizedDescription)"
            isAdvertising = false
        }
    }

    public func stopAdvertising() {
        stopPreview()
        advertiser.stop()
        isAdvertising = false
        networkStatus = "Idle"
    }

    public func rotatePIN() {
        sessionPIN = SessionPIN.generate()
        if isAdvertising {
            stopAdvertising()
            startAdvertising()
        }
    }

    public func refreshPermissionStatus() {
        permissionStatus = captureService.permissionSummary
    }

    public func requestScreenCapturePermission() {
        captureService.requestPermission()
        refreshPermissionStatus()
    }

    private func startPreviewAfterAuthentication(for session: HostClientSession) async {
        authenticatedSessions += 1
        captureStatus = "Preparing capture"

        do {
            displays = try await captureService.loadDisplays()
            captureStatus = displays.isEmpty
                ? "No displays available"
                : "Ready for MVP1 stream at \(MiradorConstants.mvpFrameRate) FPS"
        } catch {
            captureStatus = "Capture failed: \(error.localizedDescription)"
        }

        previewTask?.cancel()
        previewTask = Task { [weak self, weak session] in
            guard let self, let session else { return }
            await self.streamPreviewFrames(to: session)
        }
    }

    private func streamPreviewFrames(to session: HostClientSession) async {
        while !Task.isCancelled {
            do {
                let sequence = nextFrameSequence
                nextFrameSequence += 1
                let frame = try await captureService.capturePreviewFrame(sequence: sequence)
                session.sendPreviewFrame(frame)
                streamedFrames += 1
                captureStatus = "Streaming frame \(streamedFrames) at \(MiradorConstants.mvpFrameRate) FPS target"
                try await Task.sleep(nanoseconds: 1_000_000_000 / UInt64(MiradorConstants.mvpFrameRate))
            } catch is CancellationError {
                break
            } catch {
                captureStatus = "Preview failed: \(error.localizedDescription)"
                break
            }
        }
    }

    private func stopPreview() {
        previewTask?.cancel()
        previewTask = nil
        if streamedFrames > 0 {
            captureStatus = "Preview stopped after \(streamedFrames) frames"
        }
    }
}
