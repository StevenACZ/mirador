import Testing
@testable import MiradorCore

@Suite("Session PIN")
struct SessionPINTests {
    @Test("Generated PIN uses the configured length")
    func generatedPINLength() {
        let pin = SessionPIN.generate(length: 8)
        #expect(pin.value.count == 8)
    }

    @Test("Matching ignores non-number formatting")
    func formattedCandidateMatches() {
        let pin = SessionPIN("123456")
        #expect(pin.matches("123 456"))
        #expect(pin.matches("123-456"))
    }
}
