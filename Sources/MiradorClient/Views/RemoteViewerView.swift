import SwiftUI
import MiradorCore
#if os(iOS)
import UIKit
#endif

struct RemoteViewerView: View {
    @Bindable var store: MiradorClientStore
    @Environment(\.dismiss) private var dismiss
    @State private var keyboardIsActive = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let frame = store.latestFrame {
                GeometryReader { geometry in
                    let imageSize = fittedImageSize(for: frame, in: geometry.size)
                    let transform = previewTransform(for: frame, imageSize: imageSize)

                    ZStack {
                        PreviewImageView(frame: frame)
                            .aspectRatio(CGFloat(frame.width) / CGFloat(frame.height), contentMode: .fit)
                            .frame(width: imageSize.width, height: imageSize.height)
                            .scaleEffect(transform.scale)
                            .offset(transform.offset)
                            .clipped()

                        RemoteViewerGestureSurface(
                            zoomScale: store.zoomScale,
                            centerX: store.viewportCenterX,
                            centerY: store.viewportCenterY,
                            onRemoteInput: sendRemoteInput,
                            onViewportChange: updateViewport
                        )
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                }
            } else {
                ContentUnavailableView("No Preview", systemImage: "display")
                    .foregroundStyle(.white)
            }

            RemoteViewerChrome(
                store: store,
                keyboardIsActive: $keyboardIsActive,
                onClose: closeViewer
            )

            #if os(iOS)
            RemoteKeyboardInputView(
                isActive: $keyboardIsActive,
                onText: sendRemoteText,
                onKey: sendRemoteKeyboardKey
            )
            .frame(width: 1, height: 1)
            .opacity(0.01)
            .allowsHitTesting(false)
            #endif
        }
        .remoteViewerSystemChrome()
        .onAppear {
            #if os(iOS)
            ClientOrientationController.requestLandscape()
            #endif
            store.isControlModeEnabled = true
        }
        .onDisappear {
            #if os(iOS)
            keyboardIsActive = false
            ClientOrientationController.requestDefault()
            #endif
        }
    }

    private func sendRemoteInput(_ kind: RemoteInputKind, _ normalizedX: Double, _ normalizedY: Double) {
        store.sendRemoteInput(
            kind: kind,
            normalizedX: normalizedX,
            normalizedY: normalizedY
        )
    }

    private func updateViewport(_ zoomScale: Double, _ centerX: Double, _ centerY: Double) {
        store.updateViewport(
            zoomScale: zoomScale,
            centerX: centerX,
            centerY: centerY
        )
    }

    private func sendRemoteText(_ text: String) {
        store.sendRemoteText(text)
    }

    private func sendRemoteKeyboardKey(_ key: RemoteKeyboardKey) {
        store.sendRemoteKeyboardKey(key)
    }

    private func closeViewer() {
        keyboardIsActive = false
        dismiss()
    }

    private func fittedImageSize(for frame: PreviewFrame, in containerSize: CGSize) -> CGSize {
        guard frame.width > 0, frame.height > 0, containerSize.width > 0, containerSize.height > 0 else {
            return .zero
        }

        let aspectRatio = CGFloat(frame.width) / CGFloat(frame.height)
        let containerRatio = containerSize.width / containerSize.height
        if aspectRatio > containerRatio {
            return CGSize(width: containerSize.width, height: containerSize.width / aspectRatio)
        }
        return CGSize(width: containerSize.height * aspectRatio, height: containerSize.height)
    }

    private func previewTransform(for frame: PreviewFrame, imageSize: CGSize) -> (scale: CGFloat, offset: CGSize) {
        let desiredViewport = PreviewViewport.cropped(
            zoomScale: store.zoomScale,
            centerX: store.viewportCenterX,
            centerY: store.viewportCenterY
        )
        let currentViewport = frame.viewport
        let scale = max(1, desiredViewport.zoomScale / max(currentViewport.zoomScale, 1))
        guard scale > 1.001 else {
            return (1, .zero)
        }

        let desiredCenterX = desiredViewport.normalizedX + desiredViewport.normalizedWidth / 2
        let desiredCenterY = desiredViewport.normalizedY + desiredViewport.normalizedHeight / 2
        let relativeX = clamped(
            (desiredCenterX - currentViewport.normalizedX) / max(currentViewport.normalizedWidth, 0.001)
        )
        let relativeY = clamped(
            (desiredCenterY - currentViewport.normalizedY) / max(currentViewport.normalizedHeight, 0.001)
        )
        return (
            CGFloat(scale),
            CGSize(
                width: (0.5 - relativeX) * imageSize.width * CGFloat(scale),
                height: (0.5 - relativeY) * imageSize.height * CGFloat(scale)
            )
        )
    }

    private func clamped(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}

private struct RemoteViewerChrome: View {
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

private extension View {
    @ViewBuilder
    func remoteViewerSystemChrome() -> some View {
        #if os(iOS)
        statusBarHidden(true)
            .persistentSystemOverlays(.hidden)
        #else
        self
        #endif
    }
}

#if os(iOS)
private enum ClientOrientationController {
    static func requestLandscape() {
        request(.landscape)
    }

    static func requestDefault() {
        request(.allButUpsideDown)
    }

    private static func request(_ orientations: UIInterfaceOrientationMask) {
        guard
            let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first
        else {
            return
        }

        scene.requestGeometryUpdate(.iOS(interfaceOrientations: orientations))
    }
}
#endif
