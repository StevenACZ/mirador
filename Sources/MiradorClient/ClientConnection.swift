import Foundation
@preconcurrency import Network
#if canImport(UIKit)
import UIKit
#endif
import MiradorCore

final class ClientConnection: @unchecked Sendable {
    var onStatusChange: ((String) -> Void)?
    var onAuthenticationResult: ((AuthenticationResult) -> Void)?
    var onHostStatus: ((HostStatus) -> Void)?
    var onPreviewFrame: ((PreviewFrame) -> Void)?
    var onClosed: (() -> Void)?

    private let connection: NWConnection
    private var isClosed = false

    init(endpoint: NWEndpoint) {
        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true
        connection = NWConnection(to: endpoint, using: parameters)
    }

    func start() {
        connection.stateUpdateHandler = { [weak self] state in
            self?.handle(state)
        }
        connection.start(queue: .main)
        receiveHeader()
    }

    func authenticate(pin: String) {
        send(.hello(ClientHello(deviceName: Self.deviceName)))
        send(.authenticate(PINAuthentication(pin: pin)))
    }

    func stop() {
        isClosed = true
        send(.stopPreview)
        connection.cancel()
    }

    private func handle(_ state: NWConnection.State) {
        switch state {
        case .ready:
            onStatusChange?("Connected")
        case let .waiting(error):
            onStatusChange?("Waiting: \(error.localizedDescription)")
        case let .failed(error):
            onStatusChange?("Failed: \(error.localizedDescription)")
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
                self?.onStatusChange?("Invalid frame header: \(error.localizedDescription)")
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
                self?.onStatusChange?("Invalid payload: \(error.localizedDescription)")
                self?.receiveHeader()
            }
        }
    }

    private func handle(_ message: SignalingMessage) {
        switch message {
        case let .authenticationResult(result):
            onAuthenticationResult?(result)
            if result.accepted {
                send(.startPreview(DisplaySelection()))
            }
        case let .hostStatus(status):
            onHostStatus?(status)
        case let .previewFrame(frame):
            onPreviewFrame?(frame)
        case let .error(error):
            onStatusChange?("\(error.code): \(error.message)")
        case .hello, .authenticate, .startPreview, .stopPreview:
            break
        }
    }

    private func send(_ message: SignalingMessage) {
        do {
            let packet = try LengthPrefixedMessageCodec.encode(message)
            connection.send(content: packet, completion: .contentProcessed { _ in })
        } catch {
            onStatusChange?("Encoding failed: \(error.localizedDescription)")
        }
    }

    private func close() {
        guard !isClosed else { return }
        isClosed = true
        onClosed?()
    }

    private static var deviceName: String {
        #if canImport(UIKit)
        UIDevice.current.name
        #else
        Host.current().localizedName ?? "Mirador Client"
        #endif
    }
}
