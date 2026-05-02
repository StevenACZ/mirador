import ApplicationServices
import CoreGraphics
import Foundation
import MiradorCore

final class InputControlService {
    private let eventSource = CGEventSource(stateID: .hidSystemState)
    private var cachedAccessibilityTrust = false
    private var lastAccessibilityTrustCheck = Date.distantPast
    private let accessibilityTrustCacheDuration: TimeInterval = 0.5

    var isAccessibilityTrusted: Bool {
        refreshAccessibilityTrust()
    }

    func requestAccessibilityTrust() -> Bool {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        cachedAccessibilityTrust = AXIsProcessTrustedWithOptions(options)
        lastAccessibilityTrustCheck = Date()
        return cachedAccessibilityTrust
    }

    func apply(_ event: RemoteInputEvent) throws {
        guard event.isValid else {
            throw InputControlError.invalidLocation
        }

        guard accessibilityTrust(for: event) else {
            throw InputControlError.accessibilityNotGranted
        }

        switch event.kind {
        case .pointerMove:
            let point = try displayPoint(for: event)
            try postMouseEvent(type: .mouseMoved, at: point)
        case .primaryClick:
            let point = try displayPoint(for: event)
            try postPrimaryClick(at: point)
        case .secondaryClick:
            let point = try displayPoint(for: event)
            try postSecondaryClick(at: point)
        case .scroll:
            try postScroll(event.scrollDelta)
        case .shortcut:
            try postShortcut(event.shortcut)
        case .text:
            try postText(event.textInput)
        case .keyboardKey:
            try postKeyboardKey(event.keyboardKey)
        }
    }

    private func accessibilityTrust(for event: RemoteInputEvent) -> Bool {
        guard event.kind == .pointerMove else {
            return refreshAccessibilityTrust()
        }

        let now = Date()
        guard now.timeIntervalSince(lastAccessibilityTrustCheck) > accessibilityTrustCacheDuration else {
            return cachedAccessibilityTrust
        }

        return refreshAccessibilityTrust(now: now)
    }

    private func refreshAccessibilityTrust(now: Date = Date()) -> Bool {
        cachedAccessibilityTrust = AXIsProcessTrusted()
        lastAccessibilityTrustCheck = now
        return cachedAccessibilityTrust
    }

    private func displayPoint(for event: RemoteInputEvent) throws -> CGPoint {
        guard let location = event.location else {
            throw InputControlError.invalidLocation
        }

        let displayID = CGDirectDisplayID(event.displayID ?? CGMainDisplayID())
        let bounds = CGDisplayBounds(displayID)
        guard !bounds.isNull, !bounds.isEmpty else {
            throw InputControlError.displayUnavailable
        }

        return CGPoint(
            x: bounds.minX + (bounds.width * location.normalizedX),
            y: bounds.minY + (bounds.height * location.normalizedY)
        )
    }

    private func postPrimaryClick(at point: CGPoint) throws {
        try postMouseEvent(type: .leftMouseDown, at: point)
        try postMouseEvent(type: .leftMouseUp, at: point)
    }

    private func postSecondaryClick(at point: CGPoint) throws {
        try postMouseEvent(type: .rightMouseDown, at: point, button: .right)
        try postMouseEvent(type: .rightMouseUp, at: point, button: .right)
    }

    private func postMouseEvent(
        type: CGEventType,
        at point: CGPoint,
        button: CGMouseButton = .left
    ) throws {
        guard let event = CGEvent(
            mouseEventSource: eventSource,
            mouseType: type,
            mouseCursorPosition: point,
            mouseButton: button
        ) else {
            throw InputControlError.eventCreationFailed
        }

        event.post(tap: .cghidEventTap)
    }

    private func postScroll(_ delta: RemoteScrollDelta?) throws {
        guard let delta else {
            throw InputControlError.invalidScroll
        }

        guard let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .line,
            wheelCount: 2,
            wheel1: Int32(delta.deltaY),
            wheel2: Int32(delta.deltaX),
            wheel3: 0
        ) else {
            throw InputControlError.eventCreationFailed
        }

        event.post(tap: .cghidEventTap)
    }

    private func postShortcut(_ shortcut: RemoteShortcut?) throws {
        guard let shortcut else {
            throw InputControlError.invalidShortcut
        }

        switch shortcut {
        case .escape:
            try postKeyPress(keyCode: KeyCode.escape)
        case .spotlight:
            try postKeyPress(keyCode: KeyCode.space, flags: .maskCommand)
        case .appSwitcher:
            try postKeyPress(keyCode: KeyCode.tab, flags: .maskCommand)
        }
    }

    private func postText(_ textInput: RemoteTextInput?) throws {
        guard let textInput, textInput.isValid else {
            throw InputControlError.invalidShortcut
        }

        for character in textInput.text {
            try postUnicodeText(String(character))
        }
    }

    private func postUnicodeText(_ text: String) throws {
        let units = Array(text.utf16)
        guard
            let keyDown = CGEvent(keyboardEventSource: eventSource, virtualKey: 0, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: eventSource, virtualKey: 0, keyDown: false)
        else {
            throw InputControlError.eventCreationFailed
        }

        try units.withUnsafeBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else {
                throw InputControlError.eventCreationFailed
            }
            keyDown.keyboardSetUnicodeString(
                stringLength: buffer.count,
                unicodeString: baseAddress
            )
            keyUp.keyboardSetUnicodeString(
                stringLength: buffer.count,
                unicodeString: baseAddress
            )
        }
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    private func postKeyboardKey(_ key: RemoteKeyboardKey?) throws {
        guard let key else {
            throw InputControlError.invalidShortcut
        }

        switch key {
        case .deleteBackward:
            try postKeyPress(keyCode: KeyCode.deleteBackward)
        case .returnKey:
            try postKeyPress(keyCode: KeyCode.returnKey)
        }
    }

    private func postKeyPress(keyCode: CGKeyCode, flags: CGEventFlags = []) throws {
        guard
            let keyDown = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: false)
        else {
            throw InputControlError.eventCreationFailed
        }

        keyDown.flags = flags
        keyUp.flags = flags
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    private enum KeyCode {
        static let returnKey = CGKeyCode(36)
        static let deleteBackward = CGKeyCode(51)
        static let escape = CGKeyCode(53)
        static let tab = CGKeyCode(48)
        static let space = CGKeyCode(49)
    }
}
