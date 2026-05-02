import SwiftUI
import MiradorCore

struct RemoteViewerChrome: View {
    @Bindable var store: MiradorClientStore
    @Binding var keyboardIsActive: Bool
    let onClose: () -> Void

    var body: some View {
        VStack {
            HStack(spacing: 10) {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Close viewer")

                #if os(iOS)
                Button {
                    keyboardIsActive.toggle()
                } label: {
                    Image(systemName: keyboardIsActive ? "keyboard.chevron.compact.down" : "keyboard")
                }
                .buttonStyle(.bordered)
                .accessibilityLabel(keyboardIsActive ? "Hide keyboard" : "Show keyboard")
                #endif

                RemoteViewerDisplaySwitcher(store: store)

                Spacer()

                if let stats = store.streamStats {
                    Text("\(stats.effectiveFramesPerSecond, specifier: "%.0f")/\(stats.targetFrameRate) FPS")
                    Text("\(stats.bitrateKilobitsPerSecond / 1_000, specifier: "%.1f") Mbps")
                    Text("\(stats.sourceDropRate * 100, specifier: "%.1f")% drop")
                }

                Text("\(store.zoomScale, specifier: "%.1f")x")
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.white)
            .padding(10)
            .background(.black.opacity(0.42))

            Spacer()
        }
        .ignoresSafeArea(edges: .top)
    }
}

private struct RemoteViewerDisplaySwitcher: View {
    @Bindable var store: MiradorClientStore

    var body: some View {
        let displays = store.availableDisplays
        if displays.isEmpty {
            EmptyView()
        } else if displays.count == 1 {
            Label("Display 1", systemImage: "display")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(.white.opacity(0.12))
                .clipShape(Capsule())
                .accessibilityLabel("Primary display")
        } else {
            HStack(spacing: 6) {
                Image(systemName: "rectangle.on.rectangle")
                    .font(.caption.weight(.semibold))
                    .accessibilityHidden(true)

                ForEach(displays.indices, id: \.self) { index in
                    displayButton(for: displays[index], index: index)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.white.opacity(0.10))
            .clipShape(Capsule())
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Displays")
        }
    }

    private func displayButton(for display: DisplayDescriptor, index: Int) -> some View {
        let isSelected = isDisplaySelected(display, at: index)
        return Button {
            store.updateSelectedDisplay(display.id)
        } label: {
            Text("\(index + 1)")
                .font(.caption.monospacedDigit().weight(.bold))
                .frame(width: 24, height: 24)
                .foregroundStyle(isSelected ? Color.black : Color.white)
                .background(isSelected ? Color.white : Color.white.opacity(0.12))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Display \(index + 1)")
        .accessibilityValue(isSelected ? "Selected" : "\(display.width) by \(display.height)")
    }

    private func isDisplaySelected(_ display: DisplayDescriptor, at index: Int) -> Bool {
        if let selectedDisplayID = store.selectedDisplayID {
            return selectedDisplayID == display.id
        }
        return index == 0
    }
}
