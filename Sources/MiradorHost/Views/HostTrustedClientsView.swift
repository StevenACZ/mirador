import SwiftUI

struct HostTrustedClientsView: View {
    @Bindable var controller: HostController

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Trusted Devices")
                    .font(.headline)
                Spacer()
                Button {
                    controller.forgetInactiveTrustedClients()
                } label: {
                    Label("Forget Inactive", systemImage: "trash")
                }
                .disabled(controller.trustedClients.allSatisfy(\.isActive))
            }

            if controller.trustedClients.isEmpty {
                Label("No connected devices yet", systemImage: "iphone")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 72)
            } else {
                ForEach(controller.trustedClients) { client in
                    trustedClientRow(client)
                }
            }
        }
    }

    private func trustedClientRow(_ client: TrustedClient) -> some View {
        HStack(spacing: 12) {
            Image(systemName: client.isActive ? "iphone.gen3.radiowaves.left.and.right" : "iphone.slash")
                .foregroundStyle(client.isActive ? .green : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(client.name)
                    .lineLimit(1)
                Text("\(client.receivedInputEvents) received | \(client.appliedInputEvents) applied")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Spacer()
            Button {
                controller.revokeClient(id: client.id)
            } label: {
                Image(systemName: "xmark.circle")
            }
            .disabled(!client.isActive)
            .accessibilityLabel("Disconnect \(client.name)")
        }
        .padding(.vertical, 5)
    }
}
