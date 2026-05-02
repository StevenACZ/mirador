import SwiftUI
import MiradorCore

struct ClientSessionView: View {
    @Bindable var store: MiradorClientStore
    @State private var fullScreenViewerIsPresented = false

    var body: some View {
        Group {
            if let host = store.selectedHost {
                Form {
                    Section("Host") {
                        Label(host.name, systemImage: "macmini")
                        Label(store.connectionStatus, systemImage: "network")
                        Label(store.authenticationStatus, systemImage: "lock.shield")
                    }

                    Section("Session") {
                        HStack {
                            Button {
                                store.connectToSelectedHost()
                            } label: {
                                Label("Connect", systemImage: "play.circle")
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isAuthenticated)

                            Button {
                                store.disconnect()
                            } label: {
                                Label("Disconnect", systemImage: "xmark.circle")
                            }
                        }
                    }

                    Section("Preview") {
                        ClientPreviewPanelView(
                            store: store,
                            isAuthenticated: isAuthenticated,
                            onEnterFullScreen: enterFullScreenViewer
                        )
                    }

                    Section("Stream") {
                        StreamSettingsView(store: store, isAuthenticated: isAuthenticated)
                    }

                    Section("Control") {
                        Toggle("Control Mode", isOn: $store.isControlModeEnabled)
                            .disabled(!isAuthenticated)

                        Label(store.remoteControlStatus, systemImage: "cursorarrow.click")
                            .foregroundStyle(.secondary)

                        shortcutTray

                        Text("Input events sent: \(store.sentInputEvents)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                .navigationTitle(host.name)
                .onChange(of: store.selectedHost) { _, host in
                    if host == nil {
                        fullScreenViewerIsPresented = false
                    }
                }
                .remoteViewerPresentation(
                    isPresented: $fullScreenViewerIsPresented,
                    store: store
                )
            } else {
                ContentUnavailableView(
                    "Select a Mac",
                    systemImage: "display.and.iphone",
                    description: Text("Choose a Mirador host from the browser.")
                )
            }
        }
    }

    private var isAuthenticated: Bool {
        store.isAuthenticated
    }

    private var shortcutTray: some View {
        Grid(horizontalSpacing: 10, verticalSpacing: 10) {
            GridRow {
                Button {
                    store.sendRemoteScroll(deltaY: 6)
                } label: {
                    Label("Scroll Up", systemImage: "arrow.up")
                }

                Button {
                    store.sendRemoteScroll(deltaY: -6)
                } label: {
                    Label("Scroll Down", systemImage: "arrow.down")
                }
            }

            GridRow {
                Button {
                    store.sendRemoteShortcut(.escape)
                } label: {
                    Label("Esc", systemImage: "keyboard")
                }

                Button {
                    store.sendRemoteShortcut(.spotlight)
                } label: {
                    Label("Spotlight", systemImage: "magnifyingglass")
                }
            }
        }
        .buttonStyle(.bordered)
        .disabled(!isAuthenticated || !store.isControlModeEnabled)
    }

    private func enterFullScreenViewer() {
        store.isControlModeEnabled = true
        fullScreenViewerIsPresented = true
    }

}

private extension View {
    @ViewBuilder
    func remoteViewerPresentation(
        isPresented: Binding<Bool>,
        store: MiradorClientStore
    ) -> some View {
        #if os(iOS)
        fullScreenCover(isPresented: isPresented) {
            RemoteViewerView(store: store)
        }
        #else
        sheet(isPresented: isPresented) {
            RemoteViewerView(store: store)
        }
        #endif
    }
}
