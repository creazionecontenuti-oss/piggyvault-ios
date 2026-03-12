import SwiftUI
import AuthenticationServices

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var loadingMessage = ""
    @Published var loadingProgress: Double = 0.0
    @Published var showError = false
    @Published var errorMessage = ""
    
    private let litService = LitProtocolService()
    private let googleAuthService = GoogleAuthService()
    
    // MARK: - Apple Sign-In
    
    func handleAppleSignIn(result: Result<ASAuthorization, Error>, appState: AppState) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                showError(message: "auth.error.invalid_credential".localized)
                return
            }
            
            Task {
                isLoading = true
                loadingProgress = 0.1
                loadingMessage = "auth.loading.authenticating".localized
                
                do {
                    loadingProgress = 0.3
                    loadingMessage = "auth.loading.lit_protocol".localized
                    
                    let address = try await litService.authenticateWithApple(credential: credential)
                    
                    loadingProgress = 0.8
                    loadingMessage = "auth.loading.finalizing".localized
                    
                    let wallet = UserWallet(address: address, authMethod: .apple)
                    
                    loadingProgress = 1.0
                    isLoading = false
                    appState.signIn(wallet: wallet)
                } catch {
                    isLoading = false
                    loadingProgress = 0
                    showError(message: error.localizedDescription)
                }
            }
            
        case .failure(let error):
            if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                showError(message: error.localizedDescription)
            }
        }
    }
    
    // MARK: - Google Sign-In (via ASWebAuthenticationSession)
    
    func handleGoogleSignIn(appState: AppState) {
        Task {
            isLoading = true
            loadingProgress = 0.1
            loadingMessage = "auth.loading.google".localized
            
            do {
                // Step 1: Google OAuth flow via native web auth session
                loadingProgress = 0.2
                let googleResponse = try await googleAuthService.signIn()
                
                // Step 2: Authenticate with Lit Protocol using Google ID token
                loadingProgress = 0.4
                loadingMessage = "auth.loading.lit_protocol".localized
                
                let address = try await litService.authenticateWithGoogle(idToken: googleResponse.idToken)
                
                // Step 3: Create wallet
                loadingProgress = 0.8
                loadingMessage = "auth.loading.finalizing".localized
                
                let wallet = UserWallet(address: address, authMethod: .google)
                
                loadingProgress = 1.0
                isLoading = false
                appState.signIn(wallet: wallet)
                
            } catch let error as GoogleAuthError where error == .cancelled {
                // User cancelled - no error to show
                isLoading = false
                loadingProgress = 0
                
            } catch {
                isLoading = false
                loadingProgress = 0
                showError(message: error.localizedDescription)
            }
        }
    }
    
    private func showError(message: String) {
        errorMessage = message
        showError = true
    }
}
