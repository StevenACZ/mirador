import Foundation

extension LengthPrefixedMessageCodec {
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

    static func packet(for payload: Data) throws -> Data {
        guard payload.count <= maximumPayloadLength else {
            throw CodecError.payloadTooLarge
        }

        var length = UInt32(payload.count).bigEndian
        var packet = Data(bytes: &length, count: headerLength)
        packet.append(payload)
        return packet
    }
}
