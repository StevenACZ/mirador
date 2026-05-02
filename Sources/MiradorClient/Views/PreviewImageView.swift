import SwiftUI
import ImageIO
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
import MiradorCore

struct PreviewImageView: View {
    let frame: PreviewFrame
    @StateObject private var renderer = PreviewFrameRenderer()

    var body: some View {
        Group {
            if let renderedFrame = renderer.renderedFrame {
                renderedFrame.image
                    .resizable()
            } else {
                Color.black
            }
        }
        .onAppear {
            renderer.enqueue(frame)
        }
        .onChange(of: frame.sequence) { _, _ in
            renderer.enqueue(frame)
        }
    }
}

private struct RenderedPreviewFrame {
    let sequence: UInt64
    let image: Image
}

private struct PreviewFrameSnapshot: Sendable {
    let sequence: UInt64
    let jpegData: Data
    let width: Int
    let height: Int

    init(_ frame: PreviewFrame) {
        sequence = frame.sequence
        jpegData = frame.jpegData
        width = frame.width
        height = frame.height
    }
}

private struct DecodedPreviewImage: @unchecked Sendable {
    let sequence: UInt64
    let cgImage: CGImage
    let width: Int
    let height: Int
}

@MainActor
private final class PreviewFrameRenderer: ObservableObject {
    @Published var renderedFrame: RenderedPreviewFrame?

    private var latestFrame: PreviewFrameSnapshot?
    private var isDecoding = false

    func enqueue(_ frame: PreviewFrame) {
        latestFrame = PreviewFrameSnapshot(frame)
        guard !isDecoding else { return }
        decodeLatestFrame()
    }

    private func decodeLatestFrame() {
        guard let snapshot = latestFrame else {
            isDecoding = false
            return
        }

        latestFrame = nil
        isDecoding = true
        let decodeTask = Task.detached(priority: .userInitiated) {
            PreviewJPEGDecoder.decode(snapshot)
        }

        Task { @MainActor [weak self] in
            let decoded = await decodeTask.value
            self?.finish(decoded)
        }
    }

    private func finish(_ decoded: DecodedPreviewImage?) {
        if let decoded, decoded.sequence > (renderedFrame?.sequence ?? 0) {
            #if canImport(UIKit)
            let image = Image(uiImage: UIImage(cgImage: decoded.cgImage))
            #elseif canImport(AppKit)
            let size = NSSize(width: decoded.width, height: decoded.height)
            let image = Image(nsImage: NSImage(cgImage: decoded.cgImage, size: size))
            #endif
            renderedFrame = RenderedPreviewFrame(sequence: decoded.sequence, image: image)
        }

        isDecoding = false
        if latestFrame != nil {
            decodeLatestFrame()
        }
    }
}

private enum PreviewJPEGDecoder {
    static func decode(_ snapshot: PreviewFrameSnapshot) -> DecodedPreviewImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        let decodeOptions = [
            kCGImageSourceShouldCache: false,
            kCGImageSourceShouldCacheImmediately: true
        ] as CFDictionary
        guard
            let source = CGImageSourceCreateWithData(snapshot.jpegData as CFData, sourceOptions),
            let image = CGImageSourceCreateImageAtIndex(source, 0, decodeOptions)
        else {
            return nil
        }

        return DecodedPreviewImage(
            sequence: snapshot.sequence,
            cgImage: image,
            width: snapshot.width,
            height: snapshot.height
        )
    }
}
