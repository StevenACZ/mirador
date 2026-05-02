import Foundation
import MiradorCore

extension MiradorClientStore {
    public func sendRemoteScroll(deltaY: Int) {
        sendRemoteAction(
            kind: .scroll,
            scrollDelta: RemoteScrollDelta(deltaY: deltaY),
            shortcut: nil
        )
    }

    public func sendRemoteShortcut(_ shortcut: RemoteShortcut) {
        sendRemoteAction(kind: .shortcut, scrollDelta: nil, shortcut: shortcut)
    }

    private func sendRemoteAction(
        kind: RemoteInputKind,
        scrollDelta: RemoteScrollDelta?,
        shortcut: RemoteShortcut?
    ) {
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

        let event = RemoteInputEvent(
            sequence: nextInputSequence,
            kind: kind,
            scrollDelta: scrollDelta,
            shortcut: shortcut,
            displayID: remoteInputDisplayID
        )
        guard event.isValid else {
            remoteControlStatus = "Invalid \(kind.rawValue)"
            return
        }

        nextInputSequence += 1
        connection.sendRemoteInput(event)
        sentInputEvents += 1
        remoteControlStatus = "Sent \(kind.rawValue) #\(event.sequence)"
        MiradorClientLog.input.debug(
            "remote action sent kind=\(kind.rawValue, privacy: .public) seq=\(event.sequence, privacy: .public)"
        )
    }
}
