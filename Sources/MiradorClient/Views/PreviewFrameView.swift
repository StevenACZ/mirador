import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
import MiradorCore

struct PreviewFrameView: View {
    let frame: PreviewFrame?
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let frame {
                previewImage(for: frame)
                    .aspectRatio(CGFloat(frame.width) / CGFloat(frame.height), contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Text("Frames received: \(count) | \(frame.width) x \(frame.height)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            } else {
                ContentUnavailableView(
                    "No Preview Yet",
                    systemImage: "photo",
                    description: Text("Authenticate with the host PIN to receive frames.")
                )
                .frame(maxWidth: .infinity, minHeight: 180)
            }
        }
    }

    @ViewBuilder
    private func previewImage(for frame: PreviewFrame) -> some View {
        #if canImport(UIKit)
        if let image = UIImage(data: frame.jpegData) {
            Image(uiImage: image)
                .resizable()
        }
        #elseif canImport(AppKit)
        if let image = NSImage(data: frame.jpegData) {
            Image(nsImage: image)
                .resizable()
        }
        #endif
    }
}
