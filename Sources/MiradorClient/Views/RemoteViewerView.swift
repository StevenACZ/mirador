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

            if let frameInfo = store.latestStreamFrameInfo {
                GeometryReader { geometry in
                    let imageSize = fittedImageSize(for: frameInfo, in: geometry.size)
                    let transform = previewTransform(for: frameInfo, imageSize: imageSize)

                    ZStack {
                        if let frame = store.latestFrame {
                            PreviewImageView(frame: frame)
                                .aspectRatio(CGFloat(frame.width) / CGFloat(frame.height), contentMode: .fit)
                                .frame(width: imageSize.width, height: imageSize.height)
                                .scaleEffect(transform.scale)
                                .offset(transform.offset)
                                .clipped()
                        } else {
                            VideoFrameSurface(store: store)
                                .aspectRatio(CGFloat(frameInfo.width) / CGFloat(frameInfo.height), contentMode: .fit)
                                .frame(width: imageSize.width, height: imageSize.height)
                                .scaleEffect(transform.scale)
                                .offset(transform.offset)
                                .clipped()
                        }

                        RemoteViewerGestureSurface(
                            zoomScale: store.zoomScale,
                            centerX: store.viewportCenterX,
                            centerY: store.viewportCenterY,
                            onRemoteInput: sendRemoteInput,
                            onViewportChange: updateViewport
                        )
                        .frame(width: imageSize.width, height: imageSize.height)
                        .scaleEffect(transform.scale)
                        .offset(transform.offset)
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

    private func fittedImageSize(for frame: StreamFrameInfo, in containerSize: CGSize) -> CGSize {
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

    private func previewTransform(for frame: StreamFrameInfo, imageSize: CGSize) -> (scale: CGFloat, offset: CGSize) {
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
