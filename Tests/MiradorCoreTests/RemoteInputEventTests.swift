import Foundation
import Testing
@testable import MiradorCore

@Suite("Remote input contracts")
struct RemoteInputEventTests {
    @Test("Round-trips remote input messages")
    func remoteInputMessageRoundTrip() throws {
        let event = RemoteInputEvent(
            sequence: 42,
            createdAt: Date(timeIntervalSince1970: 12),
            kind: .primaryClick,
            location: RemotePointerLocation(normalizedX: 0.25, normalizedY: 0.75),
            displayID: 99
        )
        let message = SignalingMessage.remoteInput(event)
        let packet = try LengthPrefixedMessageCodec.encode(message)
        let payload = packet.dropFirst(LengthPrefixedMessageCodec.headerLength)

        let decoded = try LengthPrefixedMessageCodec.decode(SignalingMessage.self, from: Data(payload))
        #expect(decoded == message)
    }

    @Test("Validates normalized pointer locations")
    func validatesPointerLocation() {
        #expect(RemotePointerLocation(normalizedX: 0, normalizedY: 1).isValid)
        #expect(RemotePointerLocation(normalizedX: 1.01, normalizedY: 0.5).isValid == false)
        #expect(RemotePointerLocation(normalizedX: 0.5, normalizedY: -0.01).isValid == false)
        #expect(RemotePointerLocation(normalizedX: .infinity, normalizedY: 0.5).isValid == false)
    }

    @Test("Validates scroll and shortcut events")
    func validatesControlPayloads() {
        let scroll = RemoteInputEvent(
            sequence: 1,
            kind: .scroll,
            scrollDelta: RemoteScrollDelta(deltaY: -6)
        )
        #expect(scroll.isValid)

        let shortcut = RemoteInputEvent(
            sequence: 2,
            kind: .shortcut,
            shortcut: .spotlight
        )
        #expect(shortcut.isValid)

        let missingLocation = RemoteInputEvent(sequence: 3, kind: .primaryClick)
        #expect(missingLocation.isValid == false)

        let secondaryClick = RemoteInputEvent(
            sequence: 4,
            kind: .secondaryClick,
            location: RemotePointerLocation(normalizedX: 0.4, normalizedY: 0.6)
        )
        #expect(secondaryClick.isValid)

        let text = RemoteInputEvent(
            sequence: 5,
            kind: .text,
            textInput: RemoteTextInput(text: "Hello from iPhone")
        )
        #expect(text.isValid)

        let delete = RemoteInputEvent(
            sequence: 6,
            kind: .keyboardKey,
            keyboardKey: .deleteBackward
        )
        #expect(delete.isValid)

        let emptyText = RemoteInputEvent(
            sequence: 7,
            kind: .text,
            textInput: RemoteTextInput(text: "")
        )
        #expect(emptyText.isValid == false)
    }
}
