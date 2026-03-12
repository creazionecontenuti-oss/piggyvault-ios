import Foundation
import Security
import LocalAuthentication
import CryptoKit

// MARK: - Secure Enclave Signing Service
// Manages P-256 keys in the Secure Enclave for local transaction authorization.
// The Secure Enclave key is used as a "Passkey" to gate transaction signing —
// the actual blockchain signature is performed by Lit Protocol's PKP (threshold signing),
// but the user must first prove physical presence via biometric + Secure Enclave.

enum SecureEnclaveError: LocalizedError {
    case keyNotFound
    case keyGenerationFailed(String)
    case signingFailed(String)
    case biometricFailed
    case noSecureEnclave
    case invalidPublicKey
    
    var errorDescription: String? {
        switch self {
        case .keyNotFound: return "error.secure.key_not_found".localized
        case .keyGenerationFailed(let msg): return String(format: "error.secure.key_generation_failed".localized, msg)
        case .signingFailed(let msg): return String(format: "error.secure.signing_failed".localized, msg)
        case .biometricFailed: return "error.secure.biometric_failed".localized
        case .noSecureEnclave: return "error.secure.no_secure_enclave".localized
        case .invalidPublicKey: return "error.secure.invalid_public_key".localized
        }
    }
}

final class SecureEnclaveService {
    
    private let keyTag = "com.piggyvault.secureenclave.signing"
    private let keychainService = KeychainService()
    
    // MARK: - Key Management
    
    /// Check if the device supports Secure Enclave
    var isAvailable: Bool {
        // Secure Enclave is available on A7+ chips (iPhone 5s and later)
        // On simulator, it's not available but we can fall back to keychain
        #if targetEnvironment(simulator)
        return true // Use software keys on simulator
        #else
        return true // All modern iOS devices support it
        #endif
    }
    
    /// Check if a signing key already exists
    func hasSigningKey() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: keyTag.data(using: .utf8)!,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecReturnRef as String: false
        ]
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }
    
    /// Generate a new P-256 key pair in the Secure Enclave
    /// Requires biometric authentication for every use of the private key
    @discardableResult
    func generateSigningKey() throws -> Data {
        // Delete existing key first
        deleteSigningKey()
        
        var accessError: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [.privateKeyUsage, .biometryCurrentSet],
            &accessError
        ) else {
            throw SecureEnclaveError.keyGenerationFailed(
                accessError?.takeRetainedValue().localizedDescription ?? "Access control creation failed"
            )
        }
        
        var attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: keyTag.data(using: .utf8)!,
                kSecAttrAccessControl as String: access
            ] as [String: Any]
        ]
        
        #if !targetEnvironment(simulator)
        attributes[kSecAttrTokenID as String] = kSecAttrTokenIDSecureEnclave
        #endif
        
        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            throw SecureEnclaveError.keyGenerationFailed(
                error?.takeRetainedValue().localizedDescription ?? "Unknown error"
            )
        }
        
        // Extract and return public key bytes
        return try getPublicKeyBytes(from: privateKey)
    }
    
    /// Get the public key bytes (uncompressed, 65 bytes: 04 + x + y)
    func getPublicKey() throws -> Data {
        let privateKey = try getPrivateKey()
        return try getPublicKeyBytes(from: privateKey)
    }
    
    /// Sign arbitrary data with the Secure Enclave key
    /// This will trigger biometric authentication
    func sign(data: Data) throws -> Data {
        let privateKey = try getPrivateKey()
        
        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(
            privateKey,
            .ecdsaSignatureMessageX962SHA256,
            data as CFData,
            &error
        ) else {
            throw SecureEnclaveError.signingFailed(
                error?.takeRetainedValue().localizedDescription ?? "Signing failed"
            )
        }
        
        return signature as Data
    }
    
    /// Sign a transaction hash (32 bytes) — triggers biometric prompt
    /// Returns DER-encoded ECDSA signature
    func signTransactionHash(_ hash: Data) throws -> Data {
        guard hash.count == 32 else {
            throw SecureEnclaveError.signingFailed("Transaction hash must be 32 bytes")
        }
        return try sign(data: hash)
    }
    
    /// Authorize a transaction by signing a challenge with the Secure Enclave key.
    /// Returns the signed challenge that proves biometric authentication + key possession.
    func authorizeTransaction(
        safeAddress: String,
        to: String,
        value: String,
        data: String,
        nonce: UInt64
    ) throws -> Data {
        // Create a deterministic challenge from the transaction parameters
        let challenge = createTransactionChallenge(
            safeAddress: safeAddress,
            to: to,
            value: value,
            data: data,
            nonce: nonce
        )
        
        // Sign the challenge — this triggers biometric authentication
        return try sign(data: challenge)
    }
    
    /// Verify a signature against the stored public key
    func verify(signature: Data, data: Data) throws -> Bool {
        let privateKey = try getPrivateKey()
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw SecureEnclaveError.invalidPublicKey
        }
        
        var error: Unmanaged<CFError>?
        let result = SecKeyVerifySignature(
            publicKey,
            .ecdsaSignatureMessageX962SHA256,
            data as CFData,
            signature as CFData,
            &error
        )
        
        return result
    }
    
    /// Delete the signing key (e.g., on logout)
    func deleteSigningKey() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: keyTag.data(using: .utf8)!,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom
        ]
        SecItemDelete(query as CFDictionary)
    }
    
    // MARK: - Private Helpers
    
    private func getPrivateKey() throws -> SecKey {
        let context = LAContext()
        context.localizedReason = "auth.biometric.transaction".localized
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: keyTag.data(using: .utf8)!,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecReturnRef as String: true,
            kSecUseAuthenticationContext as String: context
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess, let key = item else {
            throw SecureEnclaveError.keyNotFound
        }
        
        // Force cast is safe because SecItemCopyMatching with kSecReturnRef returns SecKey
        return (key as! SecKey)
    }
    
    private func getPublicKeyBytes(from privateKey: SecKey) throws -> Data {
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw SecureEnclaveError.invalidPublicKey
        }
        
        var error: Unmanaged<CFError>?
        guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, &error) else {
            throw SecureEnclaveError.invalidPublicKey
        }
        
        return publicKeyData as Data
    }
    
    /// Creates a deterministic challenge from transaction parameters.
    /// This ensures the user is authorizing this specific transaction.
    private func createTransactionChallenge(
        safeAddress: String,
        to: String,
        value: String,
        data: String,
        nonce: UInt64
    ) -> Data {
        var input = Data()
        input.append(Data(safeAddress.utf8))
        input.append(Data(to.utf8))
        input.append(Data(value.utf8))
        input.append(Data(data.utf8))
        
        var nonceBytes = nonce.bigEndian
        input.append(Data(bytes: &nonceBytes, count: 8))
        
        // Use Keccak256 to hash the challenge (Ethereum-native)
        return Keccak256.hash(input)
    }
}
