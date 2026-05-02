import Foundation

public enum RemoteInputKind: String, Codable, Equatable, Sendable {
    case pointerMove
    case primaryClick
    case secondaryClick
    case scroll
    case shortcut
    case text
    case keyboardKey
}

public struct RemotePointerLocation: Codable, Equatable, Sendable {
    public let normalizedX: Double
    public let normalizedY: Double

    public init(normalizedX: Double, normalizedY: Double) {
        self.normalizedX = normalizedX
        self.normalizedY = normalizedY
    }

    public var isValid: Bool {
        normalizedX.isFinite
            && normalizedY.isFinite
            && (0...1).contains(normalizedX)
            && (0...1).contains(normalizedY)
    }
}

public struct RemoteInputEvent: Codable, Equatable, Sendable {
    public let sequence: UInt64
    public let createdAt: Date
    public let kind: RemoteInputKind
    public let location: RemotePointerLocation?
    public let scrollDelta: RemoteScrollDelta?
    public let shortcut: RemoteShortcut?
    public let textInput: RemoteTextInput?
    public let keyboardKey: RemoteKeyboardKey?
    public let displayID: UInt32?

    public init(
        sequence: UInt64,
        createdAt: Date = Date(),
        kind: RemoteInputKind,
        location: RemotePointerLocation? = nil,
        scrollDelta: RemoteScrollDelta? = nil,
        shortcut: RemoteShortcut? = nil,
        textInput: RemoteTextInput? = nil,
        keyboardKey: RemoteKeyboardKey? = nil,
        displayID: UInt32? = nil
    ) {
        self.sequence = sequence
        self.createdAt = createdAt
        self.kind = kind
        self.location = location
        self.scrollDelta = scrollDelta
        self.shortcut = shortcut
        self.textInput = textInput
        self.keyboardKey = keyboardKey
        self.displayID = displayID
    }

    public var isValid: Bool {
        switch kind {
        case .pointerMove, .primaryClick, .secondaryClick:
            location?.isValid == true
        case .scroll:
            scrollDelta?.isValid == true
        case .shortcut:
            shortcut != nil
        case .text:
            textInput?.isValid == true
        case .keyboardKey:
            keyboardKey != nil
        }
    }
}

public struct RemoteScrollDelta: Codable, Equatable, Sendable {
    public let deltaX: Int
    public let deltaY: Int

    public init(deltaX: Int = 0, deltaY: Int) {
        self.deltaX = deltaX
        self.deltaY = deltaY
    }

    public var isValid: Bool {
        abs(deltaX) <= 20 && abs(deltaY) <= 20 && (deltaX != 0 || deltaY != 0)
    }
}

public enum RemoteShortcut: String, Codable, CaseIterable, Identifiable, Sendable {
    case escape
    case spotlight
    case appSwitcher

    public var id: String {
        rawValue
    }
}

public struct RemoteTextInput: Codable, Equatable, Sendable {
    public let text: String

    public init(text: String) {
        self.text = text
    }

    public var isValid: Bool {
        !text.isEmpty && text.count <= 512
    }
}

public enum RemoteKeyboardKey: String, Codable, CaseIterable, Identifiable, Sendable {
    case deleteBackward
    case returnKey

    public var id: String {
        rawValue
    }
}
