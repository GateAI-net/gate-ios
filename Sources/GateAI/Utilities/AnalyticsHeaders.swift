import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Helper to generate analytics headers for Gate/AI requests.
///
/// These headers provide contextual information about the app and device for analytics purposes.
struct AnalyticsHeaders {
    /// The user status set by the application (e.g., "free", "premium", "trial").
    let userStatus: String?

    /// Generates a dictionary of analytics headers.
    ///
    /// - Returns: A dictionary with X-prefixed analytics headers.
    func headers() -> [String: String] {
        var headers: [String: String] = [:]

        // X-Client-Locale: Language and country code (e.g., "es-MX", "en-US")
        if let locale = Self.clientLocale() {
            headers["X-Client-Locale"] = locale
        }

        // X-App-Version: App version from bundle (e.g., "1.0.2")
        if let appVersion = Self.appVersion() {
            headers["X-App-Version"] = appVersion
        }

        // X-OS-Version: iOS version (e.g., "17.2")
        if let osVersion = Self.osVersion() {
            headers["X-OS-Version"] = osVersion
        }

        // X-User-Status: Custom status provided by developer
        if let userStatus = userStatus {
            headers["X-User-Status"] = userStatus
        }

        // X-Device-Identifier: Vendor identifier (UUID string)
        if let deviceId = Self.deviceIdentifier() {
            headers["X-Device-Identifier"] = deviceId
        }

        // X-Device-Type: Device model (e.g., "iPhone", "iPad")
        if let deviceType = Self.deviceType() {
            headers["X-Device-Type"] = deviceType
        }

        return headers
    }

    // MARK: - Private Helpers

    private static func clientLocale() -> String? {
        // Convert "en_US" to "en-US" format
        let identifier = Locale.current.identifier
        return identifier.replacingOccurrences(of: "_", with: "-")
    }

    private static func appVersion() -> String? {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }

    private static func osVersion() -> String? {
        #if canImport(UIKit)
        return UIDevice.current.systemVersion
        #else
        return ProcessInfo.processInfo.operatingSystemVersionString
        #endif
    }

    private static func deviceIdentifier() -> String? {
        #if canImport(UIKit)
        return UIDevice.current.identifierForVendor?.uuidString
        #else
        return nil
        #endif
    }

    private static func deviceType() -> String? {
        #if canImport(UIKit)
        return UIDevice.current.model
        #else
        return "macOS"
        #endif
    }
}
