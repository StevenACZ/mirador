import Foundation

public enum LengthPrefixedMessageCodec {
    public enum CodecError: Error, Equatable {
        case invalidHeaderLength
        case payloadTooLarge
    }

    public static let headerLength = 4
    public static let maximumPayloadLength = 1_048_576

    public static func encode<Message: Encodable>(_ message: Message) throws -> Data {
        let payload = try JSONEncoder.mirador.encode(message)
        guard payload.count <= maximumPayloadLength else {
            throw CodecError.payloadTooLarge
        }

        var length = UInt32(payload.count).bigEndian
        var packet = Data(bytes: &length, count: headerLength)
        packet.append(payload)
        return packet
    }

    public static func decodeLengthHeader(_ data: Data) throws -> Int {
        guard data.count == headerLength else {
            throw CodecError.invalidHeaderLength
        }

        let value = data.withUnsafeBytes { rawBuffer in
            rawBuffer.load(as: UInt32.self).bigEndian
        }

        let length = Int(value)
        guard length <= maximumPayloadLength else {
            throw CodecError.payloadTooLarge
        }

        return length
    }

    public static func decode<Message: Decodable>(_ type: Message.Type, from payload: Data) throws -> Message {
        try JSONDecoder.mirador.decode(type, from: payload)
    }
}

public extension JSONEncoder {
    static var mirador: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}

public extension JSONDecoder {
    static var mirador: JSONDecoder {
        JSONDecoder()
    }
}
