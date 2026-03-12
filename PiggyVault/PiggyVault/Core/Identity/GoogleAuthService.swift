import Foundation
import AuthenticationServices
import SwiftUI
import CommonCrypto

// MARK: - Google OAuth via ASWebAuthenticationSession
// Zero external dependencies. Uses Apple's native web auth session.

enum GoogleAuthError: LocalizedError, Equatable {
    case missingClientID
    case authenticationFailed
    case tokenExchangeFailed
    case cancelled
    case invalidResponse
    case noIDToken
    
    var errorDescription: String? {
        switch self {
        case .missingClientID: return "error.auth.google_not_configured".localized
        case .authenticationFailed: return "error.auth.google_failed".localized
        case .tokenExchangeFailed: return "error.auth.token_exchange_failed".localized
        case .cancelled: return "error.auth.cancelled".localized
        case .invalidResponse: return "error.auth.invalid_response".localized
        case .noIDToken: return "error.auth.no_id_token".localized
        }
    }
}

struct GoogleTokenResponse {
    let idToken: String
    let accessToken: String
    let refreshToken: String?
    let email: String?
    let name: String?
}

@MainActor
final class GoogleAuthService: NSObject, ObservableObject {
    
    // TODO: Replace with real Client ID from Google Cloud Console
    // Create at: https://console.cloud.google.com/apis/credentials
    // Type: iOS application
    // Bundle ID: com.piggyvault.app
    private let clientID: String
    private let redirectURI: String
    
    private var authSession: ASWebAuthenticationSession?
    private var presentationAnchor: ASPresentationAnchor?
    
    override init() {
        // Load from config or env
        self.clientID = GoogleAuthConfig.clientID
        self.redirectURI = GoogleAuthConfig.redirectURI
        super.init()
    }
    
    /// Triggers Google Sign-In via ASWebAuthenticationSession
    /// Returns the Google ID token for use with Lit Protocol
    func signIn() async throws -> GoogleTokenResponse {
        guard !clientID.isEmpty, clientID != "YOUR_GOOGLE_CLIENT_ID" else {
            throw GoogleAuthError.missingClientID
        }
        
        // 1. Build the Google OAuth URL
        let authURL = buildAuthURL()
        
        // 2. Present the web auth session
        let callbackURL = try await presentAuthSession(url: authURL)
        
        // 3. Extract authorization code from callback
        let code = try extractAuthCode(from: callbackURL)
        
        // 4. Exchange code for tokens
        let tokenResponse = try await exchangeCodeForTokens(code: code)
        
        return tokenResponse
    }
    
    // MARK: - Private Methods
    
    private func buildAuthURL() -> URL {
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "openid email profile"),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "select_account"),
            // PKCE: code_challenge for security
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: PKCEHelper.shared.codeChallenge),
        ]
        return components.url!
    }
    
    private func presentAuthSession(url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: GoogleAuthConfig.callbackScheme
            ) { callbackURL, error in
                if let error = error {
                    if (error as NSError).code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        continuation.resume(throwing: GoogleAuthError.cancelled)
                    } else {
                        continuation.resume(throwing: GoogleAuthError.authenticationFailed)
                    }
                    return
                }
                
                guard let callbackURL = callbackURL else {
                    continuation.resume(throwing: GoogleAuthError.invalidResponse)
                    return
                }
                
                continuation.resume(returning: callbackURL)
            }
            
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            
            self.authSession = session
            session.start()
        }
    }
    
    private func extractAuthCode(from url: URL) throws -> String {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        
        if let error = components?.queryItems?.first(where: { $0.name == "error" })?.value {
            throw GoogleAuthError.authenticationFailed
        }
        
        guard let code = components?.queryItems?.first(where: { $0.name == "code" })?.value else {
            throw GoogleAuthError.invalidResponse
        }
        
        return code
    }
    
    private func exchangeCodeForTokens(code: String) async throws -> GoogleTokenResponse {
        let url = URL(string: "https://oauth2.googleapis.com/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let params = [
            "code": code,
            "client_id": clientID,
            "redirect_uri": redirectURI,
            "grant_type": "authorization_code",
            "code_verifier": PKCEHelper.shared.codeVerifier,
        ]
        
        request.httpBody = params
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw GoogleAuthError.tokenExchangeFailed
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let idToken = json["id_token"] as? String,
              let accessToken = json["access_token"] as? String else {
            throw GoogleAuthError.noIDToken
        }
        
        let refreshToken = json["refresh_token"] as? String
        
        // Decode ID token to extract user info (JWT payload)
        let userInfo = decodeJWTPayload(idToken)
        
        return GoogleTokenResponse(
            idToken: idToken,
            accessToken: accessToken,
            refreshToken: refreshToken,
            email: userInfo["email"] as? String,
            name: userInfo["name"] as? String
        )
    }
    
    private func decodeJWTPayload(_ jwt: String) -> [String: Any] {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { return [:] }
        
        var base64 = String(parts[1])
        // Pad to multiple of 4
        while base64.count % 4 != 0 {
            base64.append("=")
        }
        base64 = base64.replacingOccurrences(of: "-", with: "+")
                       .replacingOccurrences(of: "_", with: "/")
        
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return json
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension GoogleAuthService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }
}

// MARK: - PKCE Helper (Proof Key for Code Exchange)

final class PKCEHelper {
    static let shared = PKCEHelper()
    
    let codeVerifier: String
    let codeChallenge: String
    
    private init() {
        // Generate a cryptographically random code verifier
        var buffer = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)
        let verifier = Data(buffer).base64URLEncoded
        self.codeVerifier = verifier
        
        // code_challenge = BASE64URL(SHA256(code_verifier))
        let challengeData = Data(verifier.utf8)
        var hash = [UInt8](repeating: 0, count: 32)
        // Use CommonCrypto SHA256 for PKCE (not keccak)
        challengeData.withUnsafeBytes { ptr in
            _ = CC_SHA256(ptr.baseAddress, CC_LONG(challengeData.count), &hash)
        }
        self.codeChallenge = Data(hash).base64URLEncoded
    }
    
    /// Regenerates PKCE values for a new auth flow
    func regenerate() -> PKCEHelper {
        return PKCEHelper()
    }
}

// MARK: - Google Auth Configuration

enum GoogleAuthConfig {
    // iOS OAuth Client ID from Google Cloud Console
    // Bundle ID must match: com.piggyvault.app
    static var clientID: String {
        // Try loading from config file first
        if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path),
           let id = dict["CLIENT_ID"] as? String {
            return id
        }
        // Fallback to hardcoded (replace after creating Google Cloud project)
        return ProcessInfo.processInfo.environment["GOOGLE_CLIENT_ID"] ?? "YOUR_GOOGLE_CLIENT_ID"
    }
    
    // The reverse client ID is used as the URL scheme
    static var callbackScheme: String {
        // Reverse the client ID for the URL scheme
        // e.g., com.googleusercontent.apps.123456 -> reversed
        let components = clientID.split(separator: ".").reversed()
        return components.joined(separator: ".")
    }
    
    static var redirectURI: String {
        "\(callbackScheme):/oauth2callback"
    }
}

// MARK: - Base64URL Encoding

private extension Data {
    var base64URLEncoded: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
