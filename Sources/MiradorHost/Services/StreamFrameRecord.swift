import Foundation
import MiradorCore

struct StreamFrameRecord {
    let codec: StreamCodec
    let sequence: UInt64
    let width: Int
    let height: Int
    let displayID: UInt32?
    let qualityProfile: StreamQualityProfile
    let viewport: PreviewViewport
    let sourceFrameNumber: UInt64
    let sourceFramesDropped: Int
    let isRepeatedSourceFrame: Bool
    let byteCount: Int

    init(previewFrame frame: PreviewFrame) {
        codec = .jpeg
        sequence = frame.sequence
        width = frame.width
        height = frame.height
        displayID = frame.displayID
        qualityProfile = frame.qualityProfile
        viewport = frame.viewport
        sourceFrameNumber = frame.sourceFrameNumber
        sourceFramesDropped = frame.sourceFramesDropped
        isRepeatedSourceFrame = false
        byteCount = frame.jpegData.count
    }

    init(videoFrame frame: EncodedVideoFrame, isRepeatedSourceFrame: Bool) {
        codec = frame.codec
        sequence = frame.sequence
        width = frame.width
        height = frame.height
        displayID = frame.displayID
        qualityProfile = frame.qualityProfile
        viewport = frame.viewport
        sourceFrameNumber = frame.sourceFrameNumber
        sourceFramesDropped = frame.sourceFramesDropped
        self.isRepeatedSourceFrame = isRepeatedSourceFrame
        byteCount = frame.data.count
    }
}
