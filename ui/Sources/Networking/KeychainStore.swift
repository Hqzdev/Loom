import Foundation
import Security

/// Thin wrapper over the macOS Keychain (generic-password items) for provider
/// API keys. Uses only Apple's Security framework — no third-party dependency.
///
/// Service id keeps the Tether brand + `loom` codename (see CLAUDE.md naming
/// rule); it does not collide with the existing `agenttrace.proxy.*`
/// UserDefaults keys, which stay untouched.
public enum KeychainStore {
    /// Keychain service namespace for all provider API-key accounts.
    public static let service = "dev.tether.loom.providerKeys"

    /// Provider API-key slots stored under the shared Tether Keychain service.
    public enum Account: String, CaseIterable {
        case openAIAPIKey = "openai-api-key"
        case anthropicAPIKey = "anthropic-api-key"
    }

    /// Reads a provider key from the macOS Keychain when it exists.
    public static func read(_ account: Account) -> String? {
        var query = baseQuery(account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8)
        else {
            return nil
        }
        return value
    }

    /// Saves a provider key, or deletes it when the input is empty.
    @discardableResult
    public static func save(_ account: Account, value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return delete(account)
        }
        guard let data = trimmed.data(using: .utf8) else { return false }

        let query = baseQuery(account)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return true
        }
        if updateStatus == errSecItemNotFound {
            var insert = query
            insert[kSecValueData as String] = data
            insert[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked
            return SecItemAdd(insert as CFDictionary, nil) == errSecSuccess
        }
        return false
    }

    /// Deletes a provider key from the macOS Keychain.
    @discardableResult
    public static func delete(_ account: Account) -> Bool {
        let status = SecItemDelete(baseQuery(account) as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    /// Returns whether a provider key is present without exposing the key value to callers.
    public static func hasValue(_ account: Account) -> Bool {
        read(account) != nil
    }

    /// Builds the shared generic-password query used by read, save, and delete operations.
    private static func baseQuery(_ account: Account) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account.rawValue
        ]
    }
}
