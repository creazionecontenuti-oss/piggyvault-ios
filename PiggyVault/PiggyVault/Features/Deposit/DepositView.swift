import SwiftUI

struct DepositView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = DepositViewModel()
    @State private var showContent = false
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("deposit.title".localized)
                        .font(PiggyTheme.Typography.title)
                        .foregroundColor(.white)
                    
                    Text("deposit.subtitle".localized)
                        .font(PiggyTheme.Typography.subheadline)
                        .foregroundColor(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 60)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : -20)
                
                // Block all money operations if Safe is not deployed
                if !appState.isSafeDeployed {
                    SafeDeploymentWarningBanner(
                        error: appState.safeDeploymentError,
                        isRetrying: appState.isDeployingRetry,
                        retryAction: { appState.retrySafeDeployment() }
                    )
                    .opacity(showContent ? 1 : 0)
                } else {
                    // Deposit methods
                    VStack(spacing: 16) {
                        // Bank Transfer (Mt Pelerin)
                        DepositMethodCard(
                            icon: "building.columns.fill",
                            title: "deposit.bank_transfer".localized,
                            subtitle: "deposit.bank_transfer_desc".localized,
                            badge: "deposit.no_kyc".localized,
                            badgeColor: PiggyTheme.Colors.accentGreen,
                            gradient: LinearGradient(
                                colors: [Color(hex: "2775CA"), Color(hex: "1A5FB4")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        ) {
                            HapticManager.mediumTap()
                            viewModel.openMtPelerinBuy(walletAddress: appState.userWallet?.safeAddress ?? "")
                        }
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 30)
                        
                        // Card Payment
                        DepositMethodCard(
                            icon: "creditcard.fill",
                            title: "deposit.card".localized,
                            subtitle: "deposit.card_desc".localized,
                            badge: "deposit.instant".localized,
                            badgeColor: PiggyTheme.Colors.accent,
                            gradient: LinearGradient(
                                colors: [Color(hex: "6C5CE7"), Color(hex: "A29BFE")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        ) {
                            HapticManager.mediumTap()
                            viewModel.openMtPelerinBuy(walletAddress: appState.userWallet?.safeAddress ?? "")
                        }
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 30)
                        
                        // Crypto Transfer
                        DepositMethodCard(
                            icon: "arrow.down.circle.fill",
                            title: "deposit.crypto".localized,
                            subtitle: "deposit.crypto_desc".localized,
                            badge: nil,
                            badgeColor: .clear,
                            gradient: LinearGradient(
                                colors: [Color(hex: "00E676"), Color(hex: "00C853")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        ) {
                            HapticManager.mediumTap()
                            viewModel.showReceiveAddress = true
                        }
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 30)
                        
                        // Withdraw to Bank
                        DepositMethodCard(
                            icon: "arrow.up.forward.circle.fill",
                            title: "deposit.withdraw".localized,
                            subtitle: "deposit.withdraw_desc".localized,
                            badge: "SEPA",
                            badgeColor: PiggyTheme.Colors.warning,
                            gradient: LinearGradient(
                                colors: [Color(hex: "FF6B6B"), Color(hex: "EE5A24")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        ) {
                            HapticManager.mediumTap()
                            viewModel.openMtPelerinSell(walletAddress: appState.userWallet?.safeAddress ?? "")
                        }
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 30)
                    }
                    
                    // IBAN Section — only show with valid Safe
                    if let safeAddr = appState.userWallet?.safeAddress {
                        ibanSection(address: safeAddr)
                    }
                    
                    // Info card
                    infoCard
                }
                
                Color.clear.frame(height: 100)
            }
            .padding(.horizontal, 20)
        }
        .background(PiggyTheme.Colors.background.ignoresSafeArea())
        .sheet(isPresented: $viewModel.showReceiveAddress) {
            receiveSheet
        }
        .sheet(isPresented: $viewModel.showBuyFlow) {
            BuyFlowSheet(
                viewModel: viewModel,
                walletAddress: appState.userWallet?.safeAddress ?? ""
            )
            .presentationDetents([.large])
        }
        .sheet(isPresented: $viewModel.showSellFlow) {
            SellFlowSheet(
                viewModel: viewModel,
                walletAddress: appState.userWallet?.safeAddress ?? ""
            )
            .presentationDetents([.large])
        }
        .sheet(isPresented: $viewModel.showWebView) {
            if let url = viewModel.webViewURL {
                WebViewContainer(url: url, title: "Mt Pelerin")
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                showContent = true
            }
        }
    }
    
    // MARK: - IBAN Section
    private func ibanSection(address: String) -> some View {
        GlassCard(padding: 20) {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "creditcard.and.123")
                        .font(.system(size: 20))
                        .foregroundColor(PiggyTheme.Colors.accent)
                    
                    Text("deposit.personal_iban".localized)
                        .font(PiggyTheme.Typography.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                
                Text("deposit.iban_desc".localized)
                    .font(PiggyTheme.Typography.caption)
                    .foregroundColor(.white.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack {
                    Text("deposit.iban_coming_soon".localized)
                        .font(PiggyTheme.Typography.callout)
                        .foregroundColor(.white.opacity(0.4))
                    
                    Spacer()
                    
                    Text("deposit.powered_by_mt_pelerin".localized)
                        .font(PiggyTheme.Typography.caption)
                        .foregroundColor(PiggyTheme.Colors.accent.opacity(0.6))
                }
            }
        }
        .opacity(showContent ? 1 : 0)
    }
    
    // MARK: - Info Card
    private var infoCard: some View {
        GlassCard(padding: 20) {
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(PiggyTheme.Colors.accent)
                    
                    Text("deposit.info.title".localized)
                        .font(PiggyTheme.Typography.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    InfoBullet(text: "deposit.info.bullet1".localized)
                    InfoBullet(text: "deposit.info.bullet2".localized)
                    InfoBullet(text: "deposit.info.bullet3".localized)
                }
            }
        }
        .opacity(showContent ? 1 : 0)
    }
    
    // MARK: - Receive Sheet
    private var receiveSheet: some View {
        NavigationStack {
            ZStack {
                PiggyTheme.Colors.background
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Spacer()
                    
                    VStack(spacing: 16) {
                        QRCodeView(
                            content: appState.userWallet?.safeAddress ?? "",
                            size: 200,
                            foregroundColor: .white,
                            backgroundColor: PiggyTheme.Colors.surface
                        )
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: PiggyTheme.CornerRadius.large)
                                .fill(PiggyTheme.Colors.surface)
                        )
                        
                        Text("deposit.receive.scan".localized)
                            .font(PiggyTheme.Typography.body)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    // Address
                    if let address = appState.userWallet?.safeAddress, !address.isEmpty {
                        VStack(spacing: 8) {
                            Text("deposit.receive.address".localized)
                                .font(PiggyTheme.Typography.captionBold)
                                .foregroundColor(.white.opacity(0.5))
                            
                            Text(address)
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: PiggyTheme.CornerRadius.medium)
                                        .fill(PiggyTheme.Colors.surface)
                                )
                            
                            Button {
                                UIPasteboard.general.string = address
                                HapticManager.success()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    viewModel.showCopiedFeedback = true
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    withAnimation(.easeOut) {
                                        viewModel.showCopiedFeedback = false
                                    }
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: viewModel.showCopiedFeedback ? "checkmark" : "doc.on.doc")
                                    Text(viewModel.showCopiedFeedback ? "deposit.receive.copied".localized : "deposit.receive.copy".localized)
                                }
                                .font(PiggyTheme.Typography.bodyBold)
                                .foregroundColor(PiggyTheme.Colors.primary)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(
                                    Capsule()
                                        .fill(PiggyTheme.Colors.primary.opacity(0.15))
                                )
                            }
                        }
                    }
                    
                    // Network warning
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(PiggyTheme.Colors.warning)
                        Text("deposit.receive.network_warning".localized)
                            .font(PiggyTheme.Typography.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: PiggyTheme.CornerRadius.small)
                            .fill(PiggyTheme.Colors.warning.opacity(0.08))
                    )
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
            }
            .navigationTitle("deposit.receive.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel".localized) { viewModel.showReceiveAddress = false }
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

struct DepositMethodCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let badge: String?
    let badgeColor: Color
    let gradient: LinearGradient
    let action: () -> Void
    
    @State private var isPressed = false
    @State private var iconBounce: CGFloat = 1.0
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                isPressed = true
                iconBounce = 1.2
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) {
                    isPressed = false
                    iconBounce = 1.0
                }
                action()
            }
        }) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(gradient)
                        .frame(width: 52, height: 52)
                        .shadow(color: badgeColor.opacity(isPressed ? 0.4 : 0.15), radius: isPressed ? 12 : 6, y: 2)
                    
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                        .scaleEffect(iconBounce)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(PiggyTheme.Typography.headline)
                            .foregroundColor(.white)
                        
                        if let badge = badge {
                            Text(badge)
                                .font(PiggyTheme.Typography.caption)
                                .foregroundColor(badgeColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(badgeColor.opacity(0.15))
                                )
                        }
                    }
                    
                    Text(subtitle)
                        .font(PiggyTheme.Typography.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.3))
                    .offset(x: isPressed ? 3 : 0)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: PiggyTheme.CornerRadius.large)
                    .fill(PiggyTheme.Colors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: PiggyTheme.CornerRadius.large)
                            .stroke(Color.white.opacity(isPressed ? 0.12 : 0.06), lineWidth: 0.5)
                    )
            )
            .scaleEffect(isPressed ? 0.96 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

struct InfoBullet: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(PiggyTheme.Colors.accent)
                .frame(width: 6, height: 6)
                .padding(.top, 6)
            
            Text(text)
                .font(PiggyTheme.Typography.caption)
                .foregroundColor(.white.opacity(0.6))
                .lineSpacing(2)
        }
    }
}

