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

    @Test("Round-trips preview frame payloads")
    func previewFrameRoundTrip() throws {
        let frame = PreviewFrame(
            sequence: 7,
            capturedAt: Date(timeIntervalSince1970: 10),
            width: 640,
            height: 360,
            jpegData: Data([0xFF, 0xD8, 0xFF])
        )
        let message = SignalingMessage.previewFrame(frame)
        let packet = try LengthPrefixedMessageCodec.encode(message)
        let payload = packet.dropFirst(LengthPrefixedMessageCodec.headerLength)

        #expect(PreviewFrameBinaryPayloadCodec.isBinaryPayload(Data(payload)))
        let decoded = try LengthPrefixedMessageCodec.decode(SignalingMessage.self, from: Data(payload))
        #expect(decoded == message)
    }

    @Test("Decodes legacy JSON preview frame payloads")
    func legacyPreviewFrameRoundTrip() throws {
        let frame = PreviewFrame(
            sequence: 8,
            capturedAt: Date(timeIntervalSince1970: 11),
            width: 320,
            height: 180,
            jpegData: Data([0xFF, 0xD8, 0x00, 0xFF])
        )
        let message = SignalingMessage.previewFrame(frame)
        let payload = try JSONEncoder.mirador.encode(message)

        let decoded = try LengthPrefixedMessageCodec.decode(SignalingMessage.self, from: payload)
        #expect(decoded == message)
    }

    @Test("Round-trips encoded video frame payloads")
    func videoFrameRoundTrip() throws {
        let format = VideoFormatMetadata(
            parameterSets: [Data([0x01, 0x64]), Data([0x02, 0xAC])],
            nalUnitHeaderLength: 4
        )
        let frame = EncodedVideoFrame(
            codec: .h264,
            sequence: 42,
            capturedAt: Date(timeIntervalSince1970: 12),
            width: 1_920,
            height: 1_080,
            displayID: 3,
            qualityProfile: .smooth,
            viewport: .centered(zoomScale: 2),
            sourceFrameNumber: 60,
            sourceFramesDropped: 2,
            isKeyframe: true,
            format: format,
            data: Data([0x00, 0x00, 0x00, 0x05, 0x65])
        )
        let message = SignalingMessage.videoFrame(frame)
        let packet = try LengthPrefixedMessageCodec.encode(message)
        let payload = packet.dropFirst(LengthPrefixedMessageCodec.headerLength)

        #expect(EncodedVideoFrameBinaryPayloadCodec.isBinaryPayload(Data(payload)))
        let decoded = try LengthPrefixedMessageCodec.decode(SignalingMessage.self, from: Data(payload))
        #expect(decoded == message)
    }
}
