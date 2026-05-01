import Foundation
@preconcurrency import Network
import Observation
import MiradorCore

@MainActor
@Observable
public final class MiradorClientStore {
    public internal(set) var hosts: [DiscoveredHost] = []
    public internal(set) var browserStatus = "Idle"
    public internal(set) var selectedHost: DiscoveredHost?
    public internal(set) var connectionStatus = "Not connected"
    public internal(set) var authenticationStatus = "Enter the host PIN"
    public internal(set) var hostStatus: HostStatus?
    public internal(set) var latestFrame: PreviewFrame?
    public internal(set) var receivedFrames = 0
    public var pinEntry = ""

    @ObservationIgnored private var browser: NWBrowser?
    @ObservationIgnored var resultsByID: [String: NWBrowser.Result] = [:]
    @ObservationIgnored var connection: ClientConnection?

    public init() {}

    public func startBrowsing() {
        guard browser == nil else { return }

        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true

        let browser = NWBrowser(
            for: .bonjour(type: MiradorConstants.bonjourServiceType, domain: nil),
            using: parameters
        )

        browser.stateUpdateHandler = { [weak self] state in
            let status = Self.statusDescription(for: state)
            Task { @MainActor in
                self?.browserStatus = status
            }
        }

        browser.browseResultsChangedHandler = { [weak self] results, _ in
            let mappedHosts = results
                .map(DiscoveredHost.init(result:))
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

            Task { @MainActor in
                self?.hosts = mappedHosts
                self?.resultsByID = Dictionary(
                    uniqueKeysWithValues: zip(mappedHosts.map(\.id), results)
                )
            }
        }

        self.browser = browser
        browserStatus = "Browsing"
        browser.start(queue: .main)
    }

    public func stopBrowsing() {
        browser?.cancel()
        browser = nil
        hosts = []
        resultsByID = [:]
        selectedHost = nil
        browserStatus = "Idle"
    }

    public func select(_ host: DiscoveredHost) {
        disconnect()
        selectedHost = host
        authenticationStatus = "Enter the host PIN"
    }

    nonisolated private static func statusDescription(for state: NWBrowser.State) -> String {
        switch state {
        case .setup:
            "Setting up"
        case .ready:
            "Browsing"
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
