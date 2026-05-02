import Foundation

extension HostController {
    func configureAdvertiserCallbacks() {
        advertiser.onStateChange = { [weak self] status in
            Task { @MainActor in
                self?.networkStatus = status
                self?.isAdvertising = status == "Listening"
            }
        }

        advertiser.onAuthenticated = { [weak self] session in
            Task { @MainActor in
                self?.handleAuthenticatedSession(session)
            }
        }

        advertiser.onPreviewRequested = { [weak self] session, selection in
            Task { @MainActor in
                await self?.startPreview(for: session, selection: selection)
            }
        }

        advertiser.onPreviewStopped = { [weak self] session in
            Task { @MainActor in
                self?.stopPreview(for: session)
            }
        }

        advertiser.onRemoteInput = { [weak self] session, event in
            await MainActor.run {
                self?.handleRemoteInput(event, from: session) ?? false
            }
        }

        advertiser.onConnectionClosed = { [weak self] session in
            Task { @MainActor in
                self?.handleConnectionClosed(session: session)
            }
        }
    }

    func handleAuthenticatedSession(_ session: HostClientSession) {
        authenticatedSessions += 1
        activeAuthenticatedSessions += 1
        upsertTrustedClient(for: session)
        remoteControlStatus = isRemoteControlEnabled ? "Control ready" : "Client connected"
    }

    func handleConnectionClosed(session: HostClientSession) {
        if activePreviewSessionID == session.id {
            stopPreview()
        }
        if session.isSessionAuthenticated {
            activeAuthenticatedSessions = max(0, activeAuthenticatedSessions - 1)
            markTrustedClient(id: session.id, isActive: false)
        }
        if activeAuthenticatedSessions == 0, isRemoteControlEnabled {
            disableRemoteControl()
        }
    }
}
