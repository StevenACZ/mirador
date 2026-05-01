import SwiftUI
import MiradorCore

public struct MiradorClientView: View {
    @State private var store: MiradorClientStore

    public init(store: MiradorClientStore = MiradorClientStore()) {
        _store = State(initialValue: store)
    }

    public var body: some View {
        #if os(iOS)
        NavigationStack {
            browser
                .navigationDestination(isPresented: sessionIsPresented) {
                    ClientSessionView(store: store)
                }
        }
        #else
        splitView
        #endif
    }

    private var splitView: some View {
        NavigationSplitView {
            browser
        } detail: {
            ClientSessionView(store: store)
        }
    }

    private var browser: some View {
        HostBrowserView(store: store)
            .navigationTitle(MiradorConstants.appName)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        store.startBrowsing()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("Refresh hosts")
                }
            }
            .task {
                store.startBrowsing()
            }
    }

    private var sessionIsPresented: Binding<Bool> {
        Binding {
            store.selectedHost != nil
        } set: { isPresented in
            if !isPresented {
                store.disconnect()
                store.selectedHost = nil
            }
        }
    }
}

#Preview {
    MiradorClientView()
}
