import AppKit
import SwiftUI
import MiradorHost

@main
struct MiradorHostApp: App {
    @State private var controller = HostController()

    var body: some Scene {
        WindowGroup("Mirador Host") {
            HostDashboardView(controller: controller)
                .frame(minWidth: 540, minHeight: 420)
        }

        MenuBarExtra("Mirador", systemImage: "display") {
            Button(controller.isAdvertising ? "Stop Listener" : "Start Listener") {
                controller.toggleAdvertising()
            }

            Button("Quit Mirador") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}
