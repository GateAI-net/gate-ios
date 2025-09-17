import Foundation

struct AuthorizationContext: Sendable {
    let accessToken: String
    let dpop: String
}

actor GateAIAuthSession {
    private let configuration: GateAIConfiguration
    private let apiClient: AuthAPIClient
    private let deviceKeyService: DeviceKeyService
    private let appAttestService: GateAIAppAttestProvider
    private var deviceKeyMaterial: DeviceKeyMaterial?
    private var dpopBuilder: DPoPTokenBuilder?
    private var cachedToken: String?
    private var tokenExpiry: Date?
    private var mintTask: Task<TokenResponse, Error>?

    init(
        configuration: GateAIConfiguration,
        apiClient: AuthAPIClient,
        deviceKeyService: DeviceKeyService,
        appAttestService: GateAIAppAttestProvider
    ) {
        self.configuration = configuration
        self.apiClient = apiClient
        self.deviceKeyService = deviceKeyService
        self.appAttestService = appAttestService
    }

    func authorizationHeaders(for url: URL, method: HTTPMethod, nonce: String? = nil) async throws -> AuthorizationContext {
        let token = try await ensureValidToken()
        guard let builder = dpopBuilder else {
            throw GateAIError.secureEnclaveUnavailable
        }
        let proof = try builder.proof(httpMethod: method, url: url, nonce: nonce)
        return AuthorizationContext(accessToken: token, dpop: proof)
    }

    func accessToken() async throws -> String {
        return try await ensureValidToken()
    }

    func reset() {
        mintTask?.cancel()
        mintTask = nil
        cachedToken = nil
        tokenExpiry = nil
    }

    private func ensureValidToken() async throws -> String {
        if let token = cachedToken, let expiry = tokenExpiry, expiry.timeIntervalSinceNow > 60 {
            return token
        }

        if let existingTask = mintTask {
            let response = try await existingTask.value
            mintTask = nil
            updateTokenCache(with: response)
            return response.accessToken
        }

        let task = Task<TokenResponse, Error> {
            try await self.mintAccessToken()
        }
        mintTask = task

        do {
            let response = try await task.value
            updateTokenCache(with: response)
            mintTask = nil
            return response.accessToken
        } catch {
            mintTask = nil
            throw error
        }
    }

    private func updateTokenCache(with response: TokenResponse) {
        cachedToken = response.accessToken
        tokenExpiry = Date().addingTimeInterval(TimeInterval(response.expiresIn))
    }

    private func mintAccessToken() async throws -> TokenResponse {
        let material = try ensureDeviceKeyMaterial()
        guard let builder = dpopBuilder else {
            throw GateAIError.secureEnclaveUnavailable
        }

        let challenge = try await apiClient.fetchChallenge()
        guard let nonceData = challenge.nonce.base64URLDecodedData
                ?? Data(base64Encoded: challenge.nonce)
                ?? challenge.nonce.data(using: .utf8) else {
            throw GateAIError.configuration("Failed to decode server nonce.")
        }

        let clientDataHash = Hashing.appAttestClientDataHash(nonce: nonceData, canonicalJWK: material.jwk.canonicalData())
        let keyID = try await appAttestService.ensureKeyID()
        let assertion = try await appAttestService.generateAssertion(keyID: keyID, clientDataHash: clientDataHash)
        let assertionBase64 = assertion.base64EncodedString()

        let tokenURL = configuration.baseURL.appendingPathComponent("token")
        let attestation = TokenRequestBody.Attestation(
            type: "app_attest",
            keyId: keyID,
            teamId: configuration.teamIdentifier,
            assertion: assertionBase64
        )
        let appDescriptor = TokenRequestBody.AppDescriptor(bundleId: configuration.bundleIdentifier)

        let initialProof = try builder.proof(httpMethod: .post, url: tokenURL)
        let initialBody = TokenRequestBody(
            app: appDescriptor,
            deviceKeyJwk: material.jwk,
            attestation: attestation,
            dpop: initialProof
        )

        do {
            return try await apiClient.exchangeToken(body: initialBody, dpop: initialProof)
        } catch let error as GateAIError {
            guard case let .server(status, _, headers) = error,
                  status == 401,
                  let nonce = headers?[caseInsensitive: "DPoP-Nonce"] else {
                throw error
            }

            // Server requested a proof with the supplied nonce—reissue DPoP and retry once.
            let retryProof = try builder.proof(httpMethod: .post, url: tokenURL, nonce: nonce)
            let retryBody = TokenRequestBody(
                app: appDescriptor,
                deviceKeyJwk: material.jwk,
                attestation: attestation,
                dpop: retryProof
            )
            return try await apiClient.exchangeToken(body: retryBody, dpop: retryProof)
        }
    }

    private func ensureDeviceKeyMaterial() throws -> DeviceKeyMaterial {
        if let material = deviceKeyMaterial {
            return material
        }
        let material = try deviceKeyService.loadOrCreateKey()
        deviceKeyMaterial = material
        dpopBuilder = DPoPTokenBuilder(material: material)
        return material
    }
}
