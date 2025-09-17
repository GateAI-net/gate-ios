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
    private let developmentToken: String?
    private var deviceKeyMaterial: DeviceKeyMaterial?
    private var dpopBuilder: DPoPTokenBuilder?
    private var cachedToken: String?
    private var tokenExpiry: Date?
    private var mintTask: Task<TokenResponse, Error>?

    init(
        configuration: GateAIConfiguration,
        apiClient: AuthAPIClient,
        deviceKeyService: DeviceKeyService,
        appAttestService: GateAIAppAttestProvider,
        developmentToken: String?
    ) {
        self.configuration = configuration
        self.apiClient = apiClient
        self.deviceKeyService = deviceKeyService
        self.appAttestService = appAttestService
        self.developmentToken = developmentToken
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

        if shouldUseDevelopmentFlow {
            return try await mintUsingDevelopmentToken(material: material, builder: builder)
        }

        return try await mintUsingAppAttest(material: material, builder: builder)
    }

    private var shouldUseDevelopmentFlow: Bool {
        guard Platform.isSimulator, let token = developmentToken, !token.isEmpty else { return false }
        return true
    }

    private func mintUsingAppAttest(material: DeviceKeyMaterial, builder: DPoPTokenBuilder) async throws -> TokenResponse {
        let challenge = try await apiClient.fetchChallenge()
        guard let nonceData = challenge.nonce.base64URLDecodedData
                ?? Data(base64Encoded: challenge.nonce)
                ?? challenge.nonce.data(using: .utf8) else {
            throw GateAIError.configuration("Failed to decode server nonce.")
        }

        let clientDataHash = Hashing.appAttestClientDataHash(nonce: nonceData, canonicalJWK: material.jwk.canonicalData())

        let keyID: String
        do {
            keyID = try await appAttestService.ensureKeyID()
        } catch let error as GateAIError {
            throw error
        } catch {
            throw GateAIError.attestationUnavailable
        }

        let assertionData: Data
        do {
            assertionData = try await appAttestService.generateAssertion(keyID: keyID, clientDataHash: clientDataHash)
        } catch let error as GateAIError {
            throw error
        } catch {
            throw GateAIError.attestationUnavailable
        }

        let attestation = TokenRequestBody.Attestation(
            type: "app_attest",
            keyId: keyID,
            teamId: configuration.teamIdentifier,
            assertion: assertionData.base64EncodedString()
        )

        return try await exchangeToken(material: material, builder: builder, attestation: attestation, devToken: nil)
    }

    private func mintUsingDevelopmentToken(material: DeviceKeyMaterial, builder: DPoPTokenBuilder) async throws -> TokenResponse {
        guard Platform.isSimulator else {
            throw GateAIError.configuration("Development token flow is restricted to the simulator.")
        }
        guard let token = developmentToken, !token.isEmpty else {
            throw GateAIError.configuration("Development token is missing or empty.")
        }

        return try await exchangeToken(material: material, builder: builder, attestation: nil, devToken: token)
    }

    private func exchangeToken(
        material: DeviceKeyMaterial,
        builder: DPoPTokenBuilder,
        attestation: TokenRequestBody.Attestation?,
        devToken: String?
    ) async throws -> TokenResponse {
        let tokenURL = configuration.baseURL.appendingPathComponent("token")
        let appDescriptor = TokenRequestBody.AppDescriptor(bundleId: configuration.bundleIdentifier)

        func sendTokenRequest(with nonce: String?) async throws -> TokenResponse {
            let proof = try builder.proof(httpMethod: .post, url: tokenURL, nonce: nonce)
            let body = TokenRequestBody(
                app: appDescriptor,
                deviceKeyJwk: material.jwk,
                attestation: attestation,
                devToken: devToken,
                dpop: proof
            )
            return try await apiClient.exchangeToken(body: body, dpop: proof)
        }

        do {
            return try await sendTokenRequest(with: nil)
        } catch let error as GateAIError {
            guard case let .server(status, _, headers) = error,
                  status == 401,
                  let nonce = headers?[caseInsensitive: "DPoP-Nonce"] else {
                throw error
            }

            // Server requested a proof with the supplied nonce—reissue DPoP and retry once.
            return try await sendTokenRequest(with: nonce)
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
