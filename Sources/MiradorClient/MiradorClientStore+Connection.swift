import Foundation
@preconcurrency import Network

extension MiradorClientStore {
    public func connectToSelectedHost() {
        guard let selectedHost else {
            connectionStatus = "Select a Mac first"
            return
        }

        let pin = pinEntry.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pin.isEmpty else {
            authenticationStatus = "Enter the host PIN"
            return
        }

        guard let endpoint = connectionEndpoint(for: selectedHost) else {
            connectionStatus = "Missing Bonjour endpoint"
            return
        }

        disconnect()
        let connection = ClientConnection(endpoint: endpoint)
        self.connection = connection
        connectionStatus = "Connecting"
        authenticationStatus = "Sending PIN"
        latestFrame = nil
        receivedFrames = 0
        bind(connection)
        connection.start()
        connection.authenticate(pin: pin)
    }

    public func disconnect() {
        connection?.stop()
        connection = nil
        hostStatus = nil
        latestFrame = nil
        receivedFrames = 0
        connectionStatus = "Not connected"
    }

    private func bind(_ connection: ClientConnection) {
        connection.onStatusChange = { [weak self] status in
            Task { @MainActor in self?.connectionStatus = status }
        }
        connection.onAuthenticationResult = { [weak self] result in
            Task { @MainActor in
                self?.authenticationStatus = result.accepted
                    ? "PIN accepted"
                    : result.reason ?? "PIN rejected"
            }
        }
        connection.onHostStatus = { [weak self] status in
            Task { @MainActor in self?.hostStatus = status }
        }
        connection.onPreviewFrame = { [weak self] frame in
            Task { @MainActor in
                self?.latestFrame = frame
                self?.receivedFrames += 1
                self?.connectionStatus = "Receiving preview"
            }
        }
        connection.onClosed = { [weak self] in
            Task { @MainActor in self?.connectionStatus = "Disconnected" }
        }
    }

    private func connectionEndpoint(for host: DiscoveredHost) -> NWEndpoint? {
        resultsByID[host.id]?.endpoint
    }
}
