import CoreMedia
import Foundation
@preconcurrency import ScreenCaptureKit

struct SystemAudioSampleObservation: Sendable {
    let sampleCount: UInt64
    let sampleRate: Int?
    let channelCount: Int?
    let byteCount: UInt64

    init(sampleBuffer: CMSampleBuffer) {
        sampleCount = UInt64(max(CMSampleBufferGetNumSamples(sampleBuffer), 0))
        byteCount = UInt64(max(CMSampleBufferGetTotalSampleSize(sampleBuffer), 0))
        guard
            let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer),
            let description = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)
        else {
            sampleRate = nil
            channelCount = nil
            return
        }
        sampleRate = Int(description.pointee.mSampleRate)
        channelCount = Int(description.pointee.mChannelsPerFrame)
    }
}

final class SystemAudioStreamOutput: NSObject, SCStreamOutput, @unchecked Sendable {
    private let onObservation: @Sendable (SystemAudioSampleObservation) -> Void

    init(onObservation: @escaping @Sendable (SystemAudioSampleObservation) -> Void) {
        self.onObservation = onObservation
    }

    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of type: SCStreamOutputType
    ) {
        guard type == .audio else { return }
        onObservation(SystemAudioSampleObservation(sampleBuffer: sampleBuffer))
    }
}
