import Foundation

public enum LengthPrefixedMessageCodec {
    public enum CodecError: Error, Equatable {
        case invalidHeaderLength
        case payloadTooLarge
    }

    public static let headerLength = 4
    public static let maximumPayloadLength = 4_194_304

    public static func encode(_ message: SignalingMessage) throws -> Data {
        let payload: Data
        switch message {
        case let .previewFrame(frame):
            payload = try PreviewFrameBinaryPayloadCodec.encode(frame)
        case let .videoFrame(frame):
            payload = try EncodedVideoFrameBinaryPayloadCodec.encode(frame)
        default:
            payload = try JSONEncoder.mirador.encode(message)
        }
        return try packet(for: payload)
    }

    public static func encode<Message: Encodable>(_ message: Message) throws -> Data {
        let payload = try JSONEncoder.mirador.encode(message)
        return try packet(for: payload)
    }

    public static func decode<Message: Decodable>(_ type: Message.Type, from payload: Data) throws -> Message {
        if type == SignalingMessage.self, PreviewFrameBinaryPayloadCodec.isBinaryPayload(payload) {
            let frame = try PreviewFrameBinaryPayloadCodec.decode(payload)
            return SignalingMessage.previewFrame(frame) as! Message
        }

        if type == SignalingMessage.self, EncodedVideoFrameBinaryPayloadCodec.isBinaryPayload(payload) {
            let frame = try EncodedVideoFrameBinaryPayloadCodec.decode(payload)
            return SignalingMessage.videoFrame(frame) as! Message
        }

        return try JSONDecoder.mirador.decode(type, from: payload)
    }
}
