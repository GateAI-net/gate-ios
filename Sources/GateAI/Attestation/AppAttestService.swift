import Foundation
@preconcurrency import Security
#if canImport(DeviceCheck)
@preconcurrency import DeviceCheck
#endif

struct AppAttestKeyStore: Sendable {
    private let account: String

    init(bundleIdentifier: String) {
        self.account = "com.gateai.appattest." + bundleIdentifier
    }

    func loadKeyID() throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data, let keyID = String(data: data, encoding: .utf8) else {
                return nil
            }
            return keyID
        case errSecItemNotFound:
            return nil
        default:
            throw GateAIError.attestationUnavailable
        }
    }

    func storeKeyID(_ keyID: String) throws {
        let data = Data(keyID.utf8)
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemAdd(baseQuery.merging(attributes) { _, new in new } as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let updateStatus = SecItemUpdate(baseQuery as CFDictionary, [kSecValueData as String: data] as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw GateAIError.attestationUnavailable
            }
        } else if status != errSecSuccess {
            throw GateAIError.attestationUnavailable
        }
    }
}

#if canImport(DeviceCheck)
@available(iOS 14.0, *)
final class AppAttestService: @unchecked Sendable { // DeviceCheck APIs are main-thread bound; we guard usage manually.
    private let service: DCAppAttestService
    private let keyStore: AppAttestKeyStore

    init(bundleIdentifier: String, service: DCAppAttestService = .shared) {
        self.service = service
        self.keyStore = AppAttestKeyStore(bundleIdentifier: bundleIdentifier)
    }
}

@available(iOS 14.0, *)
extension AppAttestService: GateAIAppAttestProvider {
    func ensureKeyID() async throws -> String {
        guard service.isSupported else {
            throw GateAIError.attestationUnavailable
        }

        if let keyID = try keyStore.loadKeyID() {
            return keyID
        }

        let newKeyID = try await generateKey()
        try keyStore.storeKeyID(newKeyID)
        return newKeyID
    }

    func generateAssertion(keyID: String, clientDataHash: Data) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            service.generateAssertion(keyID, clientDataHash: clientDataHash) { assertion, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let assertion {
                    continuation.resume(returning: assertion)
                } else {
                    continuation.resume(throwing: GateAIError.attestationUnavailable)
                }
            }
        }
    }

    private func generateKey() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            service.generateKey { keyID, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let keyID {
                    continuation.resume(returning: keyID)
                } else {
                    continuation.resume(throwing: GateAIError.attestationUnavailable)
                }
            }
        }
    }
}
#endif
