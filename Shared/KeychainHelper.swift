// KeychainHelper.swift
// Secure keychain storage shared between main app and widget extension

import Foundation
import Security

struct KeychainHelper {
    
    // IMPORTANT: This must match the App Group ID for keychain sharing
    private static let service = SharedSettings.suiteName
    private static let accessGroup = SharedSettings.suiteName
    private static let credentialsKey = "minut_credentials"
    
    // MARK: - Save Credentials
    
    static func saveCredentials(_ credentials: MinutCredentials) throws {
        let data = try JSONEncoder().encode(credentials)

        // Query to find existing item (without data)
        var deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: credentialsKey
        ]

        #if !targetEnvironment(simulator)
        deleteQuery[kSecAttrAccessGroup as String] = accessGroup
        #endif

        // Delete existing item first
        SecItemDelete(deleteQuery as CFDictionary)

        // Query to add new item (with data)
        var addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: credentialsKey,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        #if !targetEnvironment(simulator)
        addQuery[kSecAttrAccessGroup as String] = accessGroup
        #endif

        // Add new item
        let status = SecItemAdd(addQuery as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }
    
    // MARK: - Load Credentials
    
    static func loadCredentials() -> MinutCredentials? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: credentialsKey,
            kSecReturnData as String: true
        ]

        // Only use access group on device (simulator has issues with keychain access groups)
        #if !targetEnvironment(simulator)
        query[kSecAttrAccessGroup as String] = accessGroup
        #endif
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let credentials = try? JSONDecoder().decode(MinutCredentials.self, from: data) else {
            return nil
        }
        
        return credentials
    }
    
    // MARK: - Delete Credentials
    
    static func deleteCredentials() {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: credentialsKey
        ]

        // Only use access group on device (simulator has issues with keychain access groups)
        #if !targetEnvironment(simulator)
        query[kSecAttrAccessGroup as String] = accessGroup
        #endif
        
        SecItemDelete(query as CFDictionary)
    }
    
    // MARK: - Errors
    
    enum KeychainError: LocalizedError {
        case saveFailed(OSStatus)
        case loadFailed(OSStatus)
        
        var errorDescription: String? {
            switch self {
            case .saveFailed(let status):
                return "Failed to save to keychain: \(status)"
            case .loadFailed(let status):
                return "Failed to load from keychain: \(status)"
            }
        }
    }
}
