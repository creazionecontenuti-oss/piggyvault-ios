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
        
        let claims = extractJWTClaims(tokenString)
        let authId = computeAuthMethodId(provider: "apple", token: tokenString)
        NSLog("%@", "[Lit] 🍎 Apple auth — authId: \(authId.prefix(20))")
        
        let pkpInfo = try await mintOrFetchPKP(
            authMethodType: .apple,
            token: tokenString,
            authId: authId,
            sub: claims["sub"]
        )
        
        NSLog("%@", "[Lit] 🍎 Apple auth complete — address: \(pkpInfo.ethAddress)")
        return pkpInfo.ethAddress
    }
    
    // MARK: - Google Sign-In Integration
    
    func authenticateWithGoogle(idToken: String) async throws -> String {
        let claims = extractJWTClaims(idToken)
        let authId = computeAuthMethodId(provider: "google", token: idToken)
        NSLog("%@", "[Lit] 🔵 Google auth — authId: \(authId.prefix(20))")
        
        let pkpInfo = try await mintOrFetchPKP(
            authMethodType: .google,
            token: idToken,
            authId: authId,
            sub: claims["sub"]
        )
        
        NSLog("%@", "[Lit] 🔵 Google auth complete — address: \(pkpInfo.ethAddress)")
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
        authId: String,
        sub: String?
    ) async throws -> PKPInfo {
        
        NSLog("%@", "[Lit] ═══════════════════════════════════════")
        NSLog("%@", "[Lit] 🔎 mintOrFetchPKP called")
        NSLog("%@", "[Lit]    authMethodType: \(authMethodType.rawValue)")
        NSLog("%@", "[Lit]    authId: \(authId)")
        NSLog("%@", "[Lit]    sub: \(sub ?? "nil")")
        
        // ── Layer 1a: PKP map lookup by authId ──
        let map = loadPKPMap()
        NSLog("%@", "[Lit] 📦 PKP map has \(map.count) entries: \(map.keys.map { String($0.prefix(20)) }.joined(separator: ", "))")
        if let mapped = map[authId] {
            NSLog("%@", "[Lit] ✅ L1a HIT — authId match in map: \(mapped.ethAddress)")
            keychainService.store(token, for: .litAuthSig)
            storePKPInfo(mapped)
            return mapped
        }
        NSLog("%@", "[Lit] ❌ L1a MISS — authId not in map")
        
        // ── Layer 1a.5: PKP map lookup by sub (resilient to aud changes) ──
        if let sub = sub {
            let subKey = "sub:" + sub
            if let mappedBySub = map[subKey] {
                NSLog("%@", "[Lit] ✅ L1a.5 HIT — sub match in map: \(mappedBySub.ethAddress)")
                // Re-enrich with current authId and persist both keys
                let enriched = PKPInfo(tokenId: mappedBySub.tokenId, publicKey: mappedBySub.publicKey, ethAddress: mappedBySub.ethAddress, authMethodId: authId)
                keychainService.store(token, for: .litAuthSig)
                storePKPInfo(enriched)
                return enriched
            }
            NSLog("%@", "[Lit] ❌ L1a.5 MISS — sub:\(sub) not in map")
        }
        
        // ── Layer 1b: Active PKP with matching authMethodId ──
        let storedPKP = getStoredPKP()
        NSLog("%@", "[Lit] 📦 Stored active PKP: \(storedPKP?.ethAddress ?? "nil"), authMethodId: \(storedPKP?.authMethodId ?? "nil")")
        if let stored = storedPKP, stored.authMethodId == authId {
            NSLog("%@", "[Lit] ✅ L1b HIT — active PKP authId match: \(stored.ethAddress)")
            keychainService.store(token, for: .litAuthSig)
            storePKPInfo(stored)
            return stored
        }
        NSLog("%@", "[Lit] ❌ L1b MISS — stored authMethodId doesn't match")
        
        // ── Layer 2: Fetch from Lit relay (existing PKP on-chain) ──
        NSLog("%@", "[Lit] 🔍 L2: Fetching existing PKPs from relay...")
        if let existingPKP = try? await fetchExistingPKP(
            authMethodType: authMethodType,
            authId: authId
        ) {
            NSLog("%@", "[Lit] ✅ L2 HIT — relay returned PKP: \(existingPKP.ethAddress)")
            let enriched = PKPInfo(tokenId: existingPKP.tokenId, publicKey: existingPKP.publicKey, ethAddress: existingPKP.ethAddress, authMethodId: authId)
            keychainService.store(token, for: .litAuthSig)
            storePKPInfo(enriched)
            return enriched
        }
        NSLog("%@", "[Lit] ❌ L2 MISS — relay returned nothing")
        
        // ── Layer 3: Mint new PKP (genuinely new user / new account) ──
        NSLog("%@", "[Lit] 🆕 L3: No existing PKP found anywhere, minting new one...")
        
        let requestId = try await requestMintPKP(
            authMethodType: authMethodType,
            token: token,
            authId: authId
        )
        
        let pkpInfo = try await pollMintStatus(requestId: requestId)
        let enriched = PKPInfo(tokenId: pkpInfo.tokenId, publicKey: pkpInfo.publicKey, ethAddress: pkpInfo.ethAddress, authMethodId: authId)
        
        keychainService.store(token, for: .litAuthSig)
        storePKPInfo(enriched)
        
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
        
        NSLog("%@", "[Lit] 🌐 Relay fetch — POST /fetch-pkps-by-auth-method authMethodType=\(authMethodType.rawValue) authId=\(authId.prefix(20))...")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            let errorBody = String(data: data, encoding: .utf8) ?? ""
            NSLog("%@", "[Lit] ⚠️ Fetch PKPs failed (\(statusCode)): \(errorBody)")
            return nil
        }
        
        let responseString = String(data: data, encoding: .utf8) ?? ""
        NSLog("%@", "[Lit] 📥 Fetch PKPs response: \(String(responseString.prefix(500)))")
        
        // Lit relay returns {"pkps": [{...}, ...]} — parse the wrapper object
        // Also handle raw array [...] as fallback
        let parsed = try JSONSerialization.jsonObject(with: data)
        var pkpArray: [[String: Any]] = []
        
        if let wrapper = parsed as? [String: Any],
           let pkps = wrapper["pkps"] as? [[String: Any]] {
            // Standard Lit relay response: {"pkps": [...]}
            pkpArray = pkps
            NSLog("%@", "[Lit] 📦 Parsed relay response as {\"pkps\": [...]}, found \(pkps.count) PKPs")
        } else if let rawArray = parsed as? [[String: Any]] {
            // Fallback: raw array [...]
            pkpArray = rawArray
            NSLog("%@", "[Lit] 📦 Parsed relay response as raw array, found \(rawArray.count) PKPs")
        } else {
            NSLog("%@", "[Lit] ⚠️ Unexpected relay response format: \(String(responseString.prefix(200)))")
            return nil
        }
        
        guard let firstPKP = pkpArray.first else {
            NSLog("%@", "[Lit] ℹ️ No PKPs found for this auth method")
            return nil
        }
        
        // Extract PKP info from the response
        let tokenId = firstPKP["tokenId"] as? String ?? firstPKP["pkpTokenId"] as? String ?? ""
        let publicKey = firstPKP["publicKey"] as? String ?? firstPKP["pkpPublicKey"] as? String ?? ""
        let ethAddress = firstPKP["ethAddress"] as? String ?? firstPKP["pkpEthAddress"] as? String ?? ""
        
        guard !publicKey.isEmpty else {
            NSLog("%@", "[Lit] ⚠️ PKP found but missing publicKey: \(firstPKP)")
            return nil
        }
        
        let address = ethAddress.isEmpty ? EthAddress.fromPublicKey(publicKey) : ethAddress
        NSLog("%@", "[Lit] ✅ Relay returned PKP: tokenId=\(tokenId.prefix(20))... addr=\(address)")
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
        let sub = claims["sub"]
        let aud = claims["aud"]
        let email = claims["email"]
        NSLog("%@", "[Lit] 🧮 computeAuthMethodId(\(provider)):")
        NSLog("%@", "[Lit]    sub=\(sub ?? "NIL") aud=\(aud ?? "NIL") email=\(email ?? "NIL")")
        if sub == nil {
            NSLog("%@", "[Lit]    ⚠️ JWT PARSE FAILED — using entire token as sub!")
        }
        let resolvedSub = sub ?? token
        let resolvedAud = aud ?? ""
        let input = "\(resolvedSub):\(resolvedAud)"
        let result = "0x" + Keccak256.hashHex(Data(input.utf8))
        NSLog("%@", "[Lit]    authMethodId=\(result)")
        return result
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
            NSLog("%@", "[Lit] 💾 Stored active PKP: \(info.ethAddress), authMethodId: \(info.authMethodId ?? "nil")")
        } else {
            NSLog("%@", "[Lit] ⛔ FAILED to encode PKP for storage!")
        }
        // Also persist in the PKP map keyed by BOTH authId and sub
        var map = loadPKPMap()
        if let authId = info.authMethodId {
            map[authId] = info
        }
        // Extract sub from stored token for sub-based lookup
        if let token = keychainService.retrieve(for: .litAuthSig) {
            let claims = extractJWTClaims(token)
            if let sub = claims["sub"] {
                let subKey = "sub:" + sub
                map[subKey] = info
                NSLog("%@", "[Lit] 💾 Also stored PKP under sub key: \(subKey.prefix(30))")
            }
        }
        savePKPMap(map)
        NSLog("%@", "[Lit] 💾 PKP map now has \(map.count) entries")
        // Verify storage round-trip
        if let verify = getStoredPKP() {
            NSLog("%@", "[Lit] ✅ Storage verified — read back: \(verify.ethAddress), authMethodId: \(verify.authMethodId ?? "nil")")
        } else {
            NSLog("%@", "[Lit] ⛔ Storage VERIFICATION FAILED — getStoredPKP returned nil!")
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
