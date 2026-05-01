import SwiftUI
import MiradorCore

public struct HostDashboardView: View {
    @Bindable var controller: HostController

    public init(controller: HostController) {
        self.controller = controller
    }

    public var body: some View {
        HStack(spacing: 0) {
            sidebar

            Divider()

            VStack(alignment: .leading, spacing: 24) {
                header
                pinPanel
                actions
                displayList
                Spacer()
            }
            .padding(28)
        }
        .frame(minWidth: 760, minHeight: 520)
    }

    private var sidebar: some View {
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
                title: "MVP1",
                rows: [
                    ("network", "Bonjour: \(MiradorConstants.bonjourServiceType)"),
                    ("speedometer", "\(MiradorConstants.mvpFrameRate) FPS target"),
                    ("photo.on.rectangle", "\(controller.streamedFrames) frames sent")
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

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Mac Host")
                .font(.largeTitle.weight(.semibold))

            Text("Screen capture stays idle until a client authenticates with the current PIN.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var pinPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Session PIN")
                .font(.headline)

            Text(controller.sessionPIN.value)
                .font(.system(size: 44, weight: .semibold, design: .monospaced))
                .contentTransition(.numericText())
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var actions: some View {
        HStack(spacing: 12) {
            Button {
                controller.toggleAdvertising()
            } label: {
                Label(
                    controller.isAdvertising ? "Stop Listener" : "Start Listener",
                    systemImage: controller.isAdvertising ? "pause.circle" : "play.circle"
                )
            }
            .buttonStyle(.borderedProminent)

            Button {
                controller.rotatePIN()
            } label: {
                Label("Rotate PIN", systemImage: "arrow.triangle.2.circlepath")
            }

            Button {
                controller.requestScreenCapturePermission()
            } label: {
                Label("Screen Permission", systemImage: "lock.open.display")
            }

            Button {
                controller.refreshPermissionStatus()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .accessibilityLabel("Refresh permission status")
        }
    }

    private var displayList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Displays")
                .font(.headline)

            if controller.displays.isEmpty {
                Label("No display session yet", systemImage: "display")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                ForEach(controller.displays) { display in
                    HStack {
                        Image(systemName: "display")
                            .foregroundStyle(.secondary)
                        Text(display.title)
                        Spacer()
                        Text("\(display.width) x \(display.height)")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    .padding(.vertical, 6)
                }
            }
        }
    }
}
