import Foundation
import Testing
@testable import MiradorCore

@Suite("Length-prefixed message codec")
struct LengthPrefixedMessageCodecTests {
    @Test("Round-trips signaling messages")
    func roundTrip() throws {
        let message = SignalingMessage.hello(ClientHello(deviceName: "iPhone"))
        let packet = try LengthPrefixedMessageCodec.encode(message)

        let header = packet.prefix(LengthPrefixedMessageCodec.headerLength)
        let payload = packet.dropFirst(LengthPrefixedMessageCodec.headerLength)

        let length = try LengthPrefixedMessageCodec.decodeLengthHeader(Data(header))
        #expect(length == payload.count)

        let decoded = try LengthPrefixedMessageCodec.decode(SignalingMessage.self, from: Data(payload))
        #expect(decoded == message)
    }
}
