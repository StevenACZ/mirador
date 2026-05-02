import CoreMedia
import CoreVideo
import Foundation
import VideoToolbox
import MiradorCore

final class VideoToolboxEncoder: @unchecked Sendable {
    private struct EncoderKey: Equatable {
        let codec: StreamCodec
        let width: Int
        let height: Int
        let frameRate: StreamFrameRatePreset
        let bitrateMegabitsPerSecond: Double
        let displayID: UInt32?
        let viewport: PreviewViewport
    }

    fileprivate final class EncodeRequest {
        let codec: StreamCodec
        let sequence: UInt64
        let sourceFrame: CapturedSourceFrame

        private let lock = NSLock()
        private var continuation: CheckedContinuation<EncodedVideoFrame, Error>?

        init(
            codec: StreamCodec,
            sequence: UInt64,
            sourceFrame: CapturedSourceFrame,
            continuation: CheckedContinuation<EncodedVideoFrame, Error>
        ) {
            self.codec = codec
            self.sequence = sequence
            self.sourceFrame = sourceFrame
            self.continuation = continuation
        }

        func finish(_ result: Result<EncodedVideoFrame, Error>) {
            lock.lock()
            let continuation = continuation
            self.continuation = nil
            lock.unlock()

            switch result {
            case let .success(frame):
                continuation?.resume(returning: frame)
            case let .failure(error):
                continuation?.resume(throwing: error)
            }
        }
    }

    private var session: VTCompressionSession?
    private var activeKey: EncoderKey?
    private var needsKeyframe = true

    deinit {
        invalidate()
    }

    func invalidate() {
        if let session {
            VTCompressionSessionInvalidate(session)
        }
        session = nil
        activeKey = nil
        needsKeyframe = true
    }

    func encode(
        sourceFrame: CapturedSourceFrame,
        sequence: UInt64,
        settings: StreamVideoSettings
    ) async throws -> EncodedVideoFrame {
        guard settings.codec.isVideoToolboxCodec else {
            throw VideoToolboxEncoderError.unsupportedCodec(settings.codec)
        }

        let session = try configureIfNeeded(
            sourceFrame: sourceFrame,
            settings: settings
        )
        let shouldForceKeyframe = needsKeyframe
        needsKeyframe = false

        return try await withCheckedThrowingContinuation { continuation in
            let request = EncodeRequest(
                codec: settings.codec,
                sequence: sequence,
                sourceFrame: sourceFrame,
                continuation: continuation
            )
            let retainedRequest = Unmanaged.passRetained(request)
            let frameProperties = shouldForceKeyframe
                ? [kVTEncodeFrameOptionKey_ForceKeyFrame: kCFBooleanTrue] as CFDictionary
                : nil
            let presentationTime = CMTime(
                value: CMTimeValue(sequence),
                timescale: CMTimeScale(max(settings.targetFrameRate, 1))
            )
            let duration = CMTime(value: 1, timescale: CMTimeScale(max(settings.targetFrameRate, 1)))
            let status = VTCompressionSessionEncodeFrame(
                session,
                imageBuffer: sourceFrame.pixelBuffer,
                presentationTimeStamp: presentationTime,
                duration: duration,
                frameProperties: frameProperties,
                sourceFrameRefcon: retainedRequest.toOpaque(),
                infoFlagsOut: nil
            )

            guard status == noErr else {
                retainedRequest.release()
                request.finish(.failure(VideoToolboxEncoderError.encodeFailed(status)))
                return
            }
        }
    }

    private func configureIfNeeded(
        sourceFrame: CapturedSourceFrame,
        settings: StreamVideoSettings
    ) throws -> VTCompressionSession {
        let key = EncoderKey(
            codec: settings.codec,
            width: sourceFrame.width,
            height: sourceFrame.height,
            frameRate: settings.frameRate,
            bitrateMegabitsPerSecond: settings.bitrateMegabitsPerSecond,
            displayID: sourceFrame.displayID,
            viewport: sourceFrame.viewport
        )
        if let session, activeKey == key {
            return session
        }

        invalidate()
        let codecType = try Self.codecType(for: settings.codec)
        var nextSession: VTCompressionSession?
        let status = VTCompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            width: Int32(sourceFrame.width),
            height: Int32(sourceFrame.height),
            codecType: codecType,
            encoderSpecification: nil,
            imageBufferAttributes: nil,
            compressedDataAllocator: nil,
            outputCallback: videoCompressionOutputCallback,
            refcon: nil,
            compressionSessionOut: &nextSession
        )
        guard status == noErr, let nextSession else {
            throw VideoToolboxEncoderError.sessionCreationFailed(status)
        }

        try configure(nextSession, settings: settings)
        VTCompressionSessionPrepareToEncodeFrames(nextSession)
        session = nextSession
        activeKey = key
        needsKeyframe = true
        MiradorHostLog.stream.info(
            "video encoder configured codec=\(settings.codec.rawValue, privacy: .public) size=\(sourceFrame.width, privacy: .public)x\(sourceFrame.height, privacy: .public) fps=\(settings.targetFrameRate, privacy: .public) bitrateMbps=\(settings.bitrateMegabitsPerSecond, privacy: .public)"
        )
        return nextSession
    }

    private func configure(_ session: VTCompressionSession, settings: StreamVideoSettings) throws {
        try set(kVTCompressionPropertyKey_RealTime, kCFBooleanTrue, on: session)
        try set(kVTCompressionPropertyKey_AllowFrameReordering, kCFBooleanFalse, on: session)
        try set(
            kVTCompressionPropertyKey_ExpectedFrameRate,
            NSNumber(value: settings.targetFrameRate),
            on: session
        )
        try set(
            kVTCompressionPropertyKey_AverageBitRate,
            NSNumber(value: Int(settings.bitrateMegabitsPerSecond * 1_000_000)),
            on: session
        )
        try set(
            kVTCompressionPropertyKey_MaxKeyFrameInterval,
            NSNumber(value: max(settings.targetFrameRate, 1) * 2),
            on: session
        )
        try set(
            kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration,
            NSNumber(value: 2),
            on: session
        )
    }

    private func set(_ key: CFString, _ value: CFTypeRef, on session: VTCompressionSession) throws {
        let status = VTSessionSetProperty(session, key: key, value: value)
        guard status == noErr else {
            throw VideoToolboxEncoderError.propertyFailed(key as String, status)
        }
    }

    private static func codecType(for codec: StreamCodec) throws -> CMVideoCodecType {
        switch codec {
        case .h264:
            kCMVideoCodecType_H264
        case .hevc:
            kCMVideoCodecType_HEVC
        case .jpeg:
            throw VideoToolboxEncoderError.unsupportedCodec(codec)
        }
    }
}

private let videoCompressionOutputCallback: VTCompressionOutputCallback = { _, sourceFrameRefCon, status, _, sampleBuffer in
    guard let sourceFrameRefCon else { return }
    let request = Unmanaged<VideoToolboxEncoder.EncodeRequest>
        .fromOpaque(sourceFrameRefCon)
        .takeRetainedValue()

    guard status == noErr else {
        request.finish(.failure(VideoToolboxEncoderError.encodeFailed(status)))
        return
    }
    guard let sampleBuffer else {
        request.finish(.failure(VideoToolboxEncoderError.missingSampleBuffer))
        return
    }

    do {
        let frame = try EncodedVideoFrame(
            codec: request.codec,
            sequence: request.sequence,
            sourceFrame: request.sourceFrame,
            sampleBuffer: sampleBuffer
        )
        request.finish(.success(frame))
    } catch {
        request.finish(.failure(error))
    }
}

private extension EncodedVideoFrame {
    init(
        codec: StreamCodec,
        sequence: UInt64,
        sourceFrame: CapturedSourceFrame,
        sampleBuffer: CMSampleBuffer
    ) throws {
        let keyframe = sampleBuffer.isKeyframe
        self.init(
            codec: codec,
            sequence: sequence,
            capturedAt: sourceFrame.capturedAt,
            width: sourceFrame.width,
            height: sourceFrame.height,
            displayID: sourceFrame.displayID,
            qualityProfile: sourceFrame.qualityProfile,
            viewport: sourceFrame.viewport,
            sourceFrameNumber: sourceFrame.sourceFrameNumber,
            sourceFramesDropped: sourceFrame.sourceFramesDropped,
            isKeyframe: keyframe,
            format: keyframe ? try sampleBuffer.videoFormatMetadata(codec: codec) : nil,
            data: try sampleBuffer.encodedData()
        )
    }
}

private extension CMSampleBuffer {
    var isKeyframe: Bool {
        guard
            let attachments = CMSampleBufferGetSampleAttachmentsArray(
                self,
                createIfNecessary: false
            ) as? [NSDictionary],
            let attachment = attachments.first,
            let isNotSync = attachment[kCMSampleAttachmentKey_NotSync] as? Bool
        else {
            return true
        }
        return !isNotSync
    }

    func encodedData() throws -> Data {
        guard let dataBuffer = CMSampleBufferGetDataBuffer(self) else {
            throw VideoToolboxEncoderError.missingDataBuffer
        }

        var lengthAtOffset = 0
        var totalLength = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        let pointerStatus = CMBlockBufferGetDataPointer(
            dataBuffer,
            atOffset: 0,
            lengthAtOffsetOut: &lengthAtOffset,
            totalLengthOut: &totalLength,
            dataPointerOut: &dataPointer
        )
        if pointerStatus == noErr, let dataPointer, lengthAtOffset == totalLength {
            return Data(bytes: dataPointer, count: totalLength)
        }

        var data = Data(count: totalLength)
        let copyStatus = data.withUnsafeMutableBytes { buffer in
            CMBlockBufferCopyDataBytes(
                dataBuffer,
                atOffset: 0,
                dataLength: totalLength,
                destination: buffer.baseAddress!
            )
        }
        guard copyStatus == noErr else {
            throw VideoToolboxEncoderError.dataCopyFailed(copyStatus)
        }
        return data
    }

    func videoFormatMetadata(codec: StreamCodec) throws -> VideoFormatMetadata? {
        guard let description = CMSampleBufferGetFormatDescription(self) else {
            return nil
        }
        switch codec {
        case .h264:
            return try description.h264Metadata()
        case .hevc:
            return try description.hevcMetadata()
        case .jpeg:
            return nil
        }
    }
}

private extension CMFormatDescription {
    func h264Metadata() throws -> VideoFormatMetadata {
        var parameterSetCount = 0
        var nalUnitHeaderLength: Int32 = 0
        var status = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
            self,
            parameterSetIndex: 0,
            parameterSetPointerOut: nil,
            parameterSetSizeOut: nil,
            parameterSetCountOut: &parameterSetCount,
            nalUnitHeaderLengthOut: &nalUnitHeaderLength
        )
        guard status == noErr, parameterSetCount > 0 else {
            throw VideoToolboxEncoderError.parameterSetExtractionFailed(status)
        }

        var parameterSets: [Data] = []
        for index in 0..<parameterSetCount {
            var pointer: UnsafePointer<UInt8>?
            var size = 0
            status = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
                self,
                parameterSetIndex: index,
                parameterSetPointerOut: &pointer,
                parameterSetSizeOut: &size,
                parameterSetCountOut: nil,
                nalUnitHeaderLengthOut: nil
            )
            guard status == noErr, let pointer else {
                throw VideoToolboxEncoderError.parameterSetExtractionFailed(status)
            }
            parameterSets.append(Data(bytes: pointer, count: size))
        }
        return VideoFormatMetadata(
            parameterSets: parameterSets,
            nalUnitHeaderLength: Int(nalUnitHeaderLength)
        )
    }

    func hevcMetadata() throws -> VideoFormatMetadata {
        var parameterSetCount = 0
        var nalUnitHeaderLength: Int32 = 0
        var status = CMVideoFormatDescriptionGetHEVCParameterSetAtIndex(
            self,
            parameterSetIndex: 0,
            parameterSetPointerOut: nil,
            parameterSetSizeOut: nil,
            parameterSetCountOut: &parameterSetCount,
            nalUnitHeaderLengthOut: &nalUnitHeaderLength
        )
        guard status == noErr, parameterSetCount > 0 else {
            throw VideoToolboxEncoderError.parameterSetExtractionFailed(status)
        }

        var parameterSets: [Data] = []
        for index in 0..<parameterSetCount {
            var pointer: UnsafePointer<UInt8>?
            var size = 0
            status = CMVideoFormatDescriptionGetHEVCParameterSetAtIndex(
                self,
                parameterSetIndex: index,
                parameterSetPointerOut: &pointer,
                parameterSetSizeOut: &size,
                parameterSetCountOut: nil,
                nalUnitHeaderLengthOut: nil
            )
            guard status == noErr, let pointer else {
                throw VideoToolboxEncoderError.parameterSetExtractionFailed(status)
            }
            parameterSets.append(Data(bytes: pointer, count: size))
        }
        return VideoFormatMetadata(
            parameterSets: parameterSets,
            nalUnitHeaderLength: Int(nalUnitHeaderLength)
        )
    }
}

enum VideoToolboxEncoderError: LocalizedError {
    case unsupportedCodec(StreamCodec)
    case sessionCreationFailed(OSStatus)
    case propertyFailed(String, OSStatus)
    case encodeFailed(OSStatus)
    case missingSampleBuffer
    case missingDataBuffer
    case dataCopyFailed(OSStatus)
    case parameterSetExtractionFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case let .unsupportedCodec(codec):
            "Unsupported VideoToolbox codec: \(codec.rawValue)"
        case let .sessionCreationFailed(status):
            "VideoToolbox session creation failed: \(status)"
        case let .propertyFailed(key, status):
            "VideoToolbox property failed: \(key) status \(status)"
        case let .encodeFailed(status):
            "VideoToolbox encode failed: \(status)"
        case .missingSampleBuffer:
            "VideoToolbox did not return a compressed sample buffer"
        case .missingDataBuffer:
            "Compressed sample is missing a data buffer"
        case let .dataCopyFailed(status):
            "Compressed sample copy failed: \(status)"
        case let .parameterSetExtractionFailed(status):
            "Video format metadata extraction failed: \(status)"
        }
    }
}
