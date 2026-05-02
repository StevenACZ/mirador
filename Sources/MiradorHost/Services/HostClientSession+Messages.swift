import Foundation
import MiradorCore

extension HostClientSession {
    func receiveHeader() {
        connection.receive(
            minimumIncompleteLength: LengthPrefixedMessageCodec.headerLength,
            maximumLength: LengthPrefixedMessageCodec.headerLength
        ) { [weak self] data, _, isComplete, error in
            guard error == nil, !isComplete, let data else {
                self?.close()
                return
            }

            do {
                let payloadLength = try LengthPrefixedMessageCodec.decodeLengthHeader(data)
                self?.receivePayload(length: payloadLength)
            } catch {
                self?.sendError(code: "invalid_header", error: error)
                self?.receiveHeader()
            }
        }
    }

    func receivePayload(length: Int) {
        connection.receive(minimumIncompleteLength: length, maximumLength: length) { [weak self] data, _, _, error in
            guard error == nil, let data else {
                self?.close()
                return
            }

            do {
                let message = try LengthPrefixedMessageCodec.decode(SignalingMessage.self, from: data)
                self?.handle(message)
                self?.receiveHeader()
            } catch {
                self?.sendError(code: "invalid_payload", error: error)
                self?.receiveHeader()
            }
        }
    }

    func handle(_ message: SignalingMessage) {
        switch message {
        case let .hello(hello):
            handleHello(hello)
            sendHostStatus(isCaptureActive: isAuthenticated)
        case .hostStatus:
            sendHostStatus(isCaptureActive: isAuthenticated)
        case let .startPreview(selection):
            handlePreviewRequest(selection)
        case .stopPreview:
            MiradorHostLog.stream.info("preview stop requested id=\(self.id.uuidString, privacy: .public)")
            onPreviewStopped?(self)
        case let .remoteInput(event):
            handleRemoteInput(event)
        case .authenticationResult, .previewFrame, .streamStats, .error:
            break
        }
    }

    func handleHello(_ hello: ClientHello) {
        guard hello.protocolVersion == MiradorConstants.protocolVersion else {
            didAcceptHello = false
            MiradorHostLog.network.error(
                "client hello rejected id=\(self.id.uuidString, privacy: .public) protocol=\(hello.protocolVersion, privacy: .public)"
            )
            sendError(
                code: "protocol_version_unsupported",
                message: "Mirador protocol \(hello.protocolVersion) is not supported by this host."
            )
            return
        }

        didAcceptHello = true
        clientName = Self.sanitizedClientName(hello.deviceName)
        MiradorHostLog.network.info(
            "client hello accepted id=\(self.id.uuidString, privacy: .public) client=\(self.clientName, privacy: .public)"
        )
        acceptLocalSession()
    }

    func acceptLocalSession() {
        guard didAcceptHello else {
            MiradorHostLog.network.error("local session rejected before hello id=\(self.id.uuidString, privacy: .public)")
            send(.authenticationResult(AuthenticationResult(accepted: false, reason: "Client hello required")))
            return
        }

        guard !isAuthenticated else { return }
        isAuthenticated = true
        MiradorHostLog.network.info("local session accepted id=\(self.id.uuidString, privacy: .public)")
        send(.authenticationResult(AuthenticationResult(accepted: true)))
        sendHostStatus(isCaptureActive: false)
        if !didNotifyAuthentication {
            didNotifyAuthentication = true
            onAuthenticated?(self)
        }
    }

    func handlePreviewRequest(_ selection: DisplaySelection) {
        guard isAuthenticated else {
            MiradorHostLog.stream.error("preview rejected unauthenticated id=\(self.id.uuidString, privacy: .public)")
            send(.authenticationResult(AuthenticationResult(accepted: false, reason: "Connect first")))
            return
        }

        guard selection.viewport.isValid else {
            MiradorHostLog.stream.error(
                "preview rejected invalid viewport id=\(self.id.uuidString, privacy: .public)"
            )
            sendError(code: "preview_viewport_invalid", message: "Preview viewport must stay inside the display.")
            return
        }

        MiradorHostLog.stream.debug(
            "preview request id=\(self.id.uuidString, privacy: .public) display=\(String(describing: selection.displayID), privacy: .public) settings=\(selection.videoSettings.summary, privacy: .public)"
        )
        onPreviewRequested?(self, selection)
    }

    func handleRemoteInput(_ event: RemoteInputEvent) {
        guard isAuthenticated else {
            MiradorHostLog.input.error(
                "remote input rejected unauthenticated id=\(self.id.uuidString, privacy: .public)"
            )
            sendError(code: "remote_input_unauthenticated", message: "Connect before sending remote input.")
            return
        }

        guard event.isValid else {
            MiradorHostLog.input.error(
                "remote input rejected invalid id=\(self.id.uuidString, privacy: .public) kind=\(event.kind.rawValue, privacy: .public)"
            )
            sendError(code: "remote_input_invalid", message: "Remote input payload is not valid.")
            return
        }

        Task { [weak self] in
            guard let self else { return }
            let accepted = await self.onRemoteInput?(self, event) ?? false
            if !accepted {
                self.sendError(
                    code: "remote_input_unavailable",
                    message: "Remote control is disabled or missing Accessibility permission on the host."
                )
            }
        }
    }

    private static func sanitizedClientName(_ name: String) -> String {
        let trimmed = name
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else { return "Mirador Client" }
        return String(trimmed.prefix(48))
    }
}
