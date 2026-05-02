import Foundation

extension HostController {
    func upsertTrustedClient(for session: HostClientSession) {
        let now = Date()
        if let index = trustedClients.firstIndex(where: { $0.id == session.id }) {
            trustedClients[index].name = session.clientName
            trustedClients[index].lastSeenAt = now
            trustedClients[index].isActive = true
        } else {
            trustedClients.append(
                TrustedClient(
                    id: session.id,
                    name: session.clientName,
                    authenticatedAt: now,
                    lastSeenAt: now
                )
            )
        }
    }

    func markTrustedClient(id: UUID, isActive: Bool) {
        guard let index = trustedClients.firstIndex(where: { $0.id == id }) else { return }
        trustedClients[index].isActive = isActive
        trustedClients[index].lastSeenAt = Date()
    }

    func recordTrustedInput(for id: UUID, applied: Bool) {
        guard let index = trustedClients.firstIndex(where: { $0.id == id }) else { return }
        trustedClients[index].lastSeenAt = Date()
        trustedClients[index].receivedInputEvents += applied ? 0 : 1
        trustedClients[index].appliedInputEvents += applied ? 1 : 0
    }
}
