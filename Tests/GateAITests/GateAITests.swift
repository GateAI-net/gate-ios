import Foundation
import CryptoKit
import Testing
@testable import GateAI

@Test func base64URLDecodingHandlesPadding() throws {
    let original = Data([0xde, 0xad, 0xbe, 0xef])
    let base64URL = original.base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
    let decoded = base64URL.base64URLDecodedData
    #expect(decoded == original)
}

@Test func derSignatureConversionProducesRawConcatenation() throws {
    let r = Data((1...32).map(UInt8.init))
    let s = Data((101...132).map(UInt8.init))
    var der = Data([0x30, 0x44, 0x02, 0x20])
    der.append(r)
    der.append(contentsOf: [0x02, 0x20])
    der.append(s)

    let raw = try DER.ecdsaSignatureToRaw(der, coordinateOctetLength: 32)
    #expect(raw == r + s)
}

@Test func derSignatureConversionTrimsLeadingZeros() throws {
    var r = Data([0x00])
    r.append(contentsOf: Array(repeating: 0xAB, count: 32))
    var s = Data([0x00])
    s.append(contentsOf: Array(repeating: 0xCD, count: 32))

    var der = Data([0x30, 0x46, 0x02, 0x21])
    der.append(r)
    der.append(contentsOf: [0x02, 0x21])
    der.append(s)

    let raw = try DER.ecdsaSignatureToRaw(der, coordinateOctetLength: 32)
    #expect(raw.count == 64)
    #expect(Data(raw[..<32]) == Data(repeating: 0xAB, count: 32))
    #expect(Data(raw[32...]) == Data(repeating: 0xCD, count: 32))
}

@Test func appAttestClientDataHashMatchesManualComputation() throws {
    let nonce = Data("nonce".utf8)
    let canonical = Data("{\"crv\":\"P-256\",\"kty\":\"EC\",\"x\":\"abc\",\"y\":\"def\"}".utf8)

    var concatenated = Data()
    concatenated.append(nonce)
    concatenated.append(Data(SHA256.hash(data: canonical)))
    let expected = Data(SHA256.hash(data: concatenated))
    let hash = Hashing.appAttestClientDataHash(nonce: nonce, canonicalJWK: canonical)
    #expect(hash == expected)
}

// MARK: - GateAIConfiguration Tests

@Test func configurationAcceptsValidTeamIdentifier() throws {
    let config = try GateAIConfiguration(
        baseURL: URL(string: "https://example.gate-ai.net")!,
        bundleIdentifier: "com.example.app",
        teamIdentifier: "ABCDE12345"
    )
    #expect(config.teamIdentifier == "ABCDE12345")
}

@Test func configurationAcceptsNumericTeamIdentifier() throws {
    let config = try GateAIConfiguration(
        baseURL: URL(string: "https://example.gate-ai.net")!,
        bundleIdentifier: "com.example.app",
        teamIdentifier: "1234567890"
    )
    #expect(config.teamIdentifier == "1234567890")
}

@Test func configurationAcceptsMixedCaseTeamIdentifier() throws {
    let config = try GateAIConfiguration(
        baseURL: URL(string: "https://example.gate-ai.net")!,
        bundleIdentifier: "com.example.app",
        teamIdentifier: "VY76D5S364"
    )
    #expect(config.teamIdentifier == "VY76D5S364")
}

@Test func configurationRejectsShortTeamIdentifier() throws {
    #expect(throws: GateAIError.self) {
        try GateAIConfiguration(
            baseURL: URL(string: "https://example.gate-ai.net")!,
            bundleIdentifier: "com.example.app",
            teamIdentifier: "ABC123"
        )
    }
}

@Test func configurationRejectsLongTeamIdentifier() throws {
    #expect(throws: GateAIError.self) {
        try GateAIConfiguration(
            baseURL: URL(string: "https://example.gate-ai.net")!,
            bundleIdentifier: "com.example.app",
            teamIdentifier: "ABCDE123456"
        )
    }
}

@Test func configurationRejectsTeamIdentifierWithSpecialCharacters() throws {
    #expect(throws: GateAIError.self) {
        try GateAIConfiguration(
            baseURL: URL(string: "https://example.gate-ai.net")!,
            bundleIdentifier: "com.example.app",
            teamIdentifier: "ABCDE-1234"
        )
    }
}

@Test func configurationRejectsTeamIdentifierWithSpaces() throws {
    #expect(throws: GateAIError.self) {
        try GateAIConfiguration(
            baseURL: URL(string: "https://example.gate-ai.net")!,
            bundleIdentifier: "com.example.app",
            teamIdentifier: "ABCDE 1234"
        )
    }
}

@Test func configurationRejectsEmptyBundleIdentifier() throws {
    #expect(throws: GateAIError.self) {
        try GateAIConfiguration(
            baseURL: URL(string: "https://example.gate-ai.net")!,
            bundleIdentifier: "",
            teamIdentifier: "ABCDE12345"
        )
    }
}

@Test func convenienceInitializerAcceptsValidURLString() throws {
    let config = try GateAIConfiguration(
        baseURLString: "https://example.gate-ai.net",
        bundleIdentifier: "com.example.app",
        teamIdentifier: "ABCDE12345"
    )
    #expect(config.baseURL.absoluteString == "https://example.gate-ai.net")
}

@Test func convenienceInitializerRejectsInvalidURLString() throws {
    #expect(throws: GateAIError.self) {
        try GateAIConfiguration(
            baseURLString: "",
            bundleIdentifier: "com.example.app",
            teamIdentifier: "ABCDE12345"
        )
    }
}

@Test func convenienceInitializerUsesProvidedBundleIdentifier() throws {
    let config = try GateAIConfiguration(
        baseURLString: "https://example.gate-ai.net",
        bundleIdentifier: "com.custom.bundle",
        teamIdentifier: "ABCDE12345"
    )
    #expect(config.bundleIdentifier == "com.custom.bundle")
}

@Test func configurationSetsDefaultLogLevel() throws {
    let config = try GateAIConfiguration(
        baseURL: URL(string: "https://example.gate-ai.net")!,
        bundleIdentifier: "com.example.app",
        teamIdentifier: "ABCDE12345"
    )
    #expect(config.logLevel == .off)
}

@Test func configurationAcceptsCustomLogLevel() throws {
    let config = try GateAIConfiguration(
        baseURL: URL(string: "https://example.gate-ai.net")!,
        bundleIdentifier: "com.example.app",
        teamIdentifier: "ABCDE12345",
        logLevel: .debug
    )
    #expect(config.logLevel == .debug)
}

// MARK: - AnalyticsHeaders Tests

@Test func analyticsHeadersIncludeAutomaticHeaders() async throws {
    let analytics = AnalyticsHeaders(userStatus: nil, userIdentifier: nil, appFeature: nil)
    let headers = await analytics.headers()

    #expect(headers["X-SDK-Version"] == GateAIVersion.current)
    #expect(["development", "testflight", "production"].contains(headers["X-Environment"]))
    #expect(headers["X-Device-Model"]?.isEmpty == false)
}

@Test func analyticsHeadersOmitDeveloperHeadersWhenUnset() async throws {
    let analytics = AnalyticsHeaders(userStatus: nil, userIdentifier: nil, appFeature: nil)
    let headers = await analytics.headers()

    #expect(headers["X-User-Status"] == nil)
    #expect(headers["X-User-Identifier"] == nil)
    #expect(headers["X-App-Feature"] == nil)
}

@Test func analyticsHeadersIncludeDeveloperHeadersWhenSet() async throws {
    let analytics = AnalyticsHeaders(
        userStatus: "premium",
        userIdentifier: "user_8f2c1a",
        appFeature: "chat"
    )
    let headers = await analytics.headers()

    #expect(headers["X-User-Status"] == "premium")
    #expect(headers["X-User-Identifier"] == "user_8f2c1a")
    #expect(headers["X-App-Feature"] == "chat")
}

// MARK: - Quota Anchor Day Tests

@Test func analyticsHeadersIncludeQuotaAnchorDayWhenSet() async throws {
    let analytics = AnalyticsHeaders(userStatus: nil, userIdentifier: nil, appFeature: nil, quotaAnchorDay: 15)
    let headers = await analytics.headers()

    #expect(headers["X-Quota-Anchor-Day"] == "15")
}

@Test func analyticsHeadersOmitQuotaAnchorDayWhenNil() async throws {
    let analytics = AnalyticsHeaders(userStatus: nil, userIdentifier: nil, appFeature: nil, quotaAnchorDay: nil)
    let headers = await analytics.headers()

    #expect(headers["X-Quota-Anchor-Day"] == nil)
}

@Test func analyticsHeadersDropQuotaAnchorDayBelowRange() async throws {
    let analytics = AnalyticsHeaders(userStatus: nil, userIdentifier: nil, appFeature: nil, quotaAnchorDay: 0)
    let headers = await analytics.headers()

    #expect(headers["X-Quota-Anchor-Day"] == nil)
}

@Test func analyticsHeadersDropQuotaAnchorDayAboveRange() async throws {
    let analytics = AnalyticsHeaders(userStatus: nil, userIdentifier: nil, appFeature: nil, quotaAnchorDay: 32)
    let headers = await analytics.headers()

    #expect(headers["X-Quota-Anchor-Day"] == nil)
}

@Test func analyticsHeadersAcceptQuotaAnchorDayBoundaries() async throws {
    let first = AnalyticsHeaders(userStatus: nil, userIdentifier: nil, appFeature: nil, quotaAnchorDay: 1)
    let last = AnalyticsHeaders(userStatus: nil, userIdentifier: nil, appFeature: nil, quotaAnchorDay: 31)

    #expect(await first.headers()["X-Quota-Anchor-Day"] == "1")
    #expect(await last.headers()["X-Quota-Anchor-Day"] == "31")
}

// MARK: - GateAIQuotaStatus Tests

@Test func quotaStatusParsesAllHeaders() throws {
    let status = GateAIQuotaStatus(headers: [
        "X-Quota-Requests-Remaining": "42",
        "X-Quota-Tokens-Remaining": "10000",
        "X-Quota-Reset": "2026-09-01T00:00:00.000Z"
    ])

    let unwrapped = try #require(status)
    #expect(unwrapped.requestsRemaining == 42)
    #expect(unwrapped.tokensRemaining == 10000)
    #expect(unwrapped.resetsAt == Date(timeIntervalSince1970: 1_788_220_800))
}

@Test func quotaStatusParsesHeadersCaseInsensitively() throws {
    let status = GateAIQuotaStatus(headers: [
        "x-quota-requests-remaining": "5",
        "X-QUOTA-TOKENS-REMAINING": "250",
        "x-Quota-Reset": "2026-09-01T00:00:00Z"
    ])

    let unwrapped = try #require(status)
    #expect(unwrapped.requestsRemaining == 5)
    #expect(unwrapped.tokensRemaining == 250)
    #expect(unwrapped.resetsAt == Date(timeIntervalSince1970: 1_788_220_800))
}

@Test func quotaStatusIsNilWhenNoQuotaHeadersPresent() throws {
    let status = GateAIQuotaStatus(headers: ["Content-Type": "application/json"])
    #expect(status == nil)
}

@Test func quotaStatusExposedOnHTTPURLResponse() throws {
    let response = try #require(HTTPURLResponse(
        url: URL(string: "https://example.gate-ai.net/openai/chat/completions")!,
        statusCode: 200,
        httpVersion: "HTTP/1.1",
        headerFields: [
            "X-Quota-Requests-Remaining": "7",
            "X-Quota-Reset": "2026-09-01T00:00:00.000Z"
        ]
    ))

    let status = try #require(response.gateAIQuotaStatus)
    #expect(status.requestsRemaining == 7)
    #expect(status.tokensRemaining == nil)
    #expect(status.resetsAt == Date(timeIntervalSince1970: 1_788_220_800))
}

// MARK: - GateAIRateLimitInfo Tests

@Test func rateLimitInfoParsesFullDeviceWindowBody() throws {
    let body = Data("""
    {
        "error": "rate_limited",
        "code": "device_daily_requests_exceeded",
        "message": "Daily request limit reached.",
        "window": "daily",
        "limit": 200,
        "used": 200,
        "resets_at": "2026-09-01T00:00:00.000Z"
    }
    """.utf8)

    let info = try #require(GateAIRateLimitInfo.parse(from: body))
    #expect(info.code == "device_daily_requests_exceeded")
    #expect(info.message == "Daily request limit reached.")
    #expect(info.window == .daily)
    #expect(info.limit == 200)
    #expect(info.used == 200)
    #expect(info.resetsAt == Date(timeIntervalSince1970: 1_788_220_800))
}

@Test func rateLimitInfoParsesMinimalNonWindowBody() throws {
    let body = Data("""
    {
        "error": "rate_limited",
        "code": "global_rpm_exceeded",
        "message": "Too many requests."
    }
    """.utf8)

    let info = try #require(GateAIRateLimitInfo.parse(from: body))
    #expect(info.code == "global_rpm_exceeded")
    #expect(info.message == "Too many requests.")
    #expect(info.window == nil)
    #expect(info.limit == nil)
    #expect(info.used == nil)
    #expect(info.resetsAt == nil)
}

@Test func rateLimitInfoPreservesUnknownWindowValues() throws {
    let body = Data("""
    {
        "error": "rate_limited",
        "code": "device_weekly_requests_exceeded",
        "message": "Weekly request limit reached.",
        "window": "weekly",
        "limit": 50,
        "used": 50,
        "resets_at": "2026-09-01T00:00:00Z"
    }
    """.utf8)

    let info = try #require(GateAIRateLimitInfo.parse(from: body))
    #expect(info.window == .unknown("weekly"))
    #expect(info.window?.rawValue == "weekly")
}

@Test func rateLimitInfoIsNilForNonRateLimitedBody() throws {
    let body = Data("""
    {"error": "invalid_token", "error_description": "Token expired."}
    """.utf8)

    #expect(GateAIRateLimitInfo.parse(from: body) == nil)
    #expect(GateAIRateLimitInfo.parse(from: Data("not json".utf8)) == nil)
}

@Test func gateAIErrorExposesRateLimitInfoFor429() throws {
    let body = Data("""
    {
        "error": "rate_limited",
        "code": "device_cycle_tokens_exceeded",
        "message": "Cycle token limit reached.",
        "window": "cycle",
        "limit": 100000,
        "used": 99500,
        "resets_at": "2026-09-15T00:00:00.000Z"
    }
    """.utf8)
    let serverError = try JSONDecoder().decode(ServerErrorResponse.self, from: body)
    let error = GateAIError.server(statusCode: 429, error: serverError, headers: nil)

    let info = try #require(error.rateLimitInfo)
    #expect(info.code == "device_cycle_tokens_exceeded")
    #expect(info.window == .cycle)
    #expect(info.limit == 100_000)
    #expect(info.used == 99_500)
    #expect(info.resetsAt != nil)

    let nonRateLimited = GateAIError.server(statusCode: 429, error: nil, headers: nil)
    #expect(nonRateLimited.rateLimitInfo == nil)
}
