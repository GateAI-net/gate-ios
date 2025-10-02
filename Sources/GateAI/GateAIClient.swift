import Foundation

/// The main client for interacting with the Gate/AI authentication and proxy service.
///
/// `GateAIClient` provides a complete solution for authenticating with Gate/AI and making
/// authenticated requests through the proxy. It handles the entire OAuth 2.0 + DPoP + App Attest
/// flow automatically, including:
///
/// - Device key generation and management in the Secure Enclave
/// - App Attest attestation (on device) or development token flow (simulator)
/// - Access token acquisition and automatic refresh
/// - DPoP proof generation for each request
/// - Nonce challenge handling with automatic retry
///
/// ## Usage
///
/// ```swift
/// // Initialize the client
/// let configuration = try GateAIConfiguration(
///     baseURLString: "https://yourteam.us01.gate-ai.net",
///     teamIdentifier: "ABCDE12345"
/// )
/// let client = GateAIClient(configuration: configuration)
///
/// // Make authenticated requests
/// let (data, response) = try await client.performProxyRequest(
///     path: "openai/chat/completions",
///     method: .post,
///     body: requestBody,
///     additionalHeaders: ["Content-Type": "application/json"]
/// )
/// ```
///
/// ## Thread Safety
///
/// `GateAIClient` is thread-safe and can be safely accessed from multiple concurrent tasks.
/// The internal authentication session uses an actor to ensure proper synchronization.
///
/// ## Topics
///
/// ### Creating a Client
///
/// - ``init(configuration:urlSession:appAttestProvider:)``
///
/// ### Making Authenticated Requests
///
/// - ``performProxyRequest(path:method:body:additionalHeaders:)``
/// - ``performProxyRequest(to:method:body:additionalHeaders:)``
/// - ``authorizationHeaders(for:method:nonce:)-8tkvs``
/// - ``authorizationHeaders(for:method:nonce:)-5wr89``
///
/// ### Managing State
///
/// - ``currentAccessToken()``
/// - ``clearCachedState()``
/// - ``clearAppAttestKey()``
///
/// ### Error Handling
///
/// - ``extractDPoPNonce(from:)``
public final class GateAIClient: @unchecked Sendable {
    private let configuration: GateAIConfiguration
    private let authSession: GateAIAuthSession
    private let urlSession: URLSession
    private let logger: GateAILoggerProtocol
    private let appAttestProvider: GateAIAppAttestProvider

    /// Creates a new Gate/AI client with the specified configuration.
    ///
    /// - Parameters:
    ///   - configuration: The configuration containing your Gate/AI tenant URL, bundle identifier, and team ID.
    ///   - urlSession: The URL session to use for network requests. Defaults to `.shared`.
    ///   - appAttestProvider: Optional custom App Attest provider for testing. If `nil`, uses the system provider.
    ///
    /// - Note: The client automatically selects between App Attest (on device) and development token flow (simulator)
    ///         based on the build environment and configuration.
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

    /// Generates authorization headers for a specific URL and HTTP method.
    ///
    /// This method obtains a valid access token and generates a DPoP proof for the specified request.
    /// Use this when constructing your own `URLRequest` instances.
    ///
    /// - Parameters:
    ///   - url: The full URL of the request.
    ///   - method: The HTTP method (GET or POST).
    ///   - nonce: Optional DPoP nonce from a previous 401 response. Pass this when retrying after a nonce challenge.
    ///
    /// - Returns: A dictionary containing `Authorization` and `DPoP` headers ready to be added to your request.
    ///
    /// - Throws: ``GateAIError`` if authentication fails or if device attestation is unavailable.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let headers = try await client.authorizationHeaders(
    ///     for: URL(string: "https://yourteam.us01.gate-ai.net/openai/chat/completions")!,
    ///     method: .post
    /// )
    /// var request = URLRequest(url: url)
    /// headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
    /// ```
    public func authorizationHeaders(for url: URL, method: HTTPMethod, nonce: String? = nil) async throws -> [String: String] {
        let context = try await authSession.authorizationHeaders(for: url, method: method, nonce: nonce)
        return [
            "Authorization": "Bearer \(context.accessToken)",
            "DPoP": context.dpop
        ]
    }

    /// Generates authorization headers for a path relative to the configured base URL.
    ///
    /// This is a convenience method that constructs the full URL by appending the path to the base URL
    /// from your configuration.
    ///
    /// - Parameters:
    ///   - path: The path relative to your base URL (e.g., "openai/chat/completions").
    ///   - method: The HTTP method (GET or POST).
    ///   - nonce: Optional DPoP nonce from a previous 401 response.
    ///
    /// - Returns: A dictionary containing `Authorization` and `DPoP` headers.
    ///
    /// - Throws: ``GateAIError`` if authentication fails or if device attestation is unavailable.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let headers = try await client.authorizationHeaders(
    ///     for: "openai/chat/completions",
    ///     method: .post
    /// )
    /// ```
    public func authorizationHeaders(for path: String, method: HTTPMethod, nonce: String? = nil) async throws -> [String: String] {
        let url = configuration.baseURL.appendingPathComponent(path)
        return try await authorizationHeaders(for: url, method: method, nonce: nonce)
    }

    /// Retrieves the current access token.
    ///
    /// This method returns the cached access token if it's still valid (more than 60 seconds until expiry),
    /// or mints a new token if needed. The token is suitable for including in `Authorization` headers.
    ///
    /// - Returns: A valid access token string.
    ///
    /// - Throws: ``GateAIError`` if token minting fails.
    ///
    /// - Note: In most cases, you should use ``authorizationHeaders(for:method:nonce:)-8tkvs`` or
    ///         ``performProxyRequest(path:method:body:additionalHeaders:)`` instead, as they also
    ///         generate the required DPoP proof.
    public func currentAccessToken() async throws -> String {
        return try await authSession.accessToken()
    }

    /// Clears all cached authentication state.
    ///
    /// This method removes the cached access token, forcing a new authentication flow on the next request.
    /// The device key in the Secure Enclave and the App Attest key are **not** removed.
    ///
    /// Use this method when you want to force a fresh token acquisition, such as after a configuration change
    /// or for testing purposes.
    ///
    /// - Note: To also clear the App Attest key, call ``clearAppAttestKey()`` separately.
    public func clearCachedState() async {
        await authSession.reset()
    }

    /// Clears the stored App Attest key from the Keychain.
    ///
    /// This forces the creation of a new App Attest key on the next authentication attempt.
    /// Use this method when you need to completely reset the device's attestation state,
    /// such as during development or troubleshooting.
    ///
    /// - Throws: An error if the key cannot be removed from the Keychain.
    ///
    /// - Warning: This operation is destructive. After calling this method, the device will need to
    ///            re-attest with the server.
    public func clearAppAttestKey() throws {
        logger.info("Clearing App Attest key")
        try appAttestProvider.clearStoredKey()
    }

    /// Extracts the DPoP nonce from a Gate/AI error, if present.
    ///
    /// When the server returns a 401 status with a `DPoP-Nonce` header, you can use this method
    /// to extract the nonce and retry the request with updated headers.
    ///
    /// - Parameter error: The error to inspect.
    ///
    /// - Returns: The nonce string if the error is a ``GateAIError/server(statusCode:error:headers:)``
    ///            with a `DPoP-Nonce` header, otherwise `nil`.
    ///
    /// ## Example
    ///
    /// ```swift
    /// do {
    ///     try await makeRequest()
    /// } catch {
    ///     if let nonce = client.extractDPoPNonce(from: error) {
    ///         // Retry with nonce
    ///         let headers = try await client.authorizationHeaders(for: url, method: .post, nonce: nonce)
    ///     }
    /// }
    /// ```
    ///
    /// - Note: The ``performProxyRequest(path:method:body:additionalHeaders:)`` method handles
    ///         nonce challenges automatically, so you typically don't need to use this method directly.
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

    /// Performs an authenticated proxy request to the specified full URL.
    ///
    /// This method handles the complete request flow including:
    /// - Obtaining a valid access token
    /// - Generating DPoP proof for the request
    /// - Handling DPoP nonce challenges with automatic retry
    /// - Returning the response data and HTTP response
    ///
    /// - Parameters:
    ///   - url: The complete URL to request.
    ///   - method: The HTTP method to use.
    ///   - body: Optional request body data.
    ///   - additionalHeaders: Additional headers to include in the request (e.g., "Content-Type").
    ///
    /// - Returns: A tuple containing the response data and `HTTPURLResponse`.
    ///
    /// - Throws: ``GateAIError`` if authentication fails, or any network-related errors.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let requestBody = try JSONEncoder().encode(myRequest)
    /// let (data, response) = try await client.performProxyRequest(
    ///     to: URL(string: "https://yourteam.us01.gate-ai.net/openai/chat/completions")!,
    ///     method: .post,
    ///     body: requestBody,
    ///     additionalHeaders: ["Content-Type": "application/json"]
    /// )
    /// ```
    public func performProxyRequest(
        to url: URL,
        method: HTTPMethod,
        body: Data? = nil,
        additionalHeaders: [String: String] = [:]
    ) async throws -> (Data, HTTPURLResponse) {
        try await executeProxyRequest(url: url, method: method, body: body, additionalHeaders: additionalHeaders)
    }

    /// Performs an authenticated proxy request to a path relative to the configured base URL.
    ///
    /// This is the recommended method for making authenticated requests through the Gate/AI proxy.
    /// It automatically handles authentication, DPoP proof generation, and nonce challenges.
    ///
    /// - Parameters:
    ///   - path: The path relative to your base URL (e.g., "openai/chat/completions").
    ///   - method: The HTTP method to use.
    ///   - body: Optional request body data.
    ///   - additionalHeaders: Additional headers to include in the request (e.g., "Content-Type").
    ///
    /// - Returns: A tuple containing the response data and `HTTPURLResponse`.
    ///
    /// - Throws: ``GateAIError`` if authentication fails, or any network-related errors.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let requestBody = """
    /// {
    ///     "model": "gpt-4",
    ///     "messages": [{"role": "user", "content": "Hello!"}]
    /// }
    /// """.data(using: .utf8)!
    ///
    /// let (data, response) = try await client.performProxyRequest(
    ///     path: "openai/chat/completions",
    ///     method: .post,
    ///     body: requestBody,
    ///     additionalHeaders: ["Content-Type": "application/json"]
    /// )
    ///
    /// if response.statusCode == 200 {
    ///     let result = try JSONDecoder().decode(ChatResponse.self, from: data)
    /// }
    /// ```
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
