import SwiftUI

struct ClientPreviewPanelView: View {
    @Bindable var store: MiradorClientStore
    let isAuthenticated: Bool
    let onEnterFullScreen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PreviewFrameView(
                frame: store.latestFrame,
                count: store.receivedFrames,
                stats: store.streamStats,
                latencyMilliseconds: store.lastFrameLatencyMilliseconds
            )

            Button(action: onEnterFullScreen) {
                Label("Enter Full Screen", systemImage: "arrow.up.left.and.arrow.down.right")
            }
            .buttonStyle(.borderedProminent)
            .disabled(!isAuthenticated || store.latestFrame == nil)
        }
    }
}
