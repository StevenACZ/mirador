import Foundation
import SwiftUI
import MiradorCore

public struct HostDashboardView: View {
    @Bindable var controller: HostController

    public init(controller: HostController) {
        self.controller = controller
    }

    public var body: some View {
        HStack(spacing: 0) {
            HostStatusSidebarView(controller: controller)

            Divider()

            VStack(alignment: .leading, spacing: 24) {
                header
                actions
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        controlPanel
                        streamPanel
                        audioPanel
                        displayList
                        HostTrustedClientsView(controller: controller)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                Spacer()
            }
            .padding(28)
        }
        .frame(minWidth: 760, minHeight: 520)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Mac Host")
                .font(.largeTitle.weight(.semibold))

            Text("Screen capture stays idle until a compatible local client connects.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
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

    private var controlPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Remote Control")
                .font(.headline)

            HStack(spacing: 12) {
                Button {
                    controller.toggleRemoteControl()
                } label: {
                    Label(
                        controller.isRemoteControlEnabled ? "Disable Control" : "Enable Control",
                        systemImage: controller.isRemoteControlEnabled ? "cursorarrow.slash" : "cursorarrow.click"
                    )
                }
                .buttonStyle(.borderedProminent)
                .disabled(!controller.isRemoteControlEnabled && controller.activeAuthenticatedSessions == 0)

                Button {
                    controller.refreshRemoteControlPermissionStatus()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }

            Label(controller.remoteControlStatus, systemImage: "lock.shield")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var streamPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Stream")
                .font(.headline)

            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 8) {
                statRow("Settings", controller.videoSettings.summary)
                statRow("Zoom", zoomSummary)
                statRow("FPS", controller.streamStats.map { String(format: "%.1f / %d", $0.effectiveFramesPerSecond, $0.targetFrameRate) } ?? "Waiting")
                statRow("Bitrate", controller.streamStats.map { String(format: "%.0f kbps", $0.bitrateKilobitsPerSecond) } ?? "Waiting")
                statRow("Frame Cost", controller.streamStats.map { String(format: "%.0f ms encode / %.0f ms send", $0.captureDurationMilliseconds, $0.sendDurationMilliseconds) } ?? "Waiting")
                statRow("Frame Wait", controller.streamStats.map { String(format: "%.0f ms", $0.captureWaitDurationMilliseconds) } ?? "Waiting")
                statRow("Source Drop", controller.streamStats.map { String(format: "%.1f%%", $0.sourceDropRate * 100) } ?? "Waiting")
            }
        }
    }

    private var audioPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("System Audio")
                .font(.headline)

            Toggle(isOn: systemAudioBinding) {
                Label("Allow Audio", systemImage: "speaker.wave.2")
            }
            .disabled(!controller.systemAudioStatus.isAvailable)

            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 8) {
                statRow("Capture", controller.systemAudioSummary)
                statRow("Transport", audioTransportSummary)
            }
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
                        if controller.selectedDisplayID == display.id {
                            Text("Selected")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
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

    private func statRow(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
            Text(value)
                .monospacedDigit()
        }
    }

    private var zoomSummary: String {
        let zoom = controller.previewViewport.zoomScale
        return zoom > 1.01 ? String(format: "%.1fx crop", zoom) : "Full display"
    }

    private var systemAudioBinding: Binding<Bool> {
        Binding {
            controller.isSystemAudioAllowed
        } set: { allowed in
            controller.setSystemAudioAllowed(allowed)
        }
    }

    private var audioTransportSummary: String {
        switch controller.systemAudioStatus.transportState {
        case .notImplemented:
            "Playback pending"
        case .hostCaptureOnly:
            "Host only"
        case .streaming:
            "Streaming"
        }
    }
}
