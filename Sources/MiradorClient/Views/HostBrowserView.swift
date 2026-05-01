import SwiftUI

struct HostBrowserView: View {
    @Bindable var store: MiradorClientStore

    var body: some View {
        List {
            Section {
                if store.hosts.isEmpty {
                    ContentUnavailableView(
                        "No Macs Found",
                        systemImage: "display.trianglebadge.exclamationmark",
                        description: Text("Mirador is looking for Macs on your local network.")
                    )
                } else {
                    ForEach(store.hosts) { host in
                        Button {
                            store.select(host)
                        } label: {
                            HostRow(host: host, isSelected: host == store.selectedHost)
                        }
                    }
                }
            } header: {
                Text(store.browserStatus)
            }
        }
    }
}

private struct HostRow: View {
    let host: DiscoveredHost
    let isSelected: Bool

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
            Image(systemName: isSelected ? "checkmark.circle.fill" : "macmini")
                .foregroundStyle(isSelected ? Color.green : Color.secondary)
        }
        .padding(.vertical, 4)
    }
}
