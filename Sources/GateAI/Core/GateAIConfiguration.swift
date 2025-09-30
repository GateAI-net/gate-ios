import Foundation

public struct GateAIConfiguration: Sendable {
    public let baseURL: URL
    public let bundleIdentifier: String
    public let teamIdentifier: String
    public let developmentToken: String?
    public let logLevel: GateAILogLevel

    public init(
        baseURL: URL,
        bundleIdentifier: String,
        teamIdentifier: String,
        developmentToken: String? = nil,
        logLevel: GateAILogLevel = .off
    ) {
        self.baseURL = baseURL
        self.bundleIdentifier = bundleIdentifier
        self.teamIdentifier = teamIdentifier
        self.developmentToken = developmentToken
        self.logLevel = logLevel
    }
}
