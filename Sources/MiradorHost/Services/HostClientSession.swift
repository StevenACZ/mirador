import Foundation
@preconcurrency import Network
import MiradorCore

final class HostClientSession: @unchecked Sendable, Identifiable {
    let id = UUID()

    var onStateChange: ((String) -> Void)?
    var onAuthenticated: ((HostClientSession) -> Void)?
    var onHostStatusRequested: ((HostClientSession) -> Void)?
    var onPreviewRequested: ((HostClientSession, DisplaySelection) -> Void)?
    var onPreviewStopped: ((HostClientSession) -> Void)?
    var onRemoteInput: ((HostClientSession, RemoteInputEvent) async -> Bool)?
    var onClosed: ((HostClientSession) -> Void)?

    let connection: NWConnection
    let hostName: String
    private let connectionQueue: DispatchQueue
    var clientName = "Unknown Client"
    var didAcceptHello = false
    var isAuthenticated = false
    var didNotifyAuthentication = false
    var isClosed = false

    var isSessionAuthenticated: Bool {
        isAuthenticated
    }

    init(connection: NWConnection, hostName: String) {
        self.connection = connection
        self.hostName = hostName
        self.connectionQueue = DispatchQueue(
            label: "com.stevenacz.mirador.host.session.\(id.uuidString)",
            qos: .userInteractive
        )
    }

    func start() {
        connection.stateUpdateHandler = { [weak self] state in
            self?.handle(state)
        }

        MiradorHostLog.network.info("session starting id=\(self.id.uuidString, privacy: .public)")
        connection.start(queue: connectionQueue)
        receiveHeader()
    }

    func cancel() {
        MiradorHostLog.network.info("session cancel requested id=\(self.id.uuidString, privacy: .public)")
        isClosed = true
        connection.cancel()
    }

    func sendPreviewFrame(_ frame: PreviewFrame) async throws {
        guard isAuthenticated else { throw CancellationError() }
        try await sendAndWait(.previewFrame(frame))
    }

    func sendVideoFrame(_ frame: EncodedVideoFrame) async throws {
        guard isAuthenticated else { throw CancellationError() }
        try await sendAndWait(.videoFrame(frame))
    }

    func sendStreamStats(_ stats: StreamStats) {
        guard isAuthenticated else { return }
        send(.streamStats(stats))
    }

    func sendHostStatus(_ status: HostStatus) {
        guard isAuthenticated else { return }
        send(.hostStatus(status))
    }

    func sendHostStatus(isCaptureActive: Bool) {
        guard isAuthenticated else { return }
        let status = HostStatus(hostName: hostName, isCaptureActive: isCaptureActive)
        send(.hostStatus(status))
    }

    func sendError(code: String, error: Error) {
        send(.error(ErrorMessage(code: code, message: error.localizedDescription)))
    }

    func sendError(code: String, message: String) {
        send(.error(ErrorMessage(code: code, message: message)))
    }

    func send(_ message: SignalingMessage) {
        do {
            let packet = try LengthPrefixedMessageCodec.encode(message)
            connection.send(content: packet, completion: .contentProcessed { _ in })
        } catch {
            onStateChange?("Encoding failed: \(error.localizedDescription)")
        }
    }

    private func sendAndWait(_ message: SignalingMessage) async throws {
        let packet = try LengthPrefixedMessageCodec.encode(message)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: packet, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }
    }

    func close() {
        guard !isClosed else { return }
        isClosed = true
        MiradorHostLog.network.info(
            "session closed id=\(self.id.uuidString, privacy: .public) authenticated=\(self.isAuthenticated, privacy: .public)"
        )
        onClosed?(self)
    }

    private func handle(_ state: NWConnection.State) {
        switch state {
        case .ready:
            MiradorHostLog.network.info("session ready id=\(self.id.uuidString, privacy: .public)")
            onStateChange?("Client connected")
        case let .waiting(error):
            MiradorHostLog.network.info(
                "session waiting id=\(self.id.uuidString, privacy: .public) error=\(error.localizedDescription, privacy: .public)"
            )
            onStateChange?("Connection waiting: \(error.localizedDescription)")
        case let .failed(error):
            MiradorHostLog.network.error(
                "session failed id=\(self.id.uuidString, privacy: .public) error=\(error.localizedDescription, privacy: .public)"
            )
            onStateChange?("Connection failed: \(error.localizedDescription)")
            close()
        case .cancelled:
            close()
        default:
            break
        }
    }
}
