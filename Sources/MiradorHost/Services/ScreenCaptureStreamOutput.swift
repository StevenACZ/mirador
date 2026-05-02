import CoreMedia
import Foundation
@preconcurrency import ScreenCaptureKit

final class ScreenCaptureStreamOutput: NSObject, SCStreamOutput {
    private let frameBuffer: ScreenCaptureFrameBuffer
    private var receivedFrames = 0
    private var skippedFrames = 0

    init(frameBuffer: ScreenCaptureFrameBuffer) {
        self.frameBuffer = frameBuffer
    }

    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of type: SCStreamOutputType
    ) {
        guard type == .screen, sampleBuffer.isValid else { return }
        guard frameStatus(for: sampleBuffer) == .complete else {
            skippedFrames += 1
            if skippedFrames == 1 || skippedFrames.isMultiple(of: 120) {
                MiradorHostLog.stream.debug(
                    "screen stream skipped non-complete frames=\(self.skippedFrames, privacy: .public)"
                )
            }
            return
        }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            MiradorHostLog.stream.debug("screen stream delivered sample without image buffer")
            return
        }

        receivedFrames += 1
        if receivedFrames == 1 || receivedFrames.isMultiple(of: 120) {
            MiradorHostLog.stream.debug(
                "screen stream source frames=\(self.receivedFrames, privacy: .public)"
            )
        }

        frameBuffer.publish(pixelBuffer: pixelBuffer, capturedAt: Date())
    }

    private func frameStatus(for sampleBuffer: CMSampleBuffer) -> SCFrameStatus? {
        guard
            let attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(
                sampleBuffer,
                createIfNecessary: false
            ) as? [[SCStreamFrameInfo: Any]],
            let attachments = attachmentsArray.first,
            let rawStatus = attachments[SCStreamFrameInfo.status] as? Int
        else {
            return nil
        }

        return SCFrameStatus(rawValue: rawStatus)
    }
}
