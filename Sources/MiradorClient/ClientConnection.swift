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
    var onStreamStats: ((StreamStats) -> Void)?
    var onClosed: (() -> Void)?

    let connection: NWConnection
    private let connectionQueue = DispatchQueue(
        label: "com.stevenacz.mirador.client.connection",
        qos: .userInteractive
    )
    private var isClosed = false
    private var remoteInputLogCounter = 0

    init(endpoint: NWEndpoint) {
        connection = NWConnection(to: endpoint, using: MiradorNetworkParameters.interactiveTCP())
    }

    func start() {
        MiradorClientLog.connection.info("nw connection starting")
        connection.stateUpdateHandler = { [weak self] state in
            self?.handle(state)
        }
        connection.start(queue: connectionQueue)
        receiveHeader()
    }

    func startLocalSession() {
        MiradorClientLog.connection.info("auth sending local hello")
        send(.hello(ClientHello(deviceName: Self.deviceName)))
    }

    func stop() {
        MiradorClientLog.connection.info("nw connection stop requested")
        isClosed = true
        send(.stopPreview)
        connection.cancel()
    }

    func sendRemoteInput(_ event: RemoteInputEvent) {
        logRemoteInputIfNeeded(event)
        send(.remoteInput(event))
    }

    func requestPreview(_ selection: DisplaySelection) {
        MiradorClientLog.stream.debug(
            "send preview request display=\(String(describing: selection.displayID), privacy: .public) settings=\(selection.videoSettings.summary, privacy: .public)"
        )
        send(.startPreview(selection))
    }

    private func handle(_ state: NWConnection.State) {
        switch state {
        case .ready:
            MiradorClientLog.connection.info("nw connection ready")
            onStatusChange?("Connected")
        case let .waiting(error):
            MiradorClientLog.connection.info(
                "nw connection waiting error=\(error.localizedDescription, privacy: .public)"
            )
            onStatusChange?("Waiting: \(error.localizedDescription)")
        case let .failed(error):
            MiradorClientLog.connection.error(
                "nw connection failed error=\(error.localizedDescription, privacy: .public)"
            )
            onStatusChange?("Failed: \(error.localizedDescription)")
            close()
        case .cancelled:
            MiradorClientLog.connection.info("nw connection cancelled")
            close()
        default:
            break
        }
    }

    func close() {
        guard !isClosed else { return }
        isClosed = true
        MiradorClientLog.connection.info("nw connection closed")
        onClosed?()
    }

    private func logRemoteInputIfNeeded(_ event: RemoteInputEvent) {
        remoteInputLogCounter += 1
        guard event.kind != .pointerMove || remoteInputLogCounter.isMultiple(of: 60) else {
            return
        }
        MiradorClientLog.input.debug(
            "send remote input kind=\(event.kind.rawValue, privacy: .public) seq=\(event.sequence, privacy: .public)"
        )
    }

    private static var deviceName: String {
        #if canImport(UIKit)
        switch UIDevice.current.userInterfaceIdiom {
        case .pad:
            "iPad"
        case .phone:
            "iPhone"
        default:
            "Mirador Client"
        }
        #else
        "Mirador Client"
        #endif
    }
}
