import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = AuthViewModel()
    @State private var showContent = false
    @State private var logoScale: CGFloat = 0.8
    @State private var logoGlow: CGFloat = 0.3
    @State private var logoRotation: Double = -15
    
    var body: some View {
        ZStack {
            PiggyTheme.Colors.background
                .ignoresSafeArea()
            
            BackgroundOrbs()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Logo & Branding
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(PiggyTheme.Colors.primary.opacity(logoGlow))
                            .frame(width: 140, height: 140)
                            .blur(radius: 25)
                        
                        Circle()
                            .fill(PiggyTheme.Colors.primaryGradient)
                            .frame(width: 100, height: 100)
                            .shadow(color: PiggyTheme.Colors.primary.opacity(0.5), radius: 20, y: 8)
                        
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.white)
                            .rotationEffect(.degrees(logoRotation))
                    }
                    .scaleEffect(logoScale)
                    
                    VStack(spacing: 8) {
                        Text("PiggyVault")
                            .font(PiggyTheme.Typography.largeTitle)
                            .foregroundColor(.white)
                        
                        Text("auth.subtitle".localized)
                            .font(PiggyTheme.Typography.body)
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }
                }
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 20)
                
                Spacer()
                
                // Auth Buttons
                VStack(spacing: 16) {
                    // Sign in with Apple
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.email, .fullName]
                    } onCompletion: { result in
                        viewModel.handleAppleSignIn(result: result, appState: appState)
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 56)
                    .cornerRadius(PiggyTheme.CornerRadius.medium)
                    .shadow(color: Color.white.opacity(0.1), radius: 8, y: 4)
                    
                    // Sign in with Google
                    Button {
                        HapticManager.mediumTap()
                        viewModel.handleGoogleSignIn(appState: appState)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "g.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(Color(hex: "4285F4"))
                            
                            Text("auth.google_sign_in".localized)
                                .font(PiggyTheme.Typography.headline)
                                .foregroundColor(.black)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: PiggyTheme.CornerRadius.medium)
                                .fill(Color.white)
                        )
                        .shadow(color: Color.white.opacity(0.1), radius: 8, y: 4)
                    }
                    
                    Text("auth.terms".localized)
                        .font(PiggyTheme.Typography.caption)
                        .foregroundColor(.white.opacity(0.4))
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                }
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 30)
                .padding(.horizontal, 24)
                .padding(.bottom, 50)
                
                // Non-custodial badge
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundColor(PiggyTheme.Colors.accentGreen)
                        .font(.system(size: 14))
                    
                    Text("auth.non_custodial".localized)
                        .font(PiggyTheme.Typography.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.bottom, 20)
                .opacity(showContent ? 1 : 0)
            }
            
            // Loading overlay with determinate progress
            if viewModel.isLoading {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .transition(.opacity)
                
                VStack(spacing: 24) {
                    ZStack {
                        // Background ring
                        Circle()
                            .stroke(Color.white.opacity(0.1), lineWidth: 6)
                            .frame(width: 80, height: 80)
                        
                        // Progress ring
                        Circle()
                            .trim(from: 0, to: viewModel.loadingProgress)
                            .stroke(
                                LinearGradient(
                                    colors: [PiggyTheme.Colors.primary, PiggyTheme.Colors.accent],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 6, lineCap: .round)
                            )
                            .frame(width: 80, height: 80)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.4), value: viewModel.loadingProgress)
                        
                        // Percentage
                        Text("\(Int(viewModel.loadingProgress * 100))%")
                            .font(PiggyTheme.Typography.headline)
                            .foregroundColor(.white)
                            .contentTransition(.numericText())
                            .animation(.easeInOut, value: viewModel.loadingProgress)
                    }
                    
                    Text(viewModel.loadingMessage)
                        .font(PiggyTheme.Typography.body)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .animation(.easeInOut, value: viewModel.loadingMessage)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .alert("error.title".localized, isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage)
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.2)) {
                showContent = true
                logoScale = 1.0
                logoRotation = 0
            }
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true).delay(1.0)) {
                logoGlow = 0.6
            }
        }
    }
}
