import Foundation

public final class GateAIClient: @unchecked Sendable {
    private let configuration: GateAIConfiguration
    private let authSession: GateAIAuthSession
    private let urlSession: URLSession
    private let logger: GateAILoggerProtocol
    private let appAttestProvider: GateAIAppAttestProvider

    public init(
        configuration: GateAIConfiguration,
        urlSession: URLSession = .shared,
        appAttestProvider: GateAIAppAttestProvider? = nil
    ) {
        self.configuration = configuration
        self.urlSession = urlSession
        self.logger = GateAILogger.shared

        // Configure logger with the provided log level
        if let gateAILogger = logger as? GateAILogger {
            gateAILogger.setLogLevel(configuration.logLevel)
        }

        let httpClient = GateAIHTTPClient(configuration: configuration, session: urlSession, logger: logger)
        let apiClient = AuthAPIClient(httpClient: httpClient)
        let deviceKeyService = DeviceKeyService(bundleIdentifier: configuration.bundleIdentifier)
        let attestProvider: GateAIAppAttestProvider
        if let appAttestProvider {
            attestProvider = appAttestProvider
        } else {
            attestProvider = GateAIClient.makeDefaultAppAttestProvider(bundleIdentifier: configuration.bundleIdentifier)
        }
        self.appAttestProvider = attestProvider
        self.authSession = GateAIAuthSession(
            configuration: configuration,
            apiClient: apiClient,
            deviceKeyService: deviceKeyService,
            appAttestService: attestProvider,
            developmentToken: configuration.developmentToken,
            logger: logger
        )

        logger.info("GateAI client initialized with baseURL: \(configuration.baseURL.absoluteString)")
    }

    public func authorizationHeaders(for url: URL, method: HTTPMethod, nonce: String? = nil) async throws -> [String: String] {
        let context = try await authSession.authorizationHeaders(for: url, method: method, nonce: nonce)
        return [
            "Authorization": "Bearer \(context.accessToken)",
            "DPoP": context.dpop
        ]
    }

    public func authorizationHeaders(for path: String, method: HTTPMethod, nonce: String? = nil) async throws -> [String: String] {
        let url = configuration.baseURL.appendingPathComponent(path)
        return try await authorizationHeaders(for: url, method: method, nonce: nonce)
    }

    public func currentAccessToken() async throws -> String {
        return try await authSession.accessToken()
    }

    public func clearCachedState() async {
        await authSession.reset()
    }

    public func clearAppAttestKey() throws {
        logger.info("Clearing App Attest key")
        try appAttestProvider.clearStoredKey()
    }

    public func extractDPoPNonce(from error: Error) -> String? {
        guard let gateError = error as? GateAIError else { return nil }
        if case let .server(_, _, headers) = gateError {
            return headers?[caseInsensitive: "DPoP-Nonce"]
        }
        return nil
    }

    private static func makeDefaultAppAttestProvider(bundleIdentifier: String) -> GateAIAppAttestProvider {
        #if canImport(DeviceCheck)
        if #available(iOS 14.0, *) {
            return AppAttestService(bundleIdentifier: bundleIdentifier)
        }
        #endif
        return UnsupportedAppAttestService()
    }

    public func performProxyRequest(
        to url: URL,
        method: HTTPMethod,
        body: Data? = nil,
        additionalHeaders: [String: String] = [:]
    ) async throws -> (Data, HTTPURLResponse) {
        try await executeProxyRequest(url: url, method: method, body: body, additionalHeaders: additionalHeaders)
    }

    public func performProxyRequest(
        path: String,
        method: HTTPMethod,
        body: Data? = nil,
        additionalHeaders: [String: String] = [:]
    ) async throws -> (Data, HTTPURLResponse) {
        let url = configuration.baseURL.appendingPathComponent(path)
        return try await executeProxyRequest(url: url, method: method, body: body, additionalHeaders: additionalHeaders)
    }

    private func executeProxyRequest(
        url: URL,
        method: HTTPMethod,
        body: Data?,
        additionalHeaders: [String: String]
    ) async throws -> (Data, HTTPURLResponse) {
        let initial = try await sendProxyRequest(url: url, method: method, body: body, additionalHeaders: additionalHeaders, nonce: nil)
        if initial.response.statusCode == 401,
           let nonce = initial.response.value(forHTTPHeaderField: "DPoP-Nonce") {
            // Server returned a nonce challenge—sign a fresh proof including the nonce and retry once.
            return try await sendProxyRequest(url: url, method: method, body: body, additionalHeaders: additionalHeaders, nonce: nonce)
        }
        return initial
    }

    private func sendProxyRequest(
        url: URL,
        method: HTTPMethod,
        body: Data?,
        additionalHeaders: [String: String],
        nonce: String?
    ) async throws -> (data: Data, response: HTTPURLResponse) {
        logger.debug("Preparing proxy request to: \(url.absoluteString)")

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.httpBody = body
        for (header, value) in additionalHeaders {
            request.setValue(value, forHTTPHeaderField: header)
        }

        let authHeaders = try await authorizationHeaders(for: url, method: method, nonce: nonce)
        for (header, value) in authHeaders {
            request.setValue(value, forHTTPHeaderField: header)
        }

        // Log the proxy request (this will also log the auth headers)
        logger.logRequest(request, body: body)

        do {
            let (data, response) = try await urlSession.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                let error = GateAIError.invalidResponse
                logger.logResponse(response, data: data, error: error)
                throw error
            }

            logger.logResponse(httpResponse, data: data, error: nil)
            return (data, httpResponse)
        } catch {
            logger.logResponse(nil, data: nil, error: error)
            throw error
        }
    }
}
