import Foundation
import MiradorCore

extension HostController {
    public func setSystemAudioAllowed(_ allowed: Bool) {
        guard isSystemAudioAllowed != allowed else { return }
        isSystemAudioAllowed = allowed
        Task { @MainActor in
            await self.updateSystemAudioCapture()
            self.sendHostStatusToActivePreview()
        }
    }

    var systemAudioSummary: String {
        switch systemAudioStatus.captureState {
        case .unavailable:
            "Unavailable"
        case .disabled:
            "Off"
        case .ready:
            "Ready after local session"
        case .capturing:
            systemAudioCaptureSummary
        case .failed:
            systemAudioStatus.lastError ?? "Failed"
        }
    }

    func updateSystemAudioCapture() async {
        if isSystemAudioAllowed, activePreviewSessionID != nil {
            systemAudioStatus = await systemAudioCaptureService.start(displayID: selectedDisplayID)
        } else {
            systemAudioStatus = await systemAudioCaptureService.stop(isAllowedByHost: isSystemAudioAllowed)
        }
    }

    func refreshSystemAudioStatus() async {
        systemAudioStatus = await systemAudioCaptureService.status(isAllowedByHost: isSystemAudioAllowed)
    }

    private func sendHostStatusToActivePreview() {
        guard
            let activePreviewSessionID,
            let session = advertiser.session(id: activePreviewSessionID)
        else {
            return
        }
        session.sendHostStatus(hostStatus(isCaptureActive: selectedDisplayID != nil))
    }

    private var systemAudioCaptureSummary: String {
        guard let stats = systemAudioStatus.stats, stats.capturedBuffers > 0 else {
            return "Starting"
        }
        let kilohertz = Double(stats.sampleRate) / 1_000
        return String(format: "%.0f kHz / %d ch", kilohertz, stats.channelCount)
    }
}
