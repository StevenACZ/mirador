import SwiftUI
import MiradorCore

struct HostDashboardView: View {
    @Bindable var controller: HostController

    var body: some View {
        NavigationSplitView {
            List {
                Section("Host") {
                    Label(controller.networkStatus, systemImage: "antenna.radiowaves.left.and.right")
                    Label(controller.permissionStatus, systemImage: "lock.shield")
                    Label(controller.captureStatus, systemImage: "display")
                }

                Section("MVP1") {
                    Label("Bonjour: \(MiradorConstants.bonjourServiceType)", systemImage: "network")
                    Label("\(MiradorConstants.mvpFrameRate) FPS target", systemImage: "speedometer")
                }
            }
            .listStyle(.sidebar)
            .navigationTitle(MiradorConstants.appName)
        } detail: {
            VStack(alignment: .leading, spacing: 24) {
                header
                pinPanel
                actions
                displayList
                Spacer()
            }
            .padding(28)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Mac Host")
                .font(.largeTitle.weight(.semibold))

            Text("The listener is lightweight while idle. Screen capture starts only after a client authenticates with the current PIN.")
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

            Text("Use this PIN from the iPhone or iPad for the MVP1 session.")
                .font(.footnote)
                .foregroundStyle(.secondary)
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
                ContentUnavailableView(
                    "No Display Session Yet",
                    systemImage: "display",
                    description: Text("Displays are loaded after a client authenticates.")
                )
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
