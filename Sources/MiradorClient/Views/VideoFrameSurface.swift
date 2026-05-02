#if os(iOS)
import AVFoundation
import CoreMedia
import SwiftUI
import UIKit
import MiradorCore

struct VideoFrameSurface: UIViewRepresentable {
    @Bindable var store: MiradorClientStore

    func makeCoordinator() -> Coordinator {
        Coordinator(store: store)
    }

    func makeUIView(context: Context) -> VideoSampleBufferView {
        let view = VideoSampleBufferView()
        context.coordinator.renderer = view
        store.attachVideoFrameRenderer(view)
        return view
    }

    func updateUIView(_ uiView: VideoSampleBufferView, context: Context) {
        if context.coordinator.renderer !== uiView {
            context.coordinator.renderer = uiView
            store.attachVideoFrameRenderer(uiView)
        }
    }

    static func dismantleUIView(_ uiView: VideoSampleBufferView, coordinator: Coordinator) {
        coordinator.store.detachVideoFrameRenderer(uiView)
    }

    final class Coordinator {
        let store: MiradorClientStore
        weak var renderer: VideoSampleBufferView?

        init(store: MiradorClientStore) {
            self.store = store
        }
    }
}

final class VideoSampleBufferView: UIView, VideoFrameRendering {
    private var formatDescription: CMFormatDescription?
    private var formatKey: VideoFormatKey?
    private var lastSequence: UInt64?

    override static var layerClass: AnyClass {
        AVSampleBufferDisplayLayer.self
    }

    private var displayLayer: AVSampleBufferDisplayLayer {
        layer as! AVSampleBufferDisplayLayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureLayer()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureLayer()
    }

    func enqueue(_ frame: EncodedVideoFrame) {
        guard frame.codec.isVideoToolboxCodec else { return }
        do {
            try updateFormatDescriptionIfNeeded(for: frame)
            guard let formatDescription else { return }
            recoverLayerIfNeeded()
            let sampleBuffer = try CMSampleBuffer.videoSample(
                frame: frame,
                formatDescription: formatDescription
            )
            displayLayer.enqueue(sampleBuffer)
            lastSequence = frame.sequence
        } catch {
            MiradorClientLog.stream.error(
                "video frame render failed codec=\(frame.codec.rawValue, privacy: .public) seq=\(frame.sequence, privacy: .public) error=\(error.localizedDescription, privacy: .public)"
            )
            flush()
        }
    }

    func flush() {
        displayLayer.flushAndRemoveImage()
        formatDescription = nil
        formatKey = nil
        lastSequence = nil
    }

    private func configureLayer() {
        backgroundColor = .black
        displayLayer.videoGravity = .resizeAspect
        displayLayer.backgroundColor = UIColor.black.cgColor
    }

    private func recoverLayerIfNeeded() {
        guard displayLayer.status == .failed else { return }
        displayLayer.flushAndRemoveImage()
    }

    private func updateFormatDescriptionIfNeeded(for frame: EncodedVideoFrame) throws {
        if let lastSequence, frame.sequence <= lastSequence {
            return
        }
        guard let metadata = frame.format else {
            return
        }

        let nextKey = VideoFormatKey(
            codec: frame.codec,
            width: frame.width,
            height: frame.height,
            metadata: metadata
        )
        guard nextKey != formatKey else { return }

        formatDescription = try CMFormatDescription.videoDescription(
            codec: frame.codec,
            metadata: metadata
        )
        formatKey = nextKey
        displayLayer.flush()
    }
}

private struct VideoFormatKey: Equatable {
    let codec: StreamCodec
    let width: Int
    let height: Int
    let parameterSets: [Data]
    let nalUnitHeaderLength: Int

    init(codec: StreamCodec, width: Int, height: Int, metadata: VideoFormatMetadata) {
        self.codec = codec
        self.width = width
        self.height = height
        self.parameterSets = metadata.parameterSets
        self.nalUnitHeaderLength = metadata.nalUnitHeaderLength
    }
}

private extension CMFormatDescription {
    static func videoDescription(
        codec: StreamCodec,
        metadata: VideoFormatMetadata
    ) throws -> CMFormatDescription {
        guard !metadata.parameterSets.isEmpty else {
            throw VideoSampleBufferError.missingFormatMetadata
        }

        let retainedSets = metadata.parameterSets.map { $0 as NSData }
        var parameterSetPointers = retainedSets.map {
            $0.bytes.assumingMemoryBound(to: UInt8.self)
        }
        var parameterSetSizes = retainedSets.map(\.length)
        var description: CMFormatDescription?
        let status = parameterSetPointers.withUnsafeBufferPointer { pointerBuffer in
            parameterSetSizes.withUnsafeBufferPointer { sizeBuffer in
                switch codec {
                case .h264:
                    CMVideoFormatDescriptionCreateFromH264ParameterSets(
                        allocator: kCFAllocatorDefault,
                        parameterSetCount: pointerBuffer.count,
                        parameterSetPointers: pointerBuffer.baseAddress!,
                        parameterSetSizes: sizeBuffer.baseAddress!,
                        nalUnitHeaderLength: Int32(metadata.nalUnitHeaderLength),
                        formatDescriptionOut: &description
                    )
                case .hevc:
                    CMVideoFormatDescriptionCreateFromHEVCParameterSets(
                        allocator: kCFAllocatorDefault,
                        parameterSetCount: pointerBuffer.count,
                        parameterSetPointers: pointerBuffer.baseAddress!,
                        parameterSetSizes: sizeBuffer.baseAddress!,
                        nalUnitHeaderLength: Int32(metadata.nalUnitHeaderLength),
                        extensions: nil,
                        formatDescriptionOut: &description
                    )
                case .jpeg:
                    kCMFormatDescriptionBridgeError_InvalidParameter
                }
            }
        }
        guard status == noErr, let description else {
            throw VideoSampleBufferError.formatDescriptionFailed(status)
        }
        return description
    }
}

private extension CMSampleBuffer {
    static func videoSample(
        frame: EncodedVideoFrame,
        formatDescription: CMFormatDescription
    ) throws -> CMSampleBuffer {
        var blockBuffer: CMBlockBuffer?
        var status = CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault,
            memoryBlock: nil,
            blockLength: frame.data.count,
            blockAllocator: kCFAllocatorDefault,
            customBlockSource: nil,
            offsetToData: 0,
            dataLength: frame.data.count,
            flags: 0,
            blockBufferOut: &blockBuffer
        )
        guard status == noErr, let blockBuffer else {
            throw VideoSampleBufferError.blockBufferFailed(status)
        }

        status = frame.data.withUnsafeBytes { buffer in
            CMBlockBufferReplaceDataBytes(
                with: buffer.baseAddress!,
                blockBuffer: blockBuffer,
                offsetIntoDestination: 0,
                dataLength: frame.data.count
            )
        }
        guard status == noErr else {
            throw VideoSampleBufferError.blockBufferFailed(status)
        }

        var timing = CMSampleTimingInfo(
            duration: .invalid,
            presentationTimeStamp: CMTime(
                seconds: frame.capturedAt.timeIntervalSinceReferenceDate,
                preferredTimescale: 1_000_000
            ),
            decodeTimeStamp: .invalid
        )
        var sampleSize = frame.data.count
        var sampleBuffer: CMSampleBuffer?
        status = CMSampleBufferCreateReady(
            allocator: kCFAllocatorDefault,
            dataBuffer: blockBuffer,
            formatDescription: formatDescription,
            sampleCount: 1,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timing,
            sampleSizeEntryCount: 1,
            sampleSizeArray: &sampleSize,
            sampleBufferOut: &sampleBuffer
        )
        guard status == noErr, let sampleBuffer else {
            throw VideoSampleBufferError.sampleBufferFailed(status)
        }

        if let attachments = CMSampleBufferGetSampleAttachmentsArray(
            sampleBuffer,
            createIfNecessary: true
        ) as? [NSMutableDictionary] {
            attachments.first?[kCMSampleAttachmentKey_DisplayImmediately] = true
        }
        return sampleBuffer
    }
}

private enum VideoSampleBufferError: LocalizedError {
    case missingFormatMetadata
    case formatDescriptionFailed(OSStatus)
    case blockBufferFailed(OSStatus)
    case sampleBufferFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .missingFormatMetadata:
            "Missing video format metadata"
        case let .formatDescriptionFailed(status):
            "Video format description failed: \(status)"
        case let .blockBufferFailed(status):
            "Video block buffer failed: \(status)"
        case let .sampleBufferFailed(status):
            "Video sample buffer failed: \(status)"
        }
    }
}
#else
import SwiftUI
import MiradorCore

struct VideoFrameSurface: View {
    @Bindable var store: MiradorClientStore

    var body: some View {
        Color.black
            .onAppear {
                store.flushVideoRenderers()
            }
    }
}
#endif
