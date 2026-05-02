import SwiftUI
import MiradorCore

struct StreamSettingsView: View {
    @Bindable var store: MiradorClientStore
    let isAuthenticated: Bool
    @State private var draftBitrate: Double?

    var body: some View {
        Picker("Display", selection: displaySelection) {
            Text("Primary").tag(UInt32?.none)
            ForEach(store.availableDisplays) { display in
                Text("\(display.title) - \(display.width) x \(display.height)")
                    .tag(Optional(display.id))
            }
        }
        .disabled(!isAuthenticated || store.availableDisplays.isEmpty)

        Picker("Resolution", selection: resolutionSelection) {
            ForEach(StreamResolutionPreset.allCases) { resolution in
                Text(resolution.displayName).tag(resolution)
            }
        }
        .disabled(!isAuthenticated)

        Picker("FPS", selection: frameRateSelection) {
            ForEach(StreamFrameRatePreset.allCases) { frameRate in
                Text(frameRate.displayName).tag(frameRate)
            }
        }
        .pickerStyle(.segmented)
        .disabled(!isAuthenticated)

        bitrateControl

        Picker("Zoom", selection: zoomSelection) {
            Text("Fit").tag(1.0)
            Text("1.5x").tag(1.5)
            Text("2x").tag(2.0)
        }
        .pickerStyle(.segmented)
        .disabled(!isAuthenticated)

        Label(audioSummary, systemImage: audioIcon)
            .foregroundStyle(.secondary)
    }

    private var bitrateControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Bitrate")
                Spacer()
                Text(StreamVideoSettings.bitrateLabel(displayedBitrate))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            Slider(
                value: bitrateSelection,
                in: StreamVideoSettings.minimumBitrateMegabitsPerSecond...StreamVideoSettings.maximumBitrateMegabitsPerSecond,
                step: 0.5,
                onEditingChanged: applyBitrateWhenEditingEnds
            )
            .onDisappear {
                if let draftBitrate {
                    store.updateBitrateMegabitsPerSecond(draftBitrate)
                    self.draftBitrate = nil
                }
            }
            .disabled(!isAuthenticated)

            if let stats = store.streamStats {
                Text("Actual \(stats.bitrateKilobitsPerSecond / 1_000, specifier: "%.1f") Mbps")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }

    private var displaySelection: Binding<UInt32?> {
        Binding {
            store.selectedDisplayID
        } set: { newValue in
            store.updateSelectedDisplay(newValue)
        }
    }

    private var resolutionSelection: Binding<StreamResolutionPreset> {
        Binding {
            store.selectedVideoSettings.resolution
        } set: { newValue in
            store.updateResolutionPreset(newValue)
        }
    }

    private var frameRateSelection: Binding<StreamFrameRatePreset> {
        Binding {
            store.selectedVideoSettings.frameRate
        } set: { newValue in
            store.updateFrameRatePreset(newValue)
        }
    }

    private var bitrateSelection: Binding<Double> {
        Binding {
            displayedBitrate
        } set: { newValue in
            draftBitrate = newValue
        }
    }

    private var displayedBitrate: Double {
        draftBitrate ?? store.selectedVideoSettings.bitrateMegabitsPerSecond
    }

    private func applyBitrateWhenEditingEnds(_ isEditing: Bool) {
        guard !isEditing, let draftBitrate else { return }
        store.updateBitrateMegabitsPerSecond(draftBitrate)
        self.draftBitrate = nil
    }

    private var zoomSelection: Binding<Double> {
        Binding {
            store.zoomScale
        } set: { newValue in
            store.updateZoomScale(newValue)
        }
    }

    private var audioSummary: String {
        switch store.systemAudioStatus.captureState {
        case .unavailable:
            "Audio unavailable"
        case .disabled:
            "Audio off"
        case .ready:
            "Audio allowed"
        case .capturing:
            audioCapturingSummary
        case .failed:
            store.systemAudioStatus.lastError ?? "Audio failed"
        }
    }

    private var audioCapturingSummary: String {
        guard store.systemAudioStatus.transportState == .streaming else {
            return "Audio host capture only"
        }
        guard let stats = store.systemAudioStatus.stats else {
            return "Audio streaming"
        }
        return "Audio \(stats.sampleRate / 1_000) kHz / \(stats.channelCount) ch"
    }

    private var audioIcon: String {
        store.systemAudioStatus.isCapturing ? "speaker.wave.2" : "speaker.slash"
    }
}
