import Foundation

enum EncodedVideoFrameBinaryPayloadCodec {
    private static let magic = Data([0x4D, 0x56, 0x46, 0x31])
    private static let metadataLengthOffset = 4
    private static let metadataOffset = 8

    static func isBinaryPayload(_ payload: Data) -> Bool {
        payload.count >= metadataOffset && payload.prefix(magic.count).elementsEqual(magic)
    }

    static func encode(_ frame: EncodedVideoFrame) throws -> Data {
        let metadata = EncodedVideoFrameTransportMetadata(frame: frame)
        let metadataData = try JSONEncoder.mirador.encode(metadata)
        guard metadataData.count <= UInt32.max else {
            throw LengthPrefixedMessageCodec.CodecError.payloadTooLarge
        }

        var payload = Data()
        payload.reserveCapacity(metadataOffset + metadataData.count + frame.data.count)
        payload.append(magic)
        payload.appendMiradorBigEndian(UInt32(metadataData.count))
        payload.append(metadataData)
        payload.append(frame.data)
        return payload
    }

    static func decode(_ payload: Data) throws -> EncodedVideoFrame {
        guard isBinaryPayload(payload) else {
            throw LengthPrefixedMessageCodec.CodecError.invalidHeaderLength
        }

        let metadataLength = Int(try payload.miradorBigEndianUInt32(at: metadataLengthOffset))
        let metadataEnd = metadataOffset + metadataLength
        guard metadataEnd <= payload.count else {
            throw LengthPrefixedMessageCodec.CodecError.payloadTooLarge
        }

        let metadataData = Data(payload[metadataOffset..<metadataEnd])
        let metadata = try JSONDecoder.mirador.decode(
            EncodedVideoFrameTransportMetadata.self,
            from: metadataData
        )
        return metadata.encodedVideoFrame(data: Data(payload[metadataEnd..<payload.count]))
    }
}
