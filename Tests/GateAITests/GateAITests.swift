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
