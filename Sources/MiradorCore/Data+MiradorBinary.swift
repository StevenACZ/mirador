import Foundation

extension Data {
    mutating func appendMiradorBigEndian(_ value: UInt32) {
        append(contentsOf: [
            UInt8((value >> 24) & 0xFF),
            UInt8((value >> 16) & 0xFF),
            UInt8((value >> 8) & 0xFF),
            UInt8(value & 0xFF)
        ])
    }

    func miradorBigEndianUInt32(at offset: Int) throws -> UInt32 {
        guard offset >= 0, count >= offset + 4 else {
            throw LengthPrefixedMessageCodec.CodecError.invalidHeaderLength
        }

        var value: UInt32 = 0
        for byte in self[offset..<(offset + 4)] {
            value = (value << 8) | UInt32(byte)
        }
        return value
    }
}
