import SwiftUI

struct GasBuyETHSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var webViewURL: URL?
    @State private var showContent = false
    
    private let mtPelerinService = MtPelerinService()
    
    private var safeAddress: String {
        appState.userWallet?.safeAddress ?? appState.userWallet?.address ?? ""
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                PiggyTheme.Colors.background.ignoresSafeArea()
                
                if let url = webViewURL {
                    VStack(spacing: 0) {
                        WebView(
                            url: url,
                            isLoading: .constant(false),
                            loadProgress: .constant(1.0)
                        )
                    }
                } else {
                    VStack(spacing: 24) {
                        Spacer()
                        
                        // Icon
                        ZStack {
                            Circle()
                                .fill(Color.orange.opacity(0.15))
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "fuelpump.fill")
                                .font(.system(size: 32, weight: .semibold))
                                .foregroundColor(.orange)
                        }
                        .opacity(showContent ? 1 : 0)
                        .scaleEffect(showContent ? 1 : 0.8)
                        
                        VStack(spacing: 8) {
                            Text("gas.buy.title".localized)
                                .font(PiggyTheme.Typography.title)
                                .foregroundColor(.white)
                            
                            Text("gas.buy.description".localized)
                                .font(PiggyTheme.Typography.body)
                                .foregroundColor(.white.opacity(0.6))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)
                        
                        Spacer()
                        
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: PiggyTheme.Colors.primary))
                            .scaleEffect(1.2)
                        
                        Spacer()
                    }
                }
            }
            .navigationTitle("gas.buy.nav_title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        HapticManager.lightTap()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(PiggyTheme.Colors.textSecondary)
                    }
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(PiggyTheme.Colors.surface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) {
                showContent = true
            }
            Task {
                let lang = Locale.current.language.languageCode?.identifier ?? "en"
                let supported = ["en", "fr", "de", "it", "es", "pt"]
                let langCode = supported.contains(lang) ? lang : "en"
                
                NSLog("%@", "[GasBuy] Opening Mt Pelerin buy for Safe: \(safeAddress)")
                
                // Buy stablecoins into the Safe — auto-swap will convert to ETH
                let url = await mtPelerinService.getBuyURL(
                    destinationAddress: safeAddress,
                    outputCurrency: "USDC",
                    amount: 5,
                    language: langCode
                )
                withAnimation(.easeInOut(duration: 0.3)) {
                    webViewURL = url
                }
            }
        }
    }
}
