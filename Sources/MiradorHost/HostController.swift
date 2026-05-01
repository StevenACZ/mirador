import Foundation
import Observation
import MiradorCore

@MainActor
@Observable
final class HostController {
    var isAdvertising = false
    var networkStatus = "Idle"
    var captureStatus = "Idle"
    var permissionStatus = "Unknown"
    var sessionPIN = SessionPIN.generate()
    var authenticatedSessions = 0
    var displays: [CapturedDisplay] = []

    @ObservationIgnored private let advertiser = BonjourHostAdvertiser()
    @ObservationIgnored private let captureService = ScreenCaptureService()

    init() {
        permissionStatus = captureService.permissionSummary

        advertiser.onStateChange = { [weak self] status in
            Task { @MainActor in
                self?.networkStatus = status
                self?.isAdvertising = status == "Listening"
            }
        }

        advertiser.onAuthenticated = { [weak self] in
            Task { @MainActor in
                await self?.startPreviewAfterAuthentication()
            }
        }
    }

    func toggleAdvertising() {
        isAdvertising ? stopAdvertising() : startAdvertising()
    }

    func startAdvertising() {
        do {
            try advertiser.start(pin: sessionPIN)
            isAdvertising = true
            networkStatus = "Listening"
        } catch {
            networkStatus = "Failed: \(error.localizedDescription)"
            isAdvertising = false
        }
    }

    func stopAdvertising() {
        advertiser.stop()
        isAdvertising = false
        networkStatus = "Idle"
    }

    func rotatePIN() {
        sessionPIN = SessionPIN.generate()
        if isAdvertising {
            stopAdvertising()
            startAdvertising()
        }
    }

    func refreshPermissionStatus() {
        permissionStatus = captureService.permissionSummary
    }

    func requestScreenCapturePermission() {
        captureService.requestPermission()
        refreshPermissionStatus()
    }

    private func startPreviewAfterAuthentication() async {
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
    }
}
