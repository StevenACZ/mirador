import Foundation
@preconcurrency import Network
import MiradorCore

final class BonjourHostAdvertiser: @unchecked Sendable {
    var onStateChange: ((String) -> Void)?
    var onAuthenticated: ((HostClientSession) -> Void)?
    var onPreviewRequested: ((HostClientSession, DisplaySelection) -> Void)?
    var onPreviewStopped: ((HostClientSession) -> Void)?
    var onRemoteInput: ((HostClientSession, RemoteInputEvent) async -> Bool)?
    var onConnectionClosed: ((HostClientSession) -> Void)?

    private var listener: NWListener?
    private var sessions: [UUID: HostClientSession] = [:]

    func start() throws {
        stop()

        let listener = try NWListener(using: MiradorNetworkParameters.interactiveTCP())
        listener.service = NWListener.Service(
            name: MiradorConstants.hostServiceName,
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

    func cancelSession(id: UUID) {
        sessions[id]?.cancel()
        sessions[id] = nil
    }

    func session(id: UUID) -> HostClientSession? {
        sessions[id]
    }

    private func handle(_ connection: NWConnection) {
        let session = HostClientSession(
            connection: connection,
            hostName: MiradorConstants.hostServiceName
        )

        session.onStateChange = { [weak self] status in
            self?.onStateChange?(status)
        }

        session.onAuthenticated = { [weak self] session in
            self?.onAuthenticated?(session)
        }

        session.onPreviewRequested = { [weak self] session, selection in
            self?.onPreviewRequested?(session, selection)
        }

        session.onPreviewStopped = { [weak self] session in
            self?.onPreviewStopped?(session)
        }

        session.onRemoteInput = { [weak self] session, event in
            await self?.onRemoteInput?(session, event) ?? false
        }

        session.onClosed = { [weak self] session in
            guard let self else { return }
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
