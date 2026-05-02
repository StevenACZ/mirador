import Foundation
import MiradorCore

extension HostController {
    public func toggleRemoteControl() {
        isRemoteControlEnabled ? disableRemoteControl() : enableRemoteControl()
    }

    public func refreshRemoteControlPermissionStatus() {
        if inputControlService.isAccessibilityTrusted {
            remoteControlStatus = isRemoteControlEnabled ? "Control ready" : "Accessibility granted"
        } else {
            remoteControlStatus = "Accessibility not granted"
            isRemoteControlEnabled = false
        }
    }

    func enableRemoteControl() {
        guard activeAuthenticatedSessions > 0 else {
            remoteControlStatus = "Authenticate a client before enabling control"
            return
        }

        if inputControlService.isAccessibilityTrusted || inputControlService.requestAccessibilityTrust() {
            isRemoteControlEnabled = true
            remoteControlStatus = "Control ready"
        } else {
            isRemoteControlEnabled = false
            remoteControlStatus = "Grant Accessibility permission, then refresh"
        }
    }

    func disableRemoteControl() {
        isRemoteControlEnabled = false
        remoteControlStatus = "Control disabled"
    }

    func handleRemoteInput(_ event: RemoteInputEvent, from session: HostClientSession) -> Bool {
        receivedInputEventTotal += 1
        let shouldPublishUI = shouldPublishInputUI(for: event)
        if shouldPublishUI {
            receivedInputEvents = receivedInputEventTotal
            recordTrustedInput(for: session.id, applied: false)
        }

        guard isRemoteControlEnabled else {
            if shouldPublishUI {
                remoteControlStatus = "Control event blocked: enable control on Mac"
            }
            return false
        }

        do {
            try inputControlService.apply(event)
            appliedInputEventTotal += 1
            if shouldPublishUI {
                appliedInputEvents = appliedInputEventTotal
                recordTrustedInput(for: session.id, applied: true)
                remoteControlStatus = event.kind == .pointerMove
                    ? "Moving pointer #\(event.sequence)"
                    : "Applied \(event.kind.rawValue) #\(event.sequence)"
            }
            return true
        } catch {
            isRemoteControlEnabled = false
            remoteControlStatus = "Control blocked: \(error.localizedDescription)"
            return false
        }
    }

    private func shouldPublishInputUI(for event: RemoteInputEvent) -> Bool {
        guard event.kind == .pointerMove else { return true }
        let now = Date()
        guard
            event.sequence.isMultiple(of: 60)
                || now.timeIntervalSince(lastInputUIUpdate) >= 0.25
        else {
            return false
        }

        lastInputUIUpdate = now
        return true
    }
}
