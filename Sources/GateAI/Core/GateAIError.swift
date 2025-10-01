import Foundation

public enum GateAIError: Error, LocalizedError, Sendable {
    case configuration(String)
    case attestationUnavailable
    case attestationFailed(String)
    case secureEnclaveUnavailable
    case network(underlying: Error)
    case server(statusCode: Int, error: ServerErrorResponse?, headers: [String: String]?)
    case decoding(underlying: Error)
    case invalidResponse
    case tokenMissing

    public var errorDescription: String? {
        switch self {
        case .configuration(let message):
            return message
        case .attestationUnavailable:
            return "App Attest is not supported on this device."
        case .attestationFailed(let message):
            return "Device attestation failed: \(message)"
        case .secureEnclaveUnavailable:
            return "Secure Enclave is not available."
        case .network(let underlying):
            return "Network request failed: \(underlying.localizedDescription)"
        case .server(let status, let error, _):
            if let error {
                return "Server returned \(status): \(error.errorDescription ?? error.error)"
            }
            return "Server returned status code \(status)."
        case .decoding(let underlying):
            return "Failed to decode server response: \(underlying.localizedDescription)"
        case .invalidResponse:
            return "Received an invalid response from the server."
        case .tokenMissing:
            return "No access token is available."
        }
    }
}

public struct ServerErrorResponse: Codable, Sendable {
    public let error: String
    public let errorDescription: String?

    enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
    }
}
