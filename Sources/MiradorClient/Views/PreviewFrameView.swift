import SwiftUI
import MiradorCore

struct PreviewFrameView: View {
    @Bindable var store: MiradorClientStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let frame = store.latestFrame {
                GeometryReader { geometry in
                    PreviewImageView(frame: frame)
                        .aspectRatio(CGFloat(frame.width) / CGFloat(frame.height), contentMode: .fit)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .background(Color.black)
                        .overlay(alignment: .topLeading) {
                            statsOverlay(for: frame)
                        }
                }
                .aspectRatio(CGFloat(frame.width) / CGFloat(frame.height), contentMode: .fit)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                Text(frameSummary(for: frame))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            } else if let info = store.latestVideoFrameInfo {
                GeometryReader { geometry in
                    VideoFrameSurface(store: store)
                        .aspectRatio(CGFloat(info.width) / CGFloat(info.height), contentMode: .fit)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .background(Color.black)
                        .overlay(alignment: .topLeading) {
                            statsOverlay(for: info)
                        }
                }
                .aspectRatio(CGFloat(info.width) / CGFloat(info.height), contentMode: .fit)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                Text(frameSummary(for: info))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            } else {
                ContentUnavailableView(
                    "No Preview Yet",
                    systemImage: "photo",
                    description: Text("Connect to a local Mirador host to receive frames.")
                )
                .frame(maxWidth: .infinity, minHeight: 180)
            }
        }
    }

    private func frameSummary(for frame: PreviewFrame) -> String {
        let zoom = frame.viewport.zoomScale
        let zoomLabel = zoom > 1.01 ? String(format: " | %.1fx crop", zoom) : ""
        return "Frames received: \(store.receivedFrames) | \(frame.width) x \(frame.height)\(zoomLabel)"
    }

    private func frameSummary(for frame: StreamFrameInfo) -> String {
        let zoom = frame.viewport.zoomScale
        let zoomLabel = zoom > 1.01 ? String(format: " | %.1fx crop", zoom) : ""
        return "Frames received: \(store.receivedFrames) | \(frame.codec.displayName) | \(frame.width) x \(frame.height)\(zoomLabel)"
    }

    private func statsOverlay(for frame: PreviewFrame) -> some View {
        statsOverlay(width: frame.width, height: frame.height)
    }

    private func statsOverlay(for frame: StreamFrameInfo) -> some View {
        statsOverlay(width: frame.width, height: frame.height)
    }

    private func statsOverlay(width: Int, height: Int) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("\(width) x \(height)")

            if let stats = store.streamStats {
                Text(stats.codec.displayName)
                Text("\(stats.sentFramesPerSecond, specifier: "%.0f")/\(stats.targetFrameRate) sent")
                Text("\(stats.sourceFramesPerSecond, specifier: "%.0f") source FPS")
                Text("\(stats.bitrateKilobitsPerSecond / 1_000, specifier: "%.1f") Mbps")
                Text("\(stats.repeatedFrameRate * 100, specifier: "%.0f")% repeat")
                Text("\(stats.sourceDropRate * 100, specifier: "%.1f")% drop")
            }

            if let latencyMilliseconds = store.lastFrameLatencyMilliseconds {
                Text("\(latencyMilliseconds, specifier: "%.0f") ms")
            }
        }
        .font(.caption2.monospacedDigit())
        .foregroundStyle(.white)
        .padding(7)
        .background(.black.opacity(0.62))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .padding(8)
        .accessibilityLabel("Stream statistics")
    }
}
