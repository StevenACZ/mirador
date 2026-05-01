import SwiftUI
import MiradorCore

public struct MiradorClientView: View {
    @State private var store: MiradorClientStore

    public init(store: MiradorClientStore = MiradorClientStore()) {
        _store = State(initialValue: store)
    }

    public var body: some View {
        NavigationStack {
            List(selection: selectedHostBinding) {
                Section {
                    if store.hosts.isEmpty {
                        ContentUnavailableView(
                            "No Macs Found",
                            systemImage: "display.trianglebadge.exclamationmark",
                            description: Text("Mirador is looking for Macs on your local network.")
                        )
                    } else {
                        ForEach(store.hosts) { host in
                            HostRow(host: host)
                                .tag(host)
                        }
                    }
                } header: {
                    Text(store.browserStatus)
                }
            }
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
            .safeAreaInset(edge: .bottom) {
                ClientStatusBar(selectedHost: store.selectedHost)
            }
            .task {
                store.startBrowsing()
            }
        }
    }

    private var selectedHostBinding: Binding<DiscoveredHost?> {
        Binding(
            get: { store.selectedHost },
            set: { host in
                if let host {
                    store.select(host)
                }
            }
        )
    }
}

private struct HostRow: View {
    let host: DiscoveredHost

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 3) {
                Text(host.name)
                    .font(.headline)
                    .lineLimit(1)

                Text(host.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        } icon: {
            Image(systemName: "macmini")
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct ClientStatusBar: View {
    let selectedHost: DiscoveredHost?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: selectedHost == nil ? "wifi" : "checkmark.circle.fill")
                .foregroundStyle(selectedHost == nil ? Color.secondary : Color.green)

            Text(selectedHost?.name ?? "Select a Mac to prepare the MVP1 preview session.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }
}

#Preview {
    MiradorClientView()
}
