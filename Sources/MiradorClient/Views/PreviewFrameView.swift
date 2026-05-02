import SwiftUI
import MiradorCore

struct PreviewFrameView: View {
    let frame: PreviewFrame?
    let count: Int
    let stats: StreamStats?
    let latencyMilliseconds: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let frame {
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
        return "Frames received: \(count) | \(frame.width) x \(frame.height)\(zoomLabel)"
    }

    private func statsOverlay(for frame: PreviewFrame) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("\(frame.width) x \(frame.height)")

            if let stats {
                Text("\(stats.effectiveFramesPerSecond, specifier: "%.0f")/\(stats.targetFrameRate) FPS")
                Text("\(stats.bitrateKilobitsPerSecond / 1_000, specifier: "%.1f") Mbps")
                Text("\(stats.sourceDropRate * 100, specifier: "%.1f")% drop")
            }

            if let latencyMilliseconds {
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
