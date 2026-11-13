#if canImport(Security)
import Foundation
import Security

public struct KeychainError: Error, Equatable, Sendable {
    public let status: OSStatus
}

/// Stores the session as one generic-password item.
///
/// The item is readable after the first unlock so background refresh can run
/// while the phone is locked, and it never leaves this device.
public struct KeychainSessionStore: SessionStore {
    private let service: String
    private let itemName = "session"

    public init(service: String) {
        self.service = service
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: itemName,
        ]
    }

    public func load() throws -> Session? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw KeychainError(status: status)
        }
        return try JSONDecoder().decode(Session.self, from: data)
    }

    public func save(_ session: Session) throws {
        let data = try JSONEncoder().encode(session)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else {
            throw KeychainError(status: updateStatus)
        }
        let addStatus = SecItemAdd(baseQuery.merging(attributes) { $1 } as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainError(status: addStatus)
        }
    }

    public func clear() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError(status: status)
        }
    }
}
#endif
