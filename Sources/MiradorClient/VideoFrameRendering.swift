import Foundation
import MiradorCore

@MainActor
protocol VideoFrameRendering: AnyObject {
    func enqueue(_ frame: EncodedVideoFrame)
    func flush()
}
