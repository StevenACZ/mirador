import AppKit
import SwiftUI

@main
struct MiradorHostApp: App {
    @State private var controller = HostController()

    var body: some Scene {
        WindowGroup("Mirador Host") {
            HostDashboardView(controller: controller)
                .frame(minWidth: 540, minHeight: 420)
        }

        MenuBarExtra("Mirador", systemImage: "display.and.iphone") {
            Button(controller.isAdvertising ? "Stop Listener" : "Start Listener") {
                controller.toggleAdvertising()
            }

            Button("Rotate PIN") {
                controller.rotatePIN()
            }

            Divider()

            Button("Quit Mirador") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}
