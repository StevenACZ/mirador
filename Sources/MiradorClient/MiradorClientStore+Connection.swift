import Foundation
@preconcurrency import Network
import MiradorCore

extension MiradorClientStore {
    public func connectToSelectedHost() {
        guard let selectedHost else {
            connectionStatus = "Select a Mac first"
            return
        }

        guard let endpoint = connectionEndpoint(for: selectedHost) else {
            connectionStatus = "Missing Bonjour endpoint"
            return
        }

        MiradorClientLog.connection.info("connecting hostID=\(selectedHost.id, privacy: .public)")
        disconnect()
        let connection = ClientConnection(endpoint: endpoint)
        self.connection = connection
        connectionStatus = "Connecting"
        authenticationStatus = "Starting local session"
        isAuthenticated = false
        resetRenderedStreamFrames()
        streamStats = nil
        systemAudioStatus = .unavailable
        isPreviewActive = false
        remoteControlStatus = "Control disabled"
        sentInputEvents = 0
        sentInputEventTotal = 0
        zoomScale = 1.0
        viewportCenterX = 0.5
        viewportCenterY = 0.5
        nextInputSequence = 0
        bind(connection)
        connection.start()
        connection.startLocalSession()
    }

    public func disconnect() {
        MiradorClientLog.connection.info("disconnect requested")
        connection?.stop()
        connection = nil
        resetSessionState(clearSelectedHost: false)
        connectionStatus = "Not connected"
    }

    private func bind(_ connection: ClientConnection) {
        connection.onStatusChange = { [weak self] status in
            Task { @MainActor in
                MiradorClientLog.connection.info("connection status=\(status, privacy: .public)")
                self?.connectionStatus = status
                if status.hasPrefix("remote_input") {
                    self?.remoteControlStatus = status
                }
            }
        }
        connection.onAuthenticationResult = { [weak self] result in
            Task { @MainActor in
                MiradorClientLog.connection.info(
                    "auth result accepted=\(result.accepted, privacy: .public) reason=\(String(describing: result.reason), privacy: .public)"
                )
                self?.authenticationStatus = result.accepted
                    ? "Local session accepted"
                    : result.reason ?? "Local session rejected"
                self?.isAuthenticated = result.accepted
                if result.accepted {
                    self?.sendStreamSelection()
                }
            }
        }
        connection.onHostStatus = { [weak self] status in
            Task { @MainActor in
                guard let self else { return }
                MiradorClientLog.connection.debug(
                    "host status active=\(status.isCaptureActive, privacy: .public) targetFPS=\(status.targetFrameRate, privacy: .public) displays=\(status.availableDisplays.count, privacy: .public) selected=\(String(describing: status.selectedDisplayID), privacy: .public)"
                )
                if !status.isCaptureActive, self.isPreviewActive || self.receivedFrames > 0 {
                    self.returnToBrowserAfterRemoteStop("Host stopped preview")
                    return
                }
                self.hostStatus = status
                self.availableDisplays = status.availableDisplays
                self.reconcileSelectedDisplay(with: status)
                self.systemAudioStatus = status.systemAudio
                self.isPreviewActive = status.isCaptureActive
            }
        }
        connection.onPreviewFrame = { [weak self] frame in
            Task { @MainActor in
                guard let self else { return }
                self.latestFrame = frame
                self.latestVideoFrameInfo = nil
                self.receivedFrames += 1
                self.isPreviewActive = true
                let now = Date()
                if self.receivedFrames == 1 || self.receivedFrames.isMultiple(of: 15) {
                    self.lastFrameLatencyMilliseconds = now.timeIntervalSince(frame.capturedAt) * 1_000
                }
                if self.connectionStatus != "Receiving preview" {
                    self.connectionStatus = "Receiving preview"
                }
                if self.receivedFrames == 1 || self.receivedFrames.isMultiple(of: 60) {
                    MiradorClientLog.stream.info(
                        "preview frames received=\(self.receivedFrames, privacy: .public) seq=\(frame.sequence, privacy: .public) source=\(frame.sourceFrameNumber, privacy: .public) sourceDropped=\(frame.sourceFramesDropped, privacy: .public) bytes=\(frame.jpegData.count, privacy: .public) latencyMs=\(self.lastFrameLatencyMilliseconds ?? 0, privacy: .public) display=\(String(describing: frame.displayID), privacy: .public)"
                    )
                }
            }
        }
        connection.onVideoFrame = { [weak self] frame in
            Task { @MainActor in
                guard let self else { return }
                self.enqueueVideoFrame(frame)
                self.latestFrame = nil
                self.receivedFrames += 1
                self.isPreviewActive = true
                let now = Date()
                let shouldPublishInfo = self.latestVideoFrameInfo == nil
                    || self.receivedFrames.isMultiple(of: 15)
                    || self.latestVideoFrameInfo?.codec != frame.codec
                    || self.latestVideoFrameInfo?.width != frame.width
                    || self.latestVideoFrameInfo?.height != frame.height
                    || self.latestVideoFrameInfo?.displayID != frame.displayID

                if shouldPublishInfo {
                    self.latestVideoFrameInfo = StreamFrameInfo(videoFrame: frame)
                    self.lastFrameLatencyMilliseconds = now.timeIntervalSince(frame.capturedAt) * 1_000
                }
                if self.connectionStatus != "Receiving preview" {
                    self.connectionStatus = "Receiving preview"
                }
                if self.receivedFrames == 1 || self.receivedFrames.isMultiple(of: 60) {
                    MiradorClientLog.stream.info(
                        "video frames received=\(self.receivedFrames, privacy: .public) codec=\(frame.codec.rawValue, privacy: .public) seq=\(frame.sequence, privacy: .public) keyframe=\(frame.isKeyframe, privacy: .public) source=\(frame.sourceFrameNumber, privacy: .public) sourceDropped=\(frame.sourceFramesDropped, privacy: .public) bytes=\(frame.data.count, privacy: .public) latencyMs=\(self.lastFrameLatencyMilliseconds ?? 0, privacy: .public) display=\(String(describing: frame.displayID), privacy: .public)"
                    )
                }
            }
        }
        connection.onStreamStats = { [weak self] stats in
            Task { @MainActor in
                self?.streamStats = stats
                MiradorClientLog.stream.info(
                    "stream stats codec=\(stats.codec.rawValue, privacy: .public) sentFPS=\(stats.sentFramesPerSecond, privacy: .public) sourceFPS=\(stats.sourceFramesPerSecond, privacy: .public) target=\(stats.targetFrameRate, privacy: .public) kbps=\(stats.bitrateKilobitsPerSecond, privacy: .public) waitMs=\(stats.captureWaitDurationMilliseconds, privacy: .public) encodeMs=\(stats.captureDurationMilliseconds, privacy: .public) sendMs=\(stats.sendDurationMilliseconds, privacy: .public) repeatRate=\(stats.repeatedFrameRate, privacy: .public) repeated=\(stats.repeatedFrames, privacy: .public) dropRate=\(stats.sourceDropRate, privacy: .public) dropped=\(stats.sourceFramesDropped, privacy: .public)"
                )
            }
        }
        connection.onClosed = { [weak self] in
            Task { @MainActor in
                self?.returnToBrowserAfterRemoteStop("Disconnected")
            }
        }
    }

    private func connectionEndpoint(for host: DiscoveredHost) -> NWEndpoint? {
        resultsByID[host.id]?.endpoint
    }

}
