import SwiftUI

struct ClientSessionView: View {
    @Bindable var store: MiradorClientStore
    @FocusState private var pinFieldIsFocused: Bool

    var body: some View {
        Group {
            if let host = store.selectedHost {
                Form {
                    Section("Host") {
                        Label(host.name, systemImage: "macmini")
                        Label(store.connectionStatus, systemImage: "network")
                        Label(store.authenticationStatus, systemImage: "lock.shield")
                    }

                    Section("PIN") {
                        pinField

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
                        PreviewFrameView(frame: store.latestFrame, count: store.receivedFrames)
                    }
                }
                .navigationTitle(host.name)
                .onChange(of: isAuthenticated) { _, authenticated in
                    if authenticated {
                        pinFieldIsFocused = false
                    }
                }
            } else {
                ContentUnavailableView(
                    "Select a Mac",
                    systemImage: "display.and.iphone",
                    description: Text("Choose a Mirador host from the browser.")
                )
            }
        }
    }

    private var pinField: some View {
        #if os(iOS)
        TextField("Session PIN", text: $store.pinEntry)
            .keyboardType(.numberPad)
            .textContentType(.oneTimeCode)
            .focused($pinFieldIsFocused)
            .disabled(isAuthenticated)
        #else
        TextField("Session PIN", text: $store.pinEntry)
            .focused($pinFieldIsFocused)
            .disabled(isAuthenticated)
        #endif
    }

    private var isAuthenticated: Bool {
        store.authenticationStatus == "PIN accepted"
    }
}
