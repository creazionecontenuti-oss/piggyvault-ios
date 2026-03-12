import Foundation
import AuthenticationServices

enum LitError: LocalizedError {
    case authFailed
    case pkpGenerationFailed
    case pkpMintPending
    case sessionExpired
    case networkError(String)
    case signingFailed(String)
    case noAuthMethod
    
    var errorDescription: String? {
        switch self {
        case .authFailed: return "error.lit.auth_failed".localized
        case .pkpGenerationFailed: return "error.lit.pkp_generation_failed".localized
        case .pkpMintPending: return "error.lit.pkp_mint_pending".localized
        case .sessionExpired: return "error.lit.session_expired".localized
        case .networkError(let msg): return String(format: "error.lit.network_error".localized, msg)
        case .signingFailed(let msg): return String(format: "error.lit.signing_failed".localized, msg)
        case .noAuthMethod: return "error.lit.no_auth_method".localized
        }
    }
}

/// Lit Protocol Auth Method Types (from Lit SDK constants)
enum LitAuthMethodType: Int {
    case ethWallet = 1
    case webAuthn = 3
    case google = 6       // GoogleJwt
    case apple = 8         // AppleJwt
}

/// Stored PKP info
struct PKPInfo: Codable {
    let tokenId: String
    let publicKey: String
    let ethAddress: String
    let authMethodId: String?
}

actor LitProtocolService {
    // Lit Relay Server - handles PKP minting without the user paying gas
    // Production: https://relayer-server-staging-cayenne.getlit.dev
    // Datil (v0.2): https://datil-relay-server.getlit.dev
    private let litRelayURL = "https://datil-relayer.getlit.dev"
    
    // Lit Network Nodes (Datil network - latest stable)
    private let litNetwork = "datil"
    
    private let session: URLSession
    private let keychainService = KeychainService()
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 120
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Apple Sign-In Integration
    
    func authenticateWithApple(credential: ASAuthorizationAppleIDCredential) async throws -> String {
        guard let identityToken = credential.identityToken,
              let tokenString = String(data: identityToken, encoding: .utf8) else {
            throw LitError.authFailed
        }
        
        // Apple Sign-In uses OIDC auth method with Lit
        // authMethodType = 7 (Apple OIDC)
        let pkpInfo = try await mintOrFetchPKP(
            authMethodType: .apple,
            token: tokenString,
            authId: computeAuthMethodId(provider: "apple", token: tokenString)
        )
        
        // Store PKP info in keychain
        storePKPInfo(pkpInfo)
        
        return pkpInfo.ethAddress
    }
    
    // MARK: - Google Sign-In Integration
    
    func authenticateWithGoogle(idToken: String) async throws -> String {
        // Google uses OIDC auth method with Lit
        // authMethodType = 6 (Google OIDC)
        let pkpInfo = try await mintOrFetchPKP(
            authMethodType: .google,
            token: idToken,
            authId: computeAuthMethodId(provider: "google", token: idToken)
        )
        
        // Store PKP info in keychain
        storePKPInfo(pkpInfo)
        
        return pkpInfo.ethAddress
    }
    
    // MARK: - PKP Management
    
    func getStoredPKP() -> PKPInfo? {
        guard let pkpKey = keychainService.retrieve(for: .pkpPublicKey) else { return nil }
        guard let data = pkpKey.data(using: .utf8),
              let info = try? JSONDecoder().decode(PKPInfo.self, from: data) else {
            // Legacy format: just the public key (no authMethodId)
            return PKPInfo(
                tokenId: "",
                publicKey: pkpKey,
                ethAddress: EthAddress.fromPublicKey(pkpKey),
                authMethodId: nil
            )
        }
        return info
    }
    
    // MARK: - Transaction Signing via Lit Action
    
    func signTransaction(txHash: Data, chainId: Int = BaseNetwork.chainId) async throws -> Data {
        guard let pkpInfo = getStoredPKP() else {
            throw LitError.sessionExpired
        }
        
        guard let authToken = keychainService.retrieve(for: .litAuthSig) else {
            throw LitError.noAuthMethod
        }
        
        // Use Lit Action to sign with the PKP
        // The Lit nodes collectively compute the ECDSA signature using threshold cryptography
        let signature = try await executeSigningLitAction(
            pkpPublicKey: pkpInfo.publicKey,
            toSign: txHash,
            authToken: authToken
        )
        
        return signature
    }
    
    // MARK: - Private: Mint or Fetch PKP via Relay
    
    private func mintOrFetchPKP(
        authMethodType: LitAuthMethodType,
        token: String,
        authId: String
    ) async throws -> PKPInfo {
        
        // ── Layer 1a: PKP map lookup (multi-account safe) ──
        let map = loadPKPMap()
        if let mapped = map[authId] {
            print("[Lit] ✅ Reusing PKP from map for authId: \(mapped.ethAddress)")
            keychainService.store(token, for: .litAuthSig)
            return mapped
        }
        
        // ── Layer 1b: Active PKP with matching authMethodId ──
        if let stored = getStoredPKP(), stored.authMethodId == authId {
            print("[Lit] ✅ Reusing stored PKP from keychain: \(stored.ethAddress)")
            keychainService.store(token, for: .litAuthSig)
            return stored
        }
        
        // ── Layer 2: Fetch from Lit relay (existing PKP on-chain) ──
        print("[Lit] 🔍 Fetching existing PKPs from relay for authId: \(authId.prefix(20))...")
        if let existingPKP = try? await fetchExistingPKP(
            authMethodType: authMethodType,
            authId: authId
        ) {
            print("[Lit] ✅ Found existing PKP on relay: \(existingPKP.ethAddress)")
            let enriched = PKPInfo(tokenId: existingPKP.tokenId, publicKey: existingPKP.publicKey, ethAddress: existingPKP.ethAddress, authMethodId: authId)
            keychainService.store(token, for: .litAuthSig)
            return enriched
        }
        
        // ── Layer 2.5: Legacy PKP fallback (relay down + stored PKP without authMethodId) ──
        if let stored = getStoredPKP(), stored.authMethodId == nil {
            print("[Lit] ⚠️ Relay unreachable — enriching legacy PKP optimistically: \(stored.ethAddress)")
            let enriched = PKPInfo(tokenId: stored.tokenId, publicKey: stored.publicKey, ethAddress: stored.ethAddress, authMethodId: authId)
            keychainService.store(token, for: .litAuthSig)
            return enriched
        }
        
        // ── Layer 3: Mint new PKP (genuinely new user) ──
        print("[Lit] 🆕 No existing PKP found, minting new one...")
        
        let requestId = try await requestMintPKP(
            authMethodType: authMethodType,
            token: token,
            authId: authId
        )
        
        let pkpInfo = try await pollMintStatus(requestId: requestId)
        
        // Enrich with authMethodId before returning
        let enriched = PKPInfo(tokenId: pkpInfo.tokenId, publicKey: pkpInfo.publicKey, ethAddress: pkpInfo.ethAddress, authMethodId: authId)
        
        keychainService.store(token, for: .litAuthSig)
        
        return enriched
    }
    
    /// Fetch existing PKPs associated with an auth method from the Lit relay
    private func fetchExistingPKP(
        authMethodType: LitAuthMethodType,
        authId: String
    ) async throws -> PKPInfo? {
        let body: [String: Any] = [
            "authMethodType": authMethodType.rawValue,
            "authMethodId": authId
        ]
        
        var request = URLRequest(url: URL(string: "\(litRelayURL)/fetch-pkps-by-auth-method")!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(litRelayApiKey, forHTTPHeaderField: "api-key")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            let errorBody = String(data: data, encoding: .utf8) ?? ""
            print("[Lit] ⚠️ Fetch PKPs failed (\(statusCode)): \(errorBody)")
            return nil
        }
        
        let responseString = String(data: data, encoding: .utf8) ?? ""
        print("[Lit] 📥 Fetch PKPs response: \(responseString.prefix(500))")
        
        // Response is an array of PKPs
        guard let pkps = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let firstPKP = pkps.first else {
            print("[Lit] ℹ️ No PKPs found for this auth method")
            return nil
        }
        
        // Extract PKP info from the response
        let tokenId = firstPKP["tokenId"] as? String ?? firstPKP["pkpTokenId"] as? String ?? ""
        let publicKey = firstPKP["publicKey"] as? String ?? firstPKP["pkpPublicKey"] as? String ?? ""
        let ethAddress = firstPKP["ethAddress"] as? String ?? firstPKP["pkpEthAddress"] as? String ?? ""
        
        guard !publicKey.isEmpty else {
            print("[Lit] ⚠️ PKP found but missing publicKey")
            return nil
        }
        
        let address = ethAddress.isEmpty ? EthAddress.fromPublicKey(publicKey) : ethAddress
        return PKPInfo(tokenId: tokenId, publicKey: publicKey, ethAddress: address, authMethodId: nil)
    }
    
    private func requestMintPKP(
        authMethodType: LitAuthMethodType,
        token: String,
        authId: String
    ) async throws -> String {
        // Lit Datil relay uses unified /mint-next-and-add-auth-methods endpoint
        // Body format matches Lit JS SDK: BaseProvider.prepareMintBody()
        let body: [String: Any] = [
            "keyType": 2,
            "permittedAuthMethodTypes": [authMethodType.rawValue],
            "permittedAuthMethodIds": [authId],
            "permittedAuthMethodPubkeys": ["0x"],
            "permittedAuthMethodScopes": [[1]],  // SignAnything
            "addPkpEthAddressAsPermittedAddress": true,
            "sendPkpToItself": true
        ]
        
        var request = URLRequest(url: URL(string: "\(litRelayURL)/mint-next-and-add-auth-methods")!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(litRelayApiKey, forHTTPHeaderField: "api-key")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LitError.networkError("No HTTP response")
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw LitError.networkError("Relay error (\(httpResponse.statusCode)): \(errorBody)")
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let requestId = json["requestId"] as? String else {
            throw LitError.pkpGenerationFailed
        }
        
        return requestId
    }
    
    private func pollMintStatus(requestId: String, maxAttempts: Int = 30) async throws -> PKPInfo {
        var attempts = 0
        
        while attempts < maxAttempts {
            attempts += 1
            
            var request = URLRequest(url: URL(string: "\(litRelayURL)/auth/status/\(requestId)")!)
            request.httpMethod = "GET"
            request.addValue("application/json", forHTTPHeaderField: "Accept")
            request.addValue(litRelayApiKey, forHTTPHeaderField: "api-key")
            
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                // Retry on server errors
                try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                continue
            }
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw LitError.pkpGenerationFailed
            }
            
            let status = json["status"] as? String ?? ""
            
            switch status {
            case "Succeeded":
                guard let pkpTokenId = json["pkpTokenId"] as? String,
                      let pkpPublicKey = json["pkpPublicKey"] as? String,
                      let pkpEthAddress = json["pkpEthAddress"] as? String else {
                    throw LitError.pkpGenerationFailed
                }
                
                return PKPInfo(
                    tokenId: pkpTokenId,
                    publicKey: pkpPublicKey,
                    ethAddress: pkpEthAddress,
                    authMethodId: nil
                )
                
            case "Failed":
                let error = json["error"] as? String ?? "Unknown mint error"
                throw LitError.networkError(error)
                
            case "InProgress", "Pending":
                // Wait and retry
                try await Task.sleep(nanoseconds: 2_000_000_000)
                continue
                
            default:
                try await Task.sleep(nanoseconds: 2_000_000_000)
                continue
            }
        }
        
        throw LitError.pkpMintPending
    }
    
    // MARK: - Lit Action Signing
    
    private func executeSigningLitAction(
        pkpPublicKey: String,
        toSign: Data,
        authToken: String
    ) async throws -> Data {
        // For production, this requires a WebView bridge to the Lit JS SDK
        // because Lit's threshold signing is only available in their JS library.
        //
        // The flow is:
        // 1. Swift -> WKWebView running Lit JS SDK
        // 2. JS calls LitNodeClient.executeJs() with signing Lit Action
        // 3. Lit nodes collectively produce ECDSA signature
        // 4. JS sends signature back to Swift via WKScriptMessageHandler
        //
        // For now, throw an error indicating WebView bridge is needed
        throw LitError.signingFailed("Lit JS bridge not yet initialized. First deposit will use relayer.")
    }
    
    // MARK: - Helpers
    
    /// Compute auth method ID: 0x + keccak256(sub + ":" + aud) — matches Lit JS SDK GoogleProvider/AppleProvider
    private func computeAuthMethodId(provider: String, token: String) -> String {
        let claims = extractJWTClaims(token)
        let sub = claims["sub"] ?? token
        let aud = claims["aud"] ?? ""
        let input = "\(sub):\(aud)"
        return "0x" + Keccak256.hashHex(Data(input.utf8))
    }
    
    private func extractJWTClaims(_ jwt: String) -> [String: String] {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { return [:] }
        
        var base64 = String(parts[1])
        while base64.count % 4 != 0 { base64.append("=") }
        base64 = base64.replacingOccurrences(of: "-", with: "+")
                       .replacingOccurrences(of: "_", with: "/")
        
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        
        var claims: [String: String] = [:]
        if let sub = json["sub"] as? String { claims["sub"] = sub }
        // aud can be a string or array
        if let aud = json["aud"] as? String {
            claims["aud"] = aud
        } else if let audArray = json["aud"] as? [String], let first = audArray.first {
            claims["aud"] = first
        }
        if let email = json["email"] as? String { claims["email"] = email }
        return claims
    }
    
    private func storePKPInfo(_ info: PKPInfo) {
        // Store as the "active" PKP for signing
        if let data = try? JSONEncoder().encode(info),
           let string = String(data: data, encoding: .utf8) {
            keychainService.store(string, for: .pkpPublicKey)
        }
        // Also persist in the PKP map for multi-account recovery
        if let authId = info.authMethodId {
            var map = loadPKPMap()
            map[authId] = info
            savePKPMap(map)
        }
    }
    
    private func loadPKPMap() -> [String: PKPInfo] {
        guard let raw = keychainService.retrieve(for: .pkpMap),
              let data = raw.data(using: .utf8),
              let map = try? JSONDecoder().decode([String: PKPInfo].self, from: data) else {
            return [:]
        }
        return map
    }
    
    private func savePKPMap(_ map: [String: PKPInfo]) {
        if let data = try? JSONEncoder().encode(map),
           let string = String(data: data, encoding: .utf8) {
            keychainService.store(string, for: .pkpMap)
        }
    }
    
    /// Lit Relay API key (free tier, rate-limited)
    private var litRelayApiKey: String {
        // The relay server requires an API key for rate limiting
        // This is a publishable key, safe to include in client
        ProcessInfo.processInfo.environment["LIT_RELAY_API_KEY"] ?? "67e55044-10b1-426f-9247-bb680e5fe0c8_relayer"
    }
}
