import Foundation

public struct DisplayDescriptor: Codable, Equatable, Identifiable, Sendable {
    public let id: UInt32
    public let width: Int
    public let height: Int

    public init(id: UInt32, width: Int, height: Int) {
        self.id = id
        self.width = width
        self.height = height
    }

    public var title: String {
        "Display \(id)"
    }
}
