import Foundation

public struct MiradorEndpoint: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let serviceType: String
    public let domain: String

    public init(
        id: String,
        name: String,
        serviceType: String = MiradorConstants.bonjourServiceType,
        domain: String = "local"
    ) {
        self.id = id
        self.name = name
        self.serviceType = serviceType
        self.domain = domain
    }
}
