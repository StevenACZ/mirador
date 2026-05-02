import Foundation
import MiradorCore

extension MiradorClientStore {
    func resetSessionState(clearSelectedHost: Bool) {
        if clearSelectedHost {
            selectedHost = nil
        }
        hostStatus = nil
        isAuthenticated = false
        availableDisplays = []
        latestFrame = nil
        latestVideoFrameInfo = nil
        receivedFrames = 0
        streamStats = nil
        lastFrameLatencyMilliseconds = nil
        flushVideoRenderers()
        systemAudioStatus = .unavailable
        isPreviewActive = false
        remoteControlStatus = "Control disabled"
        sentInputEvents = 0
        sentInputEventTotal = 0
        lastPointerInputUIUpdate = .distantPast
        isControlModeEnabled = false
        zoomScale = 1.0
        viewportCenterX = 0.5
        viewportCenterY = 0.5
        authenticationStatus = "Connect to start local session"
    }

    func reconcileSelectedDisplay(with status: HostStatus) {
        guard !status.availableDisplays.isEmpty else {
            selectedDisplayID = nil
            return
        }

        if let selectedDisplayID, status.availableDisplays.contains(where: { $0.id == selectedDisplayID }) {
            return
        }

        selectedDisplayID = status.selectedDisplayID.flatMap { displayID in
            status.availableDisplays.contains { $0.id == displayID } ? displayID : nil
        }
    }

    func returnToBrowserAfterRemoteStop(_ status: String) {
        MiradorClientLog.connection.info("returning to browser status=\(status, privacy: .public)")
        let currentConnection = connection
        connection = nil
        currentConnection?.stop()
        resetSessionState(clearSelectedHost: true)
        connectionStatus = status
        authenticationStatus = "Connect to start local session"
    }
}
