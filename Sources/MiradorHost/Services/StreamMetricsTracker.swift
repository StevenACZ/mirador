import Foundation
import MiradorCore

struct StreamMetricsTracker {
    private var windowStart = Date()
    private var windowFrames = 0
    private var windowSourceFrames = 0
    private var windowRepeatedFrames = 0
    private var windowBytes = 0
    private var windowSourceFramesDropped = 0
    private var windowCaptureDurationMilliseconds = 0.0
    private var windowCaptureWaitDurationMilliseconds = 0.0
    private var windowSendDurationMilliseconds = 0.0
    private var totalFrames = 0
    private var totalRepeatedFrames = 0
    private var totalBytes = 0
    private var totalSourceFramesDropped = 0

    mutating func reset() {
        windowStart = Date()
        windowFrames = 0
        windowSourceFrames = 0
        windowRepeatedFrames = 0
        windowBytes = 0
        windowSourceFramesDropped = 0
        windowCaptureDurationMilliseconds = 0
        windowCaptureWaitDurationMilliseconds = 0
        windowSendDurationMilliseconds = 0
        totalFrames = 0
        totalRepeatedFrames = 0
        totalBytes = 0
        totalSourceFramesDropped = 0
    }

    mutating func record(
        frame: StreamFrameRecord,
        captureDurationMilliseconds: Double,
        captureWaitDurationMilliseconds: Double,
        sendDurationMilliseconds: Double,
        targetFrameRate: Int
    ) -> StreamStats? {
        let byteCount = frame.byteCount
        windowFrames += 1
        if frame.isRepeatedSourceFrame {
            windowRepeatedFrames += 1
        } else {
            windowSourceFrames += 1
        }
        windowBytes += byteCount
        windowSourceFramesDropped += frame.sourceFramesDropped
        windowCaptureDurationMilliseconds += captureDurationMilliseconds
        windowCaptureWaitDurationMilliseconds += captureWaitDurationMilliseconds
        windowSendDurationMilliseconds += sendDurationMilliseconds
        totalFrames += 1
        if frame.isRepeatedSourceFrame {
            totalRepeatedFrames += 1
        }
        totalBytes += byteCount
        totalSourceFramesDropped += frame.sourceFramesDropped

        let now = Date()
        let elapsed = now.timeIntervalSince(windowStart)
        guard elapsed >= 1 else { return nil }
        let sourceFramesObserved = windowSourceFrames + windowSourceFramesDropped
        let sourceDropRate = sourceFramesObserved > 0
            ? Double(windowSourceFramesDropped) / Double(sourceFramesObserved)
            : 0
        let sentFramesPerSecond = Double(windowFrames) / elapsed
        let repeatedFrameRate = windowFrames > 0
            ? Double(windowRepeatedFrames) / Double(windowFrames)
            : 0
        let averageCaptureDuration = windowCaptureDurationMilliseconds / Double(max(windowFrames, 1))
        let averageCaptureWaitDuration = windowCaptureWaitDurationMilliseconds / Double(max(windowFrames, 1))
        let averageSendDuration = windowSendDurationMilliseconds / Double(max(windowFrames, 1))

        let stats = StreamStats(
            capturedAt: now,
            framesSent: totalFrames,
            bytesSent: totalBytes,
            effectiveFramesPerSecond: sentFramesPerSecond,
            sourceFramesPerSecond: Double(windowSourceFrames) / elapsed,
            encodedFramesPerSecond: sentFramesPerSecond,
            sentFramesPerSecond: sentFramesPerSecond,
            bitrateKilobitsPerSecond: Double(windowBytes * 8) / elapsed / 1_000,
            lastFrameBytes: byteCount,
            captureDurationMilliseconds: averageCaptureDuration,
            captureWaitDurationMilliseconds: averageCaptureWaitDuration,
            sendDurationMilliseconds: averageSendDuration,
            targetFrameRate: targetFrameRate,
            codec: frame.codec,
            qualityProfile: frame.qualityProfile,
            displayID: frame.displayID,
            sourceFramesDropped: totalSourceFramesDropped,
            sourceDropRate: sourceDropRate,
            repeatedFrames: totalRepeatedFrames,
            repeatedFrameRate: repeatedFrameRate
        )

        windowStart = now
        windowFrames = 0
        windowSourceFrames = 0
        windowRepeatedFrames = 0
        windowBytes = 0
        windowSourceFramesDropped = 0
        windowCaptureDurationMilliseconds = 0
        windowCaptureWaitDurationMilliseconds = 0
        windowSendDurationMilliseconds = 0
        return stats
    }
}
