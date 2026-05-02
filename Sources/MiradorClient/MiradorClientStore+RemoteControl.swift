import Foundation
import MiradorCore

extension MiradorClientStore {
    public func sendRemoteInput(kind: RemoteInputKind, normalizedX: Double, normalizedY: Double) {
        guard isAuthenticated else {
            remoteControlStatus = "Connect before control"
            return
        }

        guard isControlModeEnabled else {
            remoteControlStatus = "Control mode disabled"
            return
        }

        guard let connection else {
            remoteControlStatus = "Not connected"
            return
        }

        let viewport = latestFrame?.viewport ?? .full
        let location = RemotePointerLocation(
            normalizedX: viewport.normalizedX + normalizedX * viewport.normalizedWidth,
            normalizedY: viewport.normalizedY + normalizedY * viewport.normalizedHeight
        )
        guard location.isValid else {
            remoteControlStatus = "Control point outside preview"
            return
        }

        let event = RemoteInputEvent(
            sequence: nextInputSequence,
            kind: kind,
            location: location,
            displayID: remoteInputDisplayID
        )
        nextInputSequence += 1
        connection.sendRemoteInput(event)
        sentInputEventTotal += 1
        publishInputStatusIfNeeded(for: event)
        logInputIfNeeded(event, location: location)
    }

    public func sendRemoteText(_ text: String) {
        guard let textInput = validatedTextInput(text) else { return }
        sendKeyboardEvent(kind: .text, textInput: textInput)
    }

    public func sendRemoteKeyboardKey(_ key: RemoteKeyboardKey) {
        sendKeyboardEvent(kind: .keyboardKey, keyboardKey: key)
    }

    private func validatedTextInput(_ text: String) -> RemoteTextInput? {
        let input = RemoteTextInput(text: text)
        return input.isValid ? input : nil
    }

    private func sendKeyboardEvent(
        kind: RemoteInputKind,
        textInput: RemoteTextInput? = nil,
        keyboardKey: RemoteKeyboardKey? = nil
    ) {
        guard isAuthenticated else {
            remoteControlStatus = "Connect before typing"
            return
        }

        guard isControlModeEnabled else {
            remoteControlStatus = "Control mode disabled"
            return
        }

        guard let connection else {
            remoteControlStatus = "Not connected"
            return
        }

        let event = RemoteInputEvent(
            sequence: nextInputSequence,
            kind: kind,
            textInput: textInput,
            keyboardKey: keyboardKey,
            displayID: remoteInputDisplayID
        )
        guard event.isValid else { return }

        nextInputSequence += 1
        connection.sendRemoteInput(event)
        sentInputEventTotal += 1
        sentInputEvents = sentInputEventTotal
        remoteControlStatus = kind == .text ? "Typed text #\(event.sequence)" : "Sent key #\(event.sequence)"
    }

    private func publishInputStatusIfNeeded(for event: RemoteInputEvent) {
        guard event.kind == .pointerMove else {
            sentInputEvents = sentInputEventTotal
            remoteControlStatus = "Sent \(event.kind.rawValue) #\(event.sequence)"
            return
        }

        let now = Date()
        guard
            event.sequence.isMultiple(of: 60)
                || now.timeIntervalSince(lastPointerInputUIUpdate) >= 0.25
        else {
            return
        }

        lastPointerInputUIUpdate = now
        sentInputEvents = sentInputEventTotal
        remoteControlStatus = "Moving pointer #\(event.sequence)"
    }

    private func logInputIfNeeded(_ event: RemoteInputEvent, location: RemotePointerLocation) {
        guard event.kind != .pointerMove || event.sequence.isMultiple(of: 60) else { return }
        MiradorClientLog.input.debug(
            "remote input sent kind=\(event.kind.rawValue, privacy: .public) seq=\(event.sequence, privacy: .public) x=\(location.normalizedX, privacy: .public) y=\(location.normalizedY, privacy: .public)"
        )
    }

    var remoteInputDisplayID: UInt32? {
        selectedDisplayID ?? latestFrame?.displayID
    }
}
