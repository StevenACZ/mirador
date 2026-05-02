import Foundation
import MiradorCore

extension PreviewViewport {
    var logSummary: String {
        String(
            format: "x=%.3f y=%.3f w=%.3f h=%.3f z=%.2f",
            normalizedX,
            normalizedY,
            normalizedWidth,
            normalizedHeight,
            zoomScale
        )
    }
}
