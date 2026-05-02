import CoreVideo
import Foundation

struct ScreenCaptureSourceFrame: @unchecked Sendable {
    let number: UInt64
    let pixelBuffer: CVPixelBuffer
    let capturedAt: Date
}

final class ScreenCaptureFrameBuffer: @unchecked Sendable {
    private struct FrameWaiter {
        let afterNumber: UInt64
        let continuation: CheckedContinuation<ScreenCaptureSourceFrame, Error>
    }

    private let lock = NSLock()
    private var latestFrame: ScreenCaptureSourceFrame?
    private var nextFrameNumber: UInt64 = 0
    private var waiters: [UUID: FrameWaiter] = [:]

    func publish(pixelBuffer: CVPixelBuffer, capturedAt: Date) {
        let readyWaiters: [FrameWaiter]

        lock.lock()
        nextFrameNumber += 1
        let frame = ScreenCaptureSourceFrame(
            number: nextFrameNumber,
            pixelBuffer: pixelBuffer,
            capturedAt: capturedAt
        )
        latestFrame = frame

        let readyWaiterEntries = waiters.filter { frame.number > $0.value.afterNumber }
        for (id, _) in readyWaiterEntries {
            waiters[id] = nil
        }
        readyWaiters = readyWaiterEntries.map(\.value)
        lock.unlock()

        readyWaiters.forEach { $0.continuation.resume(returning: frame) }
    }

    func nextFrame(after frameNumber: UInt64) async throws -> ScreenCaptureSourceFrame {
        let waiterID = UUID()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                lock.lock()
                if let latestFrame, latestFrame.number > frameNumber {
                    lock.unlock()
                    continuation.resume(returning: latestFrame)
                    return
                }

                waiters[waiterID] = FrameWaiter(
                    afterNumber: frameNumber,
                    continuation: continuation
                )
                lock.unlock()
            }
        } onCancel: {
            self.cancelWaiter(id: waiterID)
        }
    }

    func latestPublishedFrame() -> ScreenCaptureSourceFrame? {
        lock.lock()
        let frame = latestFrame
        lock.unlock()
        return frame
    }

    func reset() {
        lock.lock()
        latestFrame = nil
        nextFrameNumber = 0
        let pendingWaiters = waiters.values
        waiters.removeAll()
        lock.unlock()

        for waiter in pendingWaiters {
            waiter.continuation.resume(throwing: CancellationError())
        }
    }

    private func cancelWaiter(id: UUID) {
        lock.lock()
        guard let waiter = waiters.removeValue(forKey: id) else {
            lock.unlock()
            return
        }
        lock.unlock()
        waiter.continuation.resume(throwing: CancellationError())
    }
}
