#if os(iOS)
import SwiftUI
import UIKit
import MiradorCore

struct RemoteViewerGestureSurface: UIViewRepresentable {
    let zoomScale: Double
    let centerX: Double
    let centerY: Double
    let onRemoteInput: (RemoteInputKind, Double, Double) -> Void
    let onViewportChange: (Double, Double, Double) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> GestureView {
        let view = GestureView()
        view.backgroundColor = .clear

        let singleTap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleSingleTap(_:))
        )
        singleTap.numberOfTouchesRequired = 1

        let doubleTap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleDoubleTap(_:))
        )
        doubleTap.numberOfTapsRequired = 2
        singleTap.require(toFail: doubleTap)

        let secondaryTap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleSecondaryTap(_:))
        )
        secondaryTap.numberOfTouchesRequired = 2

        let pointerPan = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePointerPan(_:))
        )
        pointerPan.minimumNumberOfTouches = 1
        pointerPan.maximumNumberOfTouches = 1

        let viewportPan = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleViewportPan(_:))
        )
        viewportPan.minimumNumberOfTouches = 2
        viewportPan.maximumNumberOfTouches = 2

        let pinch = UIPinchGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePinch(_:))
        )

        [singleTap, doubleTap, secondaryTap, pointerPan, viewportPan, pinch].forEach {
            $0.delegate = context.coordinator
            view.addGestureRecognizer($0)
        }

        return view
    }

    func updateUIView(_ uiView: GestureView, context: Context) {
        context.coordinator.surface = self
    }

    final class GestureView: UIView {}

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var surface: RemoteViewerGestureSurface
        private var gestureStartZoom = 1.0
        private var gestureStartCenterX = 0.5
        private var gestureStartCenterY = 0.5
        private var liveZoom = 1.0
        private var liveCenterX = 0.5
        private var liveCenterY = 0.5
        private var lastViewportUpdate = Date.distantPast
        private var lastPointerMoveSentAt = Date.distantPast
        private var activeViewportGestures: Set<ObjectIdentifier> = []
        private let viewportUpdateInterval: TimeInterval = 1.0 / 30.0
        private let pointerUpdateInterval: TimeInterval = 1.0 / 60.0
        private let pointerLiftPoints: CGFloat = 44

        init(_ surface: RemoteViewerGestureSurface) {
            self.surface = surface
        }

        @objc func handleSingleTap(_ recognizer: UITapGestureRecognizer) {
            send(.primaryClick, recognizer: recognizer)
        }

        @objc func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
            send(.primaryClick, recognizer: recognizer)
            send(.primaryClick, recognizer: recognizer)
        }

        @objc func handleSecondaryTap(_ recognizer: UITapGestureRecognizer) {
            send(.secondaryClick, recognizer: recognizer)
        }

        @objc func handlePointerPan(_ recognizer: UIPanGestureRecognizer) {
            switch recognizer.state {
            case .began, .changed:
                sendPointerMove(recognizer, immediate: false)
            case .ended:
                sendPointerMove(recognizer, immediate: true)
            default:
                break
            }
        }

        @objc func handleViewportPan(_ recognizer: UIPanGestureRecognizer) {
            switch recognizer.state {
            case .began:
                beginViewportGesture(recognizer)
            case .changed, .ended:
                guard let view = recognizer.view else { return }
                let translation = recognizer.translation(in: view)
                let viewportWidth = 1 / max(liveZoom, 1)
                let nextCenterX = gestureStartCenterX - Double(translation.x / max(view.bounds.width, 1)) * viewportWidth
                let nextCenterY = gestureStartCenterY - Double(translation.y / max(view.bounds.height, 1)) * viewportWidth
                applyViewport(
                    zoomScale: liveZoom,
                    centerX: nextCenterX,
                    centerY: nextCenterY,
                    immediate: recognizer.state == .ended
                )
                if recognizer.state == .ended {
                    endViewportGesture(recognizer)
                }
            case .cancelled, .failed:
                endViewportGesture(recognizer)
            default:
                break
            }
        }

        @objc func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
            switch recognizer.state {
            case .began:
                beginViewportGesture(recognizer)
            case .changed, .ended:
                let nextZoom = gestureStartZoom * Double(recognizer.scale)
                applyViewport(
                    zoomScale: nextZoom,
                    centerX: liveCenterX,
                    centerY: liveCenterY,
                    immediate: recognizer.state == .ended
                )
                if recognizer.state == .ended {
                    endViewportGesture(recognizer)
                }
            case .cancelled, .failed:
                endViewportGesture(recognizer)
            default:
                break
            }
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }

        private func beginViewportGesture(_ recognizer: UIGestureRecognizer) {
            if activeViewportGestures.isEmpty {
                gestureStartZoom = surface.zoomScale
                gestureStartCenterX = surface.centerX
                gestureStartCenterY = surface.centerY
                liveZoom = surface.zoomScale
                liveCenterX = surface.centerX
                liveCenterY = surface.centerY
                MiradorClientLog.input.debug(
                    "viewport gesture began zoom=\(self.liveZoom, privacy: .public) centerX=\(self.liveCenterX, privacy: .public) centerY=\(self.liveCenterY, privacy: .public)"
                )
            }
            activeViewportGestures.insert(ObjectIdentifier(recognizer))
        }

        private func endViewportGesture(_ recognizer: UIGestureRecognizer) {
            activeViewportGestures.remove(ObjectIdentifier(recognizer))
            guard activeViewportGestures.isEmpty else { return }
            MiradorClientLog.input.debug(
                "viewport gesture ended zoom=\(self.liveZoom, privacy: .public) centerX=\(self.liveCenterX, privacy: .public) centerY=\(self.liveCenterY, privacy: .public)"
            )
        }

        private func send(_ kind: RemoteInputKind, recognizer: UIGestureRecognizer) {
            guard let view = recognizer.view else { return }
            let point = adjustedPoint(
                from: recognizer.location(in: view),
                for: kind,
                in: view.bounds.size
            )
            let normalizedX = min(max(point.x / max(view.bounds.width, 1), 0), 1)
            let normalizedY = min(max(point.y / max(view.bounds.height, 1), 0), 1)
            surface.onRemoteInput(kind, normalizedX, normalizedY)
        }

        private func adjustedPoint(
            from point: CGPoint,
            for kind: RemoteInputKind,
            in size: CGSize
        ) -> CGPoint {
            guard kind == .pointerMove else { return point }
            return CGPoint(
                x: point.x,
                y: min(max(point.y - pointerLiftPoints, 0), max(size.height, 1))
            )
        }

        private func sendPointerMove(_ recognizer: UIGestureRecognizer, immediate: Bool) {
            let now = Date()
            guard immediate || now.timeIntervalSince(lastPointerMoveSentAt) >= pointerUpdateInterval else { return }
            lastPointerMoveSentAt = now
            send(.pointerMove, recognizer: recognizer)
        }

        private func applyViewport(
            zoomScale: Double,
            centerX: Double,
            centerY: Double,
            immediate: Bool
        ) {
            let viewport = PreviewViewport.cropped(
                zoomScale: zoomScale,
                centerX: centerX,
                centerY: centerY
            )
            liveZoom = viewport.zoomScale
            liveCenterX = viewport.normalizedX + viewport.normalizedWidth / 2
            liveCenterY = viewport.normalizedY + viewport.normalizedHeight / 2
            sendViewport(liveZoom, liveCenterX, liveCenterY, immediate: immediate)
        }

        private func sendViewport(
            _ zoomScale: Double,
            _ centerX: Double,
            _ centerY: Double,
            immediate: Bool
        ) {
            let now = Date()
            guard immediate || now.timeIntervalSince(lastViewportUpdate) >= viewportUpdateInterval else { return }
            lastViewportUpdate = now
            MiradorClientLog.input.debug(
                "viewport emitted zoom=\(zoomScale, privacy: .public) centerX=\(centerX, privacy: .public) centerY=\(centerY, privacy: .public) immediate=\(immediate, privacy: .public)"
            )
            surface.onViewportChange(zoomScale, centerX, centerY)
        }
    }
}
#else
import SwiftUI
import MiradorCore

struct RemoteViewerGestureSurface: View {
    let zoomScale: Double
    let centerX: Double
    let centerY: Double
    let onRemoteInput: (RemoteInputKind, Double, Double) -> Void
    let onViewportChange: (Double, Double, Double) -> Void

    var body: some View {
        Color.clear
    }
}
#endif
