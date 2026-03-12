import Foundation
import Security

final class KeychainService {
    private let service = "com.piggyvault.app"
    
    enum Key: String {
        case walletAddress = "wallet_address"
        case safeAddress = "safe_address"
        case authMethod = "auth_method"
        case litAuthSig = "lit_auth_sig"
        case pkpPublicKey = "pkp_public_key"
        case pkpMap = "pkp_map"
    }
    
    func store(_ value: String, for key: Key) {
        let data = value.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    func retrieve(for key: Key) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    func delete(for key: Key) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]
        SecItemDelete(query as CFDictionary)
    }
    
    func storeWalletAddress(_ address: String) {
        store(address, for: .walletAddress)
    }
    
    func getWalletAddress() -> String? {
        retrieve(for: .walletAddress)
    }
    
    func deleteWalletAddress() {
        delete(for: .walletAddress)
    }
    
    func storeAuthMethod(_ method: AuthMethod) {
        store(method.rawValue, for: .authMethod)
    }
    
    func getAuthMethod() -> AuthMethod? {
        guard let raw = retrieve(for: .authMethod) else { return nil }
        return AuthMethod(rawValue: raw)
    }
    
    func deleteAuthMethod() {
        delete(for: .authMethod)
    }
    
    func storeSafeAddress(_ address: String) {
        store(address, for: .safeAddress)
    }
    
    func getSafeAddress() -> String? {
        retrieve(for: .safeAddress)
    }
    
    func storeSecureEnclaveKey(tag: String, privateKey: SecKey) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag.data(using: .utf8)!,
            kSecValueRef as String: privateKey,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    func deleteAll() {
        Key.allCases.forEach { delete(for: $0) }
    }
}

extension KeychainService.Key: CaseIterable {
    static var allCases: [KeychainService.Key] {
        [.walletAddress, .safeAddress, .authMethod, .litAuthSig, .pkpPublicKey, .pkpMap]
    }
}
