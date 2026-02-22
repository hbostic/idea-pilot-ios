//
//  KeychainService.swift
//  idea-pilot
//
//  Keychain abstraction protocol and production implementation.
//

import Foundation
import Security

// MARK: - KeychainStorable Protocol

/// Abstraction over iOS Keychain for secure credential storage.
///
/// The real implementation (`KeychainService`) calls Security framework APIs.
/// Tests inject `MockKeychainService` (in-memory dictionary) to avoid
/// hitting the real Keychain.
nonisolated protocol KeychainStorable: Sendable {

    /// Saves a string value to the Keychain for the given key.
    func save(_ value: String, forKey key: String) throws

    /// Loads a string value from the Keychain for the given key.
    ///
    /// Returns `nil` if the item does not exist.
    func load(forKey key: String) throws -> String?

    /// Deletes the value from the Keychain for the given key.
    ///
    /// Does not throw if the item does not exist.
    func delete(forKey key: String) throws
}

// MARK: - KeychainError

/// Errors that can occur during Keychain operations.
nonisolated enum KeychainError: Error, Equatable, Sendable {
    /// A Keychain operation failed with the given `OSStatus` code.
    case unexpectedStatus(OSStatus)
    /// The data retrieved from Keychain could not be decoded as UTF-8 text.
    case dataConversionError
}

// MARK: - KeychainService

/// Production implementation of `KeychainStorable` using the iOS Security framework.
///
/// All items are stored as `kSecClassGenericPassword` entries with:
/// - Service: `com.lifeautomation.idea-pilot`
/// - Accessibility: `kSecAttrAccessibleAfterFirstUnlock` (background sync compatible)
nonisolated final class KeychainService: KeychainStorable, Sendable {

    private let service: String

    /// Creates a Keychain service.
    ///
    /// - Parameter service: The `kSecAttrService` value. Defaults to `"com.lifeautomation.idea-pilot"`.
    init(service: String = "com.lifeautomation.idea-pilot") {
        self.service = service
    }

    func save(_ value: String, forKey key: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.dataConversionError
        }

        // Delete existing item first (upsert pattern).
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    func load(forKey key: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data,
                  let string = String(data: data, encoding: .utf8) else {
                throw KeychainError.dataConversionError
            }
            return string
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    func delete(forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
}
