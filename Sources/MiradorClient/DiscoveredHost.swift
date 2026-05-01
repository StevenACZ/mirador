import Foundation
@preconcurrency import Network
import MiradorCore

public struct DiscoveredHost: Identifiable, Equatable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let serviceType: String
    public let domain: String
    public let description: String

    public init(id: String, name: String, serviceType: String, domain: String, description: String) {
        self.id = id
        self.name = name
        self.serviceType = serviceType
        self.domain = domain
        self.description = description
    }

    init(result: NWBrowser.Result) {
        switch result.endpoint {
        case let .service(name, type, domain, _):
            self.init(
                id: "\(name).\(type).\(domain)",
                name: name,
                serviceType: type,
                domain: domain,
                description: "\(name) \(type) \(domain)"
            )
        default:
            let value = String(describing: result.endpoint)
            self.init(
                id: value,
                name: value,
                serviceType: MiradorConstants.bonjourServiceType,
                domain: "local",
                description: value
            )
        }
    }
}
