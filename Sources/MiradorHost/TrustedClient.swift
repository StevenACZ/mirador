import Foundation

public struct TrustedClient: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var authenticatedAt: Date
    public var lastSeenAt: Date
    public var isActive: Bool
    public var receivedInputEvents: Int
    public var appliedInputEvents: Int

    public init(
        id: UUID,
        name: String,
        authenticatedAt: Date = Date(),
        lastSeenAt: Date = Date(),
        isActive: Bool = true,
        receivedInputEvents: Int = 0,
        appliedInputEvents: Int = 0
    ) {
        self.id = id
        self.name = name
        self.authenticatedAt = authenticatedAt
        self.lastSeenAt = lastSeenAt
        self.isActive = isActive
        self.receivedInputEvents = receivedInputEvents
        self.appliedInputEvents = appliedInputEvents
    }
}
