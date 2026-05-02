import Foundation
import MiradorCore

extension MiradorClientStore {
    public func updateSelectedDisplay(_ displayID: UInt32?) {
        selectedDisplayID = displayID
        MiradorClientLog.stream.info(
            "selected display changed display=\(String(describing: displayID), privacy: .public)"
        )
        sendStreamSelection()
    }

    public func updateQualityProfile(_ profile: StreamQualityProfile) {
        updateVideoSettings(StreamVideoSettings(qualityProfile: profile))
    }

    public func updateResolutionPreset(_ resolution: StreamResolutionPreset) {
        updateVideoSettings(
            StreamVideoSettings(
                resolution: resolution,
                frameRate: selectedVideoSettings.frameRate,
                bitrateMegabitsPerSecond: selectedVideoSettings.bitrateMegabitsPerSecond
            )
        )
    }

    public func updateFrameRatePreset(_ frameRate: StreamFrameRatePreset) {
        updateVideoSettings(
            StreamVideoSettings(
                resolution: selectedVideoSettings.resolution,
                frameRate: frameRate,
                bitrateMegabitsPerSecond: selectedVideoSettings.bitrateMegabitsPerSecond
            )
        )
    }

    public func updateBitrateMegabitsPerSecond(_ bitrate: Double) {
        updateVideoSettings(
            StreamVideoSettings(
                resolution: selectedVideoSettings.resolution,
                frameRate: selectedVideoSettings.frameRate,
                bitrateMegabitsPerSecond: bitrate
            )
        )
    }

    public func updateVideoSettings(_ settings: StreamVideoSettings) {
        selectedVideoSettings = settings
        MiradorClientLog.stream.info(
            "video settings changed settings=\(settings.summary, privacy: .public)"
        )
        sendStreamSelection()
    }

    public func updateZoomScale(_ scale: Double) {
        zoomScale = min(max(scale, 1), 4)
        if zoomScale <= 1.01 {
            viewportCenterX = 0.5
            viewportCenterY = 0.5
        }
        MiradorClientLog.stream.info(
            "zoom changed zoom=\(self.zoomScale, privacy: .public) centerX=\(self.viewportCenterX, privacy: .public) centerY=\(self.viewportCenterY, privacy: .public)"
        )
        sendStreamSelection()
    }

    public func updateViewport(zoomScale: Double, centerX: Double, centerY: Double) {
        self.zoomScale = min(max(zoomScale, 1), 4)
        let viewport = PreviewViewport.cropped(
            zoomScale: self.zoomScale,
            centerX: centerX,
            centerY: centerY
        )
        viewportCenterX = viewport.normalizedX + viewport.normalizedWidth / 2
        viewportCenterY = viewport.normalizedY + viewport.normalizedHeight / 2
        MiradorClientLog.stream.debug(
            "viewport changed zoom=\(self.zoomScale, privacy: .public) centerX=\(self.viewportCenterX, privacy: .public) centerY=\(self.viewportCenterY, privacy: .public)"
        )
        sendStreamSelection()
    }

    public func sendStreamSelection() {
        guard isAuthenticated, let connection else { return }

        let selection = DisplaySelection(
            displayID: selectedDisplayID,
            videoSettings: selectedVideoSettings,
            viewport: PreviewViewport.cropped(
                zoomScale: zoomScale,
                centerX: viewportCenterX,
                centerY: viewportCenterY
            )
        )
        MiradorClientLog.stream.debug(
            "request preview display=\(String(describing: self.selectedDisplayID), privacy: .public) settings=\(self.selectedVideoSettings.summary, privacy: .public) zoom=\(self.zoomScale, privacy: .public) centerX=\(self.viewportCenterX, privacy: .public) centerY=\(self.viewportCenterY, privacy: .public)"
        )
        connection.requestPreview(selection)
    }
}
