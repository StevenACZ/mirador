import Foundation
import CoreGraphics
import MiradorCore

extension HostController {
    func startPreview(for session: HostClientSession, selection: DisplaySelection) async {
        captureStatus = "Preparing capture"
        let isUpdatingActivePreview = activePreviewSessionID == session.id && previewTask != nil
        let previousDisplayID = selectedDisplayID
        let previousVideoSettings = videoSettings
        let previousViewport = previewViewport

        activePreviewSessionID = session.id
        videoSettings = selection.videoSettings
        qualityProfile = videoSettings.qualityProfile
        previewViewport = selection.viewport

        do {
            if displays.isEmpty || !isUpdatingActivePreview {
                displays = try await captureService.loadDisplays()
            }
            selectedDisplayID = resolvedDisplayID(from: selection.displayID)
            guard selectedDisplayID != nil else {
                captureStatus = "Requested display unavailable"
                session.sendHostStatus(hostStatus(isCaptureActive: false))
                session.sendError(
                    code: "display_unavailable",
                    message: "The requested display is no longer available."
                )
                return
            }
            await updateSystemAudioCapture()
            captureStatus = displays.isEmpty
                ? "No displays available"
                : "Ready for \(videoSettings.summary) stream"
            session.sendHostStatus(hostStatus(isCaptureActive: !displays.isEmpty))
            MiradorHostLog.stream.info(
                "preview selection session=\(session.id.uuidString, privacy: .public) update=\(isUpdatingActivePreview, privacy: .public) display=\(String(describing: self.selectedDisplayID), privacy: .public) profile=\(self.qualityProfile.rawValue, privacy: .public) settings=\(self.videoSettings.summary, privacy: .public) viewport=\(self.previewViewport.logSummary, privacy: .public)"
            )
        } catch {
            selectedDisplayID = nil
            captureStatus = "Capture failed: \(error.localizedDescription)"
            session.sendError(code: "capture_unavailable", error: error)
            MiradorHostLog.stream.error("preview setup failed: \(error.localizedDescription, privacy: .public)")
        }

        guard selectedDisplayID != nil else { return }
        if isUpdatingActivePreview {
            if previousDisplayID != selectedDisplayID || previousVideoSettings != videoSettings {
                metricsTracker.reset()
                videoEncoder.invalidate()
                streamStats = nil
                skippedPreviewFrames = 0
            }
            if previousViewport != previewViewport {
                MiradorHostLog.stream.debug(
                    "preview viewport changed from=\(previousViewport.logSummary, privacy: .public) to=\(self.previewViewport.logSummary, privacy: .public)"
                )
            }
            return
        }

        metricsTracker.reset()
        streamStats = nil
        skippedPreviewFrames = 0
        previewTask?.cancel()
        previewTask = Task { [weak self, weak session] in
            guard let self, let session else { return }
            await self.streamPreviewFrames(to: session)
        }
    }

    func streamPreviewFrames(to session: HostClientSession) async {
        while !Task.isCancelled {
            let frameStartedAt = Date()
            do {
                try await sendNextPreviewFrame(to: session)
                try await sleepUntilNextFrame(from: frameStartedAt)
            } catch is CancellationError {
                break
            } catch {
                captureStatus = "Preview failed: \(error.localizedDescription)"
                MiradorHostLog.stream.error("preview loop failed: \(error.localizedDescription, privacy: .public)")
                break
            }
        }
        MiradorHostLog.stream.debug("preview loop stopped session=\(session.id.uuidString, privacy: .public)")
    }

    func stopPreview(for session: HostClientSession) {
        guard activePreviewSessionID == session.id else { return }
        stopPreview()
    }

    func stopPreview() {
        let activeSession = activePreviewSessionID.flatMap { advertiser.session(id: $0) }
        previewTask?.cancel()
        previewTask = nil
        activeSession?.sendHostStatus(hostStatus(isCaptureActive: false))
        activePreviewSessionID = nil
        streamStats = nil
        skippedPreviewFrames = 0
        videoEncoder.invalidate()
        Task { @MainActor in
            await self.captureService.stopCapture()
            await self.updateSystemAudioCapture()
        }
        streamedFrames = streamedFrameTotal
        if streamedFrameTotal > 0 {
            captureStatus = "Preview stopped after \(streamedFrameTotal) frames"
        } else {
            captureStatus = "Preview stopped"
        }
        MiradorHostLog.stream.info(
            "preview stopped frames=\(self.streamedFrameTotal, privacy: .public)"
        )
    }

    func resolvedDisplayID(from requestedID: UInt32?) -> UInt32? {
        guard let requestedID else {
            let primaryID = CGMainDisplayID()
            return displays.first { $0.id == primaryID }?.id ?? displays.first?.id
        }
        guard displays.contains(where: { $0.id == requestedID }) else {
            MiradorHostLog.stream.error(
                "requested display missing requested=\(requestedID, privacy: .public) available=\(self.displays.map(\.id).description, privacy: .public)"
            )
            return nil
        }
        return requestedID
    }

    func hostStatus(isCaptureActive: Bool) -> HostStatus {
        HostStatus(
            hostName: MiradorConstants.hostServiceName,
            isCaptureActive: isCaptureActive,
            targetFrameRate: videoSettings.targetFrameRate,
            availableDisplays: displays.map(\.descriptor),
            selectedDisplayID: selectedDisplayID,
            qualityProfile: videoSettings.qualityProfile,
            isSystemAudioAvailable: systemAudioStatus.isAvailable,
            isSystemAudioEnabled: systemAudioStatus.isAllowedByHost,
            systemAudio: systemAudioStatus
        )
    }

    func sendHostStatus(to session: HostClientSession) {
        let isCaptureActive = activePreviewSessionID == session.id && previewTask != nil
        session.sendHostStatus(hostStatus(isCaptureActive: isCaptureActive))
    }

    private func sendNextPreviewFrame(to session: HostClientSession) async throws {
        if videoSettings.codec == .jpeg {
            try await sendNextJPEGFrame(to: session)
        } else {
            try await sendNextEncodedVideoFrame(to: session)
        }
    }

    private func sendNextJPEGFrame(to session: HostClientSession) async throws {
        let sequence = nextFrameSequence
        nextFrameSequence += 1
        let capturedFrame = try await captureService.capturePreviewFrame(
            sequence: sequence,
            displayID: selectedDisplayID,
            videoSettings: videoSettings,
            viewport: previewViewport
        )
        let frame = capturedFrame.frame
        let captureDuration = capturedFrame.encodeDurationMilliseconds
        let waitDuration = capturedFrame.waitDurationMilliseconds
        let sendStartedAt = Date()
        try await session.sendPreviewFrame(frame)
        let sendDuration = Date().timeIntervalSince(sendStartedAt) * 1_000
        await publishSentFrame(
            StreamFrameRecord(previewFrame: frame),
            captureDuration: captureDuration,
            waitDuration: waitDuration,
            sendDuration: sendDuration,
            session: session
        )
    }

    private func sendNextEncodedVideoFrame(to session: HostClientSession) async throws {
        let sequence = nextFrameSequence
        nextFrameSequence += 1
        let sourceFrame = try await captureService.captureSourceFrame(
            displayID: selectedDisplayID,
            videoSettings: videoSettings,
            viewport: previewViewport,
            repeatsLatestFrame: true
        )
        let encodeStartedAt = Date()
        let frame = try await videoEncoder.encode(
            sourceFrame: sourceFrame,
            sequence: sequence,
            settings: videoSettings
        )
        let captureDuration = Date().timeIntervalSince(encodeStartedAt) * 1_000
        let sendStartedAt = Date()
        try await session.sendVideoFrame(frame)
        let sendDuration = Date().timeIntervalSince(sendStartedAt) * 1_000
        await publishSentFrame(
            StreamFrameRecord(
                videoFrame: frame,
                isRepeatedSourceFrame: sourceFrame.isRepeatedSourceFrame
            ),
            captureDuration: captureDuration,
            waitDuration: sourceFrame.waitDurationMilliseconds,
            sendDuration: sendDuration,
            session: session
        )
    }

    private func publishSentFrame(
        _ frame: StreamFrameRecord,
        captureDuration: Double,
        waitDuration: Double,
        sendDuration: Double,
        session: HostClientSession
    ) async {
        streamedFrameTotal += 1
        publishStreamProgressIfNeeded(frame: frame)
        logSlowFrameIfNeeded(frame: frame, captureDuration: captureDuration, sendDuration: sendDuration)
        if let stats = metricsTracker.record(
            frame: frame,
            captureDurationMilliseconds: captureDuration,
            captureWaitDurationMilliseconds: waitDuration,
            sendDurationMilliseconds: sendDuration,
            targetFrameRate: videoSettings.targetFrameRate
        ) {
            streamStats = stats
            session.sendStreamStats(stats)
            await refreshSystemAudioStatus()
            session.sendHostStatus(hostStatus(isCaptureActive: true))
            MiradorHostLog.stream.info(
                "stream stats codec=\(stats.codec.rawValue, privacy: .public) sentFPS=\(stats.sentFramesPerSecond, privacy: .public) sourceFPS=\(stats.sourceFramesPerSecond, privacy: .public) target=\(stats.targetFrameRate, privacy: .public) kbps=\(stats.bitrateKilobitsPerSecond, privacy: .public) waitMs=\(stats.captureWaitDurationMilliseconds, privacy: .public) encodeMs=\(stats.captureDurationMilliseconds, privacy: .public) sendMs=\(stats.sendDurationMilliseconds, privacy: .public) repeatRate=\(stats.repeatedFrameRate, privacy: .public) repeated=\(stats.repeatedFrames, privacy: .public) dropRate=\(stats.sourceDropRate, privacy: .public) dropped=\(stats.sourceFramesDropped, privacy: .public) bytes=\(stats.lastFrameBytes, privacy: .public) display=\(String(describing: stats.displayID), privacy: .public)"
            )
        }
    }

    private func publishStreamProgressIfNeeded(frame: StreamFrameRecord) {
        let now = Date()
        guard
            streamedFrameTotal == 1
                || now.timeIntervalSince(lastStreamUIUpdate) >= 0.5
        else {
            return
        }

        lastStreamUIUpdate = now
        streamedFrames = streamedFrameTotal
        captureStatus = "Streaming \(videoSettings.summary)"
    }

    private func sleepUntilNextFrame(from startedAt: Date) async throws {
        let interval = 1 / Double(max(videoSettings.targetFrameRate, 1))
        let elapsed = Date().timeIntervalSince(startedAt)
        guard elapsed < interval else {
            skippedPreviewFrames += 1
            if skippedPreviewFrames == 1 || skippedPreviewFrames.isMultiple(of: 10) {
                MiradorHostLog.stream.info(
                    "stream over budget skipped=\(self.skippedPreviewFrames, privacy: .public) elapsedMs=\(elapsed * 1_000, privacy: .public) budgetMs=\(interval * 1_000, privacy: .public)"
                )
            }
            await Task.yield()
            return
        }

        let sleepNanoseconds = UInt64((interval - elapsed) * 1_000_000_000)
        try await Task.sleep(nanoseconds: sleepNanoseconds)
    }

    private func logSlowFrameIfNeeded(
        frame: StreamFrameRecord,
        captureDuration: Double,
        sendDuration: Double
    ) {
        let frameBudget = 1_000 / Double(max(videoSettings.targetFrameRate, 1))
        guard captureDuration + sendDuration > frameBudget else { return }
        MiradorHostLog.stream.debug(
            "slow frame seq=\(frame.sequence, privacy: .public) source=\(frame.sourceFrameNumber, privacy: .public) repeated=\(frame.isRepeatedSourceFrame, privacy: .public) sourceDropped=\(frame.sourceFramesDropped, privacy: .public) codec=\(frame.codec.rawValue, privacy: .public) profile=\(frame.qualityProfile.rawValue, privacy: .public) encodeMs=\(captureDuration, privacy: .public) sendMs=\(sendDuration, privacy: .public) budgetMs=\(frameBudget, privacy: .public) bytes=\(frame.byteCount, privacy: .public) viewport=\(frame.viewport.logSummary, privacy: .public)"
        )
    }
}
