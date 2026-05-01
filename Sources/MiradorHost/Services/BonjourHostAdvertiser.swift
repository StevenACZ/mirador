import Foundation
@preconcurrency import Network
import MiradorCore

final class BonjourHostAdvertiser: @unchecked Sendable {
    var onStateChange: ((String) -> Void)?
    var onAuthenticated: (() -> Void)?

    private var listener: NWListener?
    private var sessionPIN: SessionPIN?

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
        listener?.cancel()
        listener = nil
    }

    private func handle(_ connection: NWConnection) {
        connection.stateUpdateHandler = { [weak self] state in
            if case let .failed(error) = state {
                self?.onStateChange?("Connection failed: \(error.localizedDescription)")
            }
        }

        connection.start(queue: .main)
        sendHostStatus(on: connection)
        receiveHeader(on: connection)
    }

    private func sendHostStatus(on connection: NWConnection) {
        let status = HostStatus(
            hostName: Host.current().localizedName ?? MiradorConstants.appName,
            isCaptureActive: false
        )
        send(.hostStatus(status), on: connection)
    }

    private func receiveHeader(on connection: NWConnection) {
        connection.receive(
            minimumIncompleteLength: LengthPrefixedMessageCodec.headerLength,
            maximumLength: LengthPrefixedMessageCodec.headerLength
        ) { [weak self] data, _, isComplete, error in
            guard error == nil, !isComplete, let data else {
                return
            }

            do {
                let payloadLength = try LengthPrefixedMessageCodec.decodeLengthHeader(data)
                self?.receivePayload(length: payloadLength, on: connection)
            } catch {
                self?.send(.error(ErrorMessage(code: "invalid_header", message: error.localizedDescription)), on: connection)
            }
        }
    }

    private func receivePayload(length: Int, on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: length, maximumLength: length) { [weak self] data, _, _, error in
            guard error == nil, let data else {
                return
            }

            do {
                let message = try LengthPrefixedMessageCodec.decode(SignalingMessage.self, from: data)
                self?.handle(message, on: connection)
                self?.receiveHeader(on: connection)
            } catch {
                self?.send(.error(ErrorMessage(code: "invalid_payload", message: error.localizedDescription)), on: connection)
            }
        }
    }

    private func handle(_ message: SignalingMessage, on connection: NWConnection) {
        switch message {
        case let .authenticate(authentication):
            guard let sessionPIN else {
                send(.authenticationResult(AuthenticationResult(accepted: false, reason: "No active PIN")), on: connection)
                return
            }

            if sessionPIN.matches(authentication.pin) {
                send(.authenticationResult(AuthenticationResult(accepted: true)), on: connection)
                onAuthenticated?()
            } else {
                send(.authenticationResult(AuthenticationResult(accepted: false, reason: "Invalid PIN")), on: connection)
            }

        case .hello, .hostStatus, .authenticationResult, .startPreview, .stopPreview:
            sendHostStatus(on: connection)

        case .error:
            break
        }
    }

    private func send(_ message: SignalingMessage, on connection: NWConnection) {
        do {
            let packet = try LengthPrefixedMessageCodec.encode(message)
            connection.send(content: packet, completion: .contentProcessed { _ in })
        } catch {
            onStateChange?("Encoding failed: \(error.localizedDescription)")
        }
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
