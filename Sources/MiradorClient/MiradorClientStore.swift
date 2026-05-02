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
    public internal(set) var authenticationStatus = "Connect to start local session"
    public internal(set) var isAuthenticated = false
    public internal(set) var hostStatus: HostStatus?
    public internal(set) var availableDisplays: [DisplayDescriptor] = []
    public internal(set) var latestFrame: PreviewFrame?
    public internal(set) var receivedFrames = 0
    public internal(set) var streamStats: StreamStats?
    public internal(set) var lastFrameLatencyMilliseconds: Double?
    public internal(set) var systemAudioStatus = SystemAudioStatus.unavailable
    public internal(set) var isPreviewActive = false
    public internal(set) var remoteControlStatus = "Control disabled"
    public internal(set) var sentInputEvents = 0
    public var selectedDisplayID: UInt32?
    public var selectedVideoSettings = StreamVideoSettings()
    public var zoomScale = 1.0
    public var viewportCenterX = 0.5
    public var viewportCenterY = 0.5
    public var isControlModeEnabled = false

    @ObservationIgnored private var browser: NWBrowser?
    @ObservationIgnored var resultsByID: [String: NWBrowser.Result] = [:]
    @ObservationIgnored var connection: ClientConnection?
    @ObservationIgnored var nextInputSequence: UInt64 = 0
    @ObservationIgnored var sentInputEventTotal = 0
    @ObservationIgnored var lastPointerInputUIUpdate = Date.distantPast

    public init() {}

    public func startBrowsing() {
        guard browser == nil else { return }
        MiradorClientLog.browser.info("browser starting")

        let browser = NWBrowser(
            for: .bonjour(type: MiradorConstants.bonjourServiceType, domain: nil),
            using: MiradorNetworkParameters.interactiveTCP()
        )

        browser.stateUpdateHandler = { [weak self] state in
            let status = Self.statusDescription(for: state)
            MiradorClientLog.browser.info("browser state=\(status, privacy: .public)")
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
                MiradorClientLog.browser.info(
                    "browser results count=\(mappedHosts.count, privacy: .public)"
                )
            }
        }

        self.browser = browser
        browserStatus = "Browsing"
        browser.start(queue: .main)
    }

    public func stopBrowsing() {
        MiradorClientLog.browser.info("browser stopping")
        browser?.cancel()
        browser = nil
        hosts = []
        resultsByID = [:]
        selectedHost = nil
        browserStatus = "Idle"
    }

    public func select(_ host: DiscoveredHost) {
        MiradorClientLog.browser.info("host selected id=\(host.id, privacy: .public)")
        disconnect()
        selectedHost = host
        authenticationStatus = "Connect to start local session"
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
