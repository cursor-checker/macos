import Foundation
import Security

/// Stores app secrets in Application Support (`secrets.json`, mode 0600).
/// One-time migration from the legacy Keychain entries is performed on first access.
enum SecretStore {
    private static let lock = NSLock()
    private static var didMigrateFromKeychain = false

    private struct FilePayload: Codable {
        var entries: [String: String] = [:]
    }

    static var fileURL: URL {
        Config.directory.appendingPathComponent("secrets.json")
    }

    static func set(_ value: String, account: String) {
        migrateFromKeychainIfNeeded()
        lock.lock()
        defer { lock.unlock() }

        var payload = loadPayloadUnlocked()
        if value.isEmpty {
            payload.entries.removeValue(forKey: account)
        } else {
            payload.entries[account] = value
        }
        savePayloadUnlocked(payload)
    }

    static func get(_ account: String) -> String? {
        migrateFromKeychainIfNeeded()
        lock.lock()
        defer { lock.unlock() }

        guard let value = loadPayloadUnlocked().entries[account], !value.isEmpty else {
            return nil
        }
        return value
    }

    static func delete(_ account: String) {
        set("", account: account)
    }

    static func deleteAll() {
        migrateFromKeychainIfNeeded()
        lock.lock()
        defer { lock.unlock() }
        try? FileManager.default.removeItem(at: fileURL)
    }

    // MARK: - Keychain migration

    private static let legacyKeychainService = "com.nokk3r.cursorchecker"

    private static let legacyAccounts = [
        Config.telegramSecretAccount,
        Config.cursorCredentialsAccount,
        Config.legacyCursorTokenAccount,
        Config.legacyCursorEmailAccount,
    ]

    static func migrateFromKeychainIfNeeded() {
        lock.lock()
        if didMigrateFromKeychain {
            lock.unlock()
            return
        }
        didMigrateFromKeychain = true
        lock.unlock()

        var payload = loadPayloadUnlocked()
        var changed = false

        for account in legacyAccounts {
            let existing = payload.entries[account]?.isEmpty == false
            if !existing, let legacy = keychainGet(account), !legacy.isEmpty {
                payload.entries[account] = legacy
                changed = true
            }
            keychainDelete(account)
        }

        if changed {
            lock.lock()
            savePayloadUnlocked(payload)
            lock.unlock()
        }
    }

    // MARK: - File I/O

    private static func loadPayloadUnlocked() -> FilePayload {
        Config.ensureDirectory()
        guard let data = try? Data(contentsOf: fileURL),
              let payload = try? JSONDecoder().decode(FilePayload.self, from: data) else {
            return FilePayload()
        }
        return payload
    }

    private static func savePayloadUnlocked(_ payload: FilePayload) {
        Config.ensureDirectory()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(payload) else { return }
        try? data.write(to: fileURL, options: .atomic)
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: fileURL.path
        )
    }

    // MARK: - Legacy Keychain (migration only)

    private static func keychainGet(_ account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: legacyKeychainService,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var out: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess,
              let data = out as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        return value
    }

    private static func keychainDelete(_ account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: legacyKeychainService,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
