import Foundation
import MiradorCore

extension MiradorClientStore {
    func attachVideoFrameRenderer(_ renderer: any VideoFrameRendering) {
        videoFrameRenderers[ObjectIdentifier(renderer)] = renderer
        renderer.flush()
    }

    func detachVideoFrameRenderer(_ renderer: any VideoFrameRendering) {
        videoFrameRenderers.removeValue(forKey: ObjectIdentifier(renderer))
    }

    func enqueueVideoFrame(_ frame: EncodedVideoFrame) {
        for renderer in videoFrameRenderers.values {
            renderer.enqueue(frame)
        }
    }

    func flushVideoRenderers() {
        for renderer in videoFrameRenderers.values {
            renderer.flush()
        }
    }

    func resetRenderedStreamFrames() {
        latestFrame = nil
        latestVideoFrameInfo = nil
        receivedFrames = 0
        lastFrameLatencyMilliseconds = nil
        flushVideoRenderers()
    }
}
