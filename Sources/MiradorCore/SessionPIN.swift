import Foundation

public struct SessionPIN: Codable, Equatable, Hashable, Sendable {
    public let value: String

    public init(_ value: String) {
        self.value = value
    }

    public static func generate(length: Int = MiradorConstants.defaultPINLength) -> SessionPIN {
        var generator = SystemRandomNumberGenerator()
        let digits = (0..<length).map { _ in
            String(Int.random(in: 0...9, using: &generator))
        }

        return SessionPIN(digits.joined())
    }

    public func matches(_ candidate: String) -> Bool {
        candidate.filter(\.isNumber) == value
    }
}
