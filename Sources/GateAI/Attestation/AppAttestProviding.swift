import Foundation

public protocol GateAIAppAttestProvider: Sendable {
    func ensureKeyID() async throws -> String
    func generateAssertion(keyID: String, clientDataHash: Data) async throws -> Data
}

struct UnsupportedAppAttestService: GateAIAppAttestProvider {
    func ensureKeyID() async throws -> String {
        throw GateAIError.attestationUnavailable
    }

    func generateAssertion(keyID: String, clientDataHash: Data) async throws -> Data {
        throw GateAIError.attestationUnavailable
    }
}
