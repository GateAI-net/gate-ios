import Foundation

public protocol GateAIAppAttestProvider: Sendable {
    func ensureKeyID() async throws -> String
    func markKeyAsAttested(_ keyID: String) throws
    func attestKey(keyID: String, clientDataHash: Data) async throws -> Data
    func generateAssertion(keyID: String, clientDataHash: Data) async throws -> Data
    func clearStoredKey() throws
}

struct UnsupportedAppAttestService: GateAIAppAttestProvider {
    func ensureKeyID() async throws -> String {
        throw GateAIError.attestationUnavailable
    }

    func markKeyAsAttested(_ keyID: String) throws {
        throw GateAIError.attestationUnavailable
    }

    func attestKey(keyID: String, clientDataHash: Data) async throws -> Data {
        throw GateAIError.attestationUnavailable
    }

    func generateAssertion(keyID: String, clientDataHash: Data) async throws -> Data {
        throw GateAIError.attestationUnavailable
    }

    func clearStoredKey() throws {
        // No-op for unsupported service
    }
}
