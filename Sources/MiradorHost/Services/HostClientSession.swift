import Foundation
@preconcurrency import Network
import MiradorCore

final class HostClientSession: @unchecked Sendable, Identifiable {
    let id = UUID()

    var onStateChange: ((String) -> Void)?
    var onAuthenticated: (() -> Void)?
    var onPreviewStopped: (() -> Void)?
    var onClosed: (() -> Void)?

    private let connection: NWConnection
    private let hostName: String
    private let pinProvider: () -> SessionPIN?
    private var isAuthenticated = false
    private var isClosed = false

    init(connection: NWConnection, hostName: String, pinProvider: @escaping () -> SessionPIN?) {
        self.connection = connection
        self.hostName = hostName
        self.pinProvider = pinProvider
    }

    func start() {
        connection.stateUpdateHandler = { [weak self] state in
            self?.handle(state)
        }

        connection.start(queue: .main)
        sendHostStatus(isCaptureActive: false)
        receiveHeader()
    }

    func cancel() {
        isClosed = true
        connection.cancel()
    }

    func sendPreviewFrame(_ frame: PreviewFrame) {
        guard isAuthenticated else { return }
        send(.previewFrame(frame))
    }

    private func handle(_ state: NWConnection.State) {
        switch state {
        case let .failed(error):
            onStateChange?("Connection failed: \(error.localizedDescription)")
            close()
        case .cancelled:
            close()
        default:
            break
        }
    }

    private func receiveHeader() {
        connection.receive(
            minimumIncompleteLength: LengthPrefixedMessageCodec.headerLength,
            maximumLength: LengthPrefixedMessageCodec.headerLength
        ) { [weak self] data, _, isComplete, error in
            guard error == nil, !isComplete, let data else {
                self?.close()
                return
            }

            do {
                let payloadLength = try LengthPrefixedMessageCodec.decodeLengthHeader(data)
                self?.receivePayload(length: payloadLength)
            } catch {
                self?.sendError(code: "invalid_header", error: error)
                self?.receiveHeader()
            }
        }
    }

    private func receivePayload(length: Int) {
        connection.receive(minimumIncompleteLength: length, maximumLength: length) { [weak self] data, _, _, error in
            guard error == nil, let data else {
                self?.close()
                return
            }

            do {
                let message = try LengthPrefixedMessageCodec.decode(SignalingMessage.self, from: data)
                self?.handle(message)
                self?.receiveHeader()
            } catch {
                self?.sendError(code: "invalid_payload", error: error)
                self?.receiveHeader()
            }
        }
    }

    private func handle(_ message: SignalingMessage) {
        switch message {
        case let .authenticate(authentication):
            authenticate(authentication.pin)
        case .hello, .hostStatus:
            sendHostStatus(isCaptureActive: isAuthenticated)
        case .startPreview:
            if isAuthenticated {
                sendHostStatus(isCaptureActive: true)
                onAuthenticated?()
            } else {
                send(.authenticationResult(AuthenticationResult(accepted: false, reason: "Authenticate first")))
            }
        case .stopPreview:
            onPreviewStopped?()
        case .authenticationResult, .previewFrame, .error:
            break
        }
    }

    private func authenticate(_ candidate: String) {
        guard let sessionPIN = pinProvider() else {
            send(.authenticationResult(AuthenticationResult(accepted: false, reason: "No active PIN")))
            return
        }

        isAuthenticated = sessionPIN.matches(candidate)
        if isAuthenticated {
            send(.authenticationResult(AuthenticationResult(accepted: true)))
            sendHostStatus(isCaptureActive: false)
        } else {
            send(.authenticationResult(AuthenticationResult(accepted: false, reason: "Invalid PIN")))
        }
    }

    private func sendHostStatus(isCaptureActive: Bool) {
        let status = HostStatus(hostName: hostName, isCaptureActive: isCaptureActive)
        send(.hostStatus(status))
    }

    private func sendError(code: String, error: Error) {
        send(.error(ErrorMessage(code: code, message: error.localizedDescription)))
    }

    private func send(_ message: SignalingMessage) {
        do {
            let packet = try LengthPrefixedMessageCodec.encode(message)
            connection.send(content: packet, completion: .contentProcessed { _ in })
        } catch {
            onStateChange?("Encoding failed: \(error.localizedDescription)")
        }
    }

    private func close() {
        guard !isClosed else { return }
        isClosed = true
        onClosed?()
    }
}
