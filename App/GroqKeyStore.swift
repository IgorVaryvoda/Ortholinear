import Foundation
import Security

enum GroqKeyStore {
    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "com.varyvoda.Ortholinear.groq",
         kSecAttrAccount as String: "api-key"]
    }
    static func load() throws -> String {
        var q = query
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(q as CFDictionary, &result)
        if status == errSecItemNotFound { return "" }
        guard status == errSecSuccess, let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else { throw KeyError.failed }
        return value
    }
    static func save(_ key: String) throws {
        let clean = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, !clean.contains(where: { $0.isWhitespace }) else { throw KeyError.invalid }
        let values: [String: Any] = [kSecValueData as String: Data(clean.utf8),
                                     kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        let status = SecItemUpdate(query as CFDictionary, values as CFDictionary)
        if status == errSecItemNotFound {
            guard SecItemAdd(query.merging(values) { _, new in new } as CFDictionary, nil) == errSecSuccess else { throw KeyError.failed }
        } else if status != errSecSuccess { throw KeyError.failed }
    }
    static func remove() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeyError.failed }
    }
    enum KeyError: LocalizedError {
        case failed, invalid
        var errorDescription: String? { self == .invalid ? "Enter a valid Groq API key." : "The key could not be accessed securely. Unlock your device and try again." }
    }
}
