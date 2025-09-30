import Foundation

struct ChallengeRequestBody: Codable, Sendable {
    let purpose: String
}

public struct ChallengeResponse: Codable, Sendable {
    public let nonce: String
    public let exp: Int
}

struct TokenRequestBody: Codable, Sendable {
    struct AppDescriptor: Codable, Sendable {
        let bundleId: String

        enum CodingKeys: String, CodingKey {
            case bundleId = "bundle_id"
        }
    }

    struct Attestation: Codable, Sendable {
        let type: String
        let keyId: String
        let teamId: String
        let assertion: String

        enum CodingKeys: String, CodingKey {
            case type
            case keyId = "key_id"
            case teamId = "team_id"
            case assertion
        }
    }

    let platform: String = "ios"
    let app: AppDescriptor
    let deviceKeyJwk: DeviceKeyJWK
    let attestation: Attestation?
    let devToken: String?
    let dpop: String

    enum CodingKeys: String, CodingKey {
        case platform
        case app
        case deviceKeyJwk = "device_key_jwk"
        case attestation
        case devToken = "dev_token"
        case dpop
    }
}

public struct TokenResponse: Codable, Sendable {
    public let accessToken: String
    public let expiresIn: Int
    public let mode: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case mode
    }
}

final class AuthAPIClient: @unchecked Sendable {
    private let httpClient: GateAIHTTPClient

    init(httpClient: GateAIHTTPClient) {
        self.httpClient = httpClient
    }

    func fetchChallenge() async throws -> ChallengeResponse {
        let request = HTTPRequest(method: .post, path: "attest/challenge", body: ChallengeRequestBody(purpose: "token"))
        return try await httpClient.send(request, expecting: ChallengeResponse.self)
    }

    func exchangeToken(body: TokenRequestBody, dpop: String) async throws -> TokenResponse {
        var headers = HTTPHeaders()
        headers["DPoP"] = dpop
        let request = HTTPRequest(method: .post, path: "token", body: body, headers: headers)
        return try await httpClient.send(request, expecting: TokenResponse.self)
    }
}
