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
    public var authenticatedSessions = 0
    public var activeAuthenticatedSessions = 0
    public var streamedFrames = 0
    public var isRemoteControlEnabled = false
    public var remoteControlStatus = "Control disabled"
    public var receivedInputEvents = 0
    public var appliedInputEvents = 0
    public var displays: [CapturedDisplay] = []
    public var selectedDisplayID: UInt32?
    public var videoSettings = StreamVideoSettings()
    public var qualityProfile: StreamQualityProfile = StreamVideoSettings().qualityProfile
    public var previewViewport: PreviewViewport = .full
    public var streamStats: StreamStats?
    public var trustedClients: [TrustedClient] = []
    public var isSystemAudioAllowed = false
    public var systemAudioStatus = SystemAudioStatus.disabled()

    @ObservationIgnored let advertiser = BonjourHostAdvertiser()
    @ObservationIgnored let captureService = ScreenCaptureService()
    @ObservationIgnored let videoEncoder = VideoToolboxEncoder()
    @ObservationIgnored let systemAudioCaptureService = SystemAudioCaptureService()
    @ObservationIgnored let inputControlService = InputControlService()
    @ObservationIgnored var previewTask: Task<Void, Never>?
    @ObservationIgnored var nextFrameSequence: UInt64 = 0
    @ObservationIgnored var activePreviewSessionID: UUID?
    @ObservationIgnored var metricsTracker = StreamMetricsTracker()
    @ObservationIgnored var skippedPreviewFrames = 0
    @ObservationIgnored var streamedFrameTotal = 0
    @ObservationIgnored var lastStreamUIUpdate = Date.distantPast
    @ObservationIgnored var receivedInputEventTotal = 0
    @ObservationIgnored var appliedInputEventTotal = 0
    @ObservationIgnored var lastInputUIUpdate = Date.distantPast

    public init() {
        permissionStatus = captureService.permissionSummary
        systemAudioStatus = SystemAudioStatus.disabled(isAvailable: systemAudioCaptureService.isAvailable)
        configureAdvertiserCallbacks()
    }

    public func toggleAdvertising() {
        isAdvertising ? stopAdvertising() : startAdvertising()
    }

    public func startAdvertising() {
        do {
            try advertiser.start()
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

    public func refreshPermissionStatus() {
        permissionStatus = captureService.permissionSummary
    }

    public func requestScreenCapturePermission() {
        captureService.requestPermission()
        refreshPermissionStatus()
    }

    public func revokeClient(id: UUID) {
        advertiser.cancelSession(id: id)
        markTrustedClient(id: id, isActive: false)
        if activePreviewSessionID == id {
            stopPreview()
        }
    }

    public func forgetInactiveTrustedClients() {
        trustedClients.removeAll { !$0.isActive }
    }
}
