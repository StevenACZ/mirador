import Foundation
@preconcurrency import Network
import MiradorCore

final class BonjourHostAdvertiser: @unchecked Sendable {
    var onStateChange: ((String) -> Void)?
    var onAuthenticated: ((HostClientSession) -> Void)?
    var onPreviewStopped: (() -> Void)?
    var onConnectionClosed: ((HostClientSession) -> Void)?

    private var listener: NWListener?
    private var sessionPIN: SessionPIN?
    private var sessions: [UUID: HostClientSession] = [:]

    func start(pin: SessionPIN) throws {
        stop()

        sessionPIN = pin

        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true

        let listener = try NWListener(using: parameters)
        listener.service = NWListener.Service(
            name: Host.current().localizedName ?? MiradorConstants.appName,
            type: MiradorConstants.bonjourServiceType
        )

        listener.stateUpdateHandler = { [weak self] state in
            self?.onStateChange?(Self.statusDescription(for: state))
        }

        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection)
        }

        self.listener = listener
        listener.start(queue: .main)
    }

    func stop() {
        sessions.values.forEach { $0.cancel() }
        sessions = [:]
        listener?.cancel()
        listener = nil
    }

    private func handle(_ connection: NWConnection) {
        let session = HostClientSession(
            connection: connection,
            hostName: Host.current().localizedName ?? MiradorConstants.appName,
            pinProvider: { [weak self] in self?.sessionPIN }
        )

        session.onStateChange = { [weak self] status in
            self?.onStateChange?(status)
        }

        session.onAuthenticated = { [weak self, weak session] in
            guard let session else { return }
            self?.onAuthenticated?(session)
        }

        session.onPreviewStopped = { [weak self] in
            self?.onPreviewStopped?()
        }

        session.onClosed = { [weak self, weak session] in
            guard let self, let session else { return }
            self.sessions[session.id] = nil
            self.onConnectionClosed?(session)
        }

        sessions[session.id] = session
        session.start()
    }

    private static func statusDescription(for state: NWListener.State) -> String {
        switch state {
        case .setup:
            "Setting up"
        case .ready:
            "Listening"
        case .failed:
            "Failed"
        case .cancelled:
            "Stopped"
        case .waiting:
            "Waiting"
        @unknown default:
            "Unknown"
        }
    }
}
