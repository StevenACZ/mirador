import Foundation
@preconcurrency import Network
import Observation
import MiradorCore

@MainActor
@Observable
public final class MiradorClientStore {
    public private(set) var hosts: [DiscoveredHost] = []
    public private(set) var browserStatus = "Idle"
    public private(set) var selectedHost: DiscoveredHost?

    @ObservationIgnored private var browser: NWBrowser?
    @ObservationIgnored private var resultsByID: [String: NWBrowser.Result] = [:]

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
        selectedHost = host
    }

    public func connectionEndpoint(for host: DiscoveredHost) -> NWEndpoint? {
        resultsByID[host.id]?.endpoint
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
