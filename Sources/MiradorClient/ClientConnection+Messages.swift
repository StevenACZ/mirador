import Foundation
@preconcurrency import Network
import MiradorCore

extension ClientConnection {
    func receiveHeader() {
        connection.receive(
            minimumIncompleteLength: LengthPrefixedMessageCodec.headerLength,
            maximumLength: LengthPrefixedMessageCodec.headerLength
        ) { [weak self] data, _, isComplete, error in
            guard error == nil, !isComplete, let data else {
                MiradorClientLog.connection.info("receive header closed")
                self?.close()
                return
            }

            do {
                let payloadLength = try LengthPrefixedMessageCodec.decodeLengthHeader(data)
                self?.receivePayload(length: payloadLength)
            } catch {
                self?.onStatusChange?("Invalid frame header: \(error.localizedDescription)")
                self?.receiveHeader()
            }
        }
    }

    func receivePayload(length: Int) {
        connection.receive(minimumIncompleteLength: length, maximumLength: length) { [weak self] data, _, _, error in
            guard error == nil, let data else {
                MiradorClientLog.connection.info("receive payload closed")
                self?.close()
                return
            }

            do {
                let message = try LengthPrefixedMessageCodec.decode(SignalingMessage.self, from: data)
                self?.handle(message)
                self?.receiveHeader()
            } catch {
                self?.onStatusChange?("Invalid payload: \(error.localizedDescription)")
                self?.receiveHeader()
            }
        }
    }

    func handle(_ message: SignalingMessage) {
        switch message {
        case let .authenticationResult(result):
            MiradorClientLog.connection.info(
                "received auth result accepted=\(result.accepted, privacy: .public)"
            )
            onAuthenticationResult?(result)
        case let .hostStatus(status):
            MiradorClientLog.connection.debug(
                "received host status active=\(status.isCaptureActive, privacy: .public) targetFPS=\(status.targetFrameRate, privacy: .public)"
            )
            onHostStatus?(status)
        case let .previewFrame(frame):
            onPreviewFrame?(frame)
        case let .videoFrame(frame):
            onVideoFrame?(frame)
        case let .streamStats(stats):
            onStreamStats?(stats)
        case let .error(error):
            MiradorClientLog.connection.error(
                "received error code=\(error.code, privacy: .public) message=\(error.message, privacy: .public)"
            )
            onStatusChange?("\(error.code): \(error.message)")
        case .hello, .startPreview, .remoteInput, .stopPreview:
            break
        }
    }

    func send(_ message: SignalingMessage) {
        do {
            let packet = try LengthPrefixedMessageCodec.encode(message)
            connection.send(content: packet, completion: .contentProcessed { error in
                if let error {
                    MiradorClientLog.connection.error(
                        "send failed bytes=\(packet.count, privacy: .public) error=\(error.localizedDescription, privacy: .public)"
                    )
                }
            })
        } catch {
            onStatusChange?("Encoding failed: \(error.localizedDescription)")
        }
    }
}
