import Foundation
import SwiftUI
import MiradorCore

struct HostStatusSidebarView: View {
    let controller: HostController

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(MiradorConstants.appName)
                .font(.title2.weight(.semibold))

            statusGroup(
                title: "Host",
                rows: [
                    ("antenna.radiowaves.left.and.right", controller.networkStatus),
                    ("lock.shield", controller.permissionStatus),
                    ("display", controller.captureStatus)
                ]
            )

            statusGroup(
                title: "Stream",
                rows: [
                    ("network", "Bonjour: \(MiradorConstants.bonjourServiceType)"),
                    ("speedometer", "\(controller.videoSettings.targetFrameRate) FPS target"),
                    ("photo.on.rectangle", "\(controller.streamedFrames) frames sent")
                ]
            )

            statusGroup(
                title: "Control",
                rows: [
                    ("cursorarrow.click", controller.remoteControlStatus),
                    ("person.crop.circle.badge.checkmark", "\(controller.activeAuthenticatedSessions) active sessions"),
                    ("point.topleft.down.curvedto.point.bottomright.up", "\(controller.appliedInputEvents) inputs applied")
                ]
            )

            statusGroup(
                title: "Diagnostics",
                rows: [
                    ("slider.horizontal.3", controller.videoSettings.summary),
                    ("waveform.path.ecg", statsSummary),
                    ("viewfinder", zoomSummary)
                ]
            )

            Spacer()
        }
        .padding(22)
        .frame(width: 250, alignment: .topLeading)
        .background(.bar)
    }

    private func statusGroup(title: String, rows: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(rows, id: \.1) { image, text in
                Label(text, systemImage: image)
                    .font(.callout)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var statsSummary: String {
        controller.streamStats.map {
            String(
                format: "%.0f/%d FPS / %.0f kbps",
                $0.effectiveFramesPerSecond,
                $0.targetFrameRate,
                $0.bitrateKilobitsPerSecond
            )
        } ?? "Waiting for stream"
    }

    private var zoomSummary: String {
        let zoom = controller.previewViewport.zoomScale
        return zoom > 1.01 ? String(format: "%.1fx crop", zoom) : "Full display"
    }
}
