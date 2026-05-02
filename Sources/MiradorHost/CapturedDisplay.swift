import Foundation
import MiradorCore

public struct CapturedDisplay: Identifiable, Equatable, Sendable {
    public let id: UInt32
    public let width: Int
    public let height: Int

    public var title: String {
        "Display \(id)"
    }

    public var descriptor: DisplayDescriptor {
        DisplayDescriptor(id: id, width: width, height: height)
    }
}
