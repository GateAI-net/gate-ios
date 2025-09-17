import Foundation

public struct GateAIConfiguration: Sendable {
    public let baseURL: URL
    public let bundleIdentifier: String
    public let teamIdentifier: String

    public init(baseURL: URL, bundleIdentifier: String, teamIdentifier: String) {
        self.baseURL = baseURL
        self.bundleIdentifier = bundleIdentifier
        self.teamIdentifier = teamIdentifier
    }
}
