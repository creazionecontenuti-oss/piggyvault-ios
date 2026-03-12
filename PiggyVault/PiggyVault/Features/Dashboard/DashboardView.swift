import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @State private var showContent = false
    @State private var isRefreshing = false
    
    private var totalFiatValue: Double {
        appState.totalBalance.reduce(0) { $0 + $1.fiatValue }
    }
    
    @State private var isLoadingData = true
    @State private var showTransactionHistory = false
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 24) {
                // Header
                headerSection
                
                // Safe deployment failed warning — blocks everything
                if appState.safeDeploymentFailed {
                    SafeDeploymentWarningBanner(
                        error: appState.safeDeploymentError,
                        isRetrying: appState.isDeployingRetry,
                        retryAction: { appState.retrySafeDeployment() }
                    )
                }
                
                if isLoadingData && appState.totalBalance.isEmpty {
                    DashboardShimmer()
                } else {
                    // Inline error banner if blockchain fetch failed but cached data shown
                    if appState.showError && !appState.totalBalance.isEmpty {
                        InlineErrorBanner(
                            message: appState.errorMessage,
                            retryAction: {
                                Task {
                                    appState.showError = false
                                    await appState.refreshData()
                                }
                            }
                        )
                    }
                    
                    // Total Balance Card
                    totalBalanceCard
                    
                    // Quick Actions (disabled if Safe not deployed)
                    quickActions
                    
                    // Assets
                    assetsSection
                    
                    // Piggy Banks Preview
                    piggyBanksPreview
                    
                    // Full error state if no data at all
                    if appState.showError && appState.totalBalance.isEmpty {
                        BlockchainErrorView(
                            errorMessage: appState.errorMessage,
                            retryAction: {
                                Task {
                                    appState.showError = false
                                    await appState.refreshData()
                                }
                            }
                        )
                        .frame(height: 300)
                    }
                }
                
                // Bottom spacing for tab bar
                Color.clear.frame(height: 100)
            }
            .padding(.horizontal, 20)
        }
        .refreshable {
            HapticManager.lightTap()
            await appState.refreshData()
            HapticManager.success()
        }
        .background(PiggyTheme.Colors.background.ignoresSafeArea())
        .sheet(isPresented: $showTransactionHistory) {
            TransactionHistoryView()
                .environmentObject(appState)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                showContent = true
            }
            Task {
                await appState.refreshData()
                withAnimation(.easeOut(duration: 0.3)) {
                    isLoadingData = false
                }
            }
        }
    }
    
    // MARK: - Header
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("dashboard.greeting".localized)
                    .font(PiggyTheme.Typography.subheadline)
                    .foregroundColor(.white.opacity(0.6))
                
                if let wallet = appState.userWallet {
                    Text(wallet.shortAddress)
                        .font(PiggyTheme.Typography.headline)
                        .foregroundColor(.white)
                }
            }
            
            Spacer()
            
            // Transaction history button
            Button {
                HapticManager.lightTap()
                showTransactionHistory = true
            } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(PiggyTheme.Colors.surface)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                            )
                    )
            }
            
            // Live network status
            NetworkStatusView()
        }
        .padding(.top, 60)
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : -20)
    }
    
    // MARK: - Total Balance
    private var totalBalanceCard: some View {
        GlassCard(padding: 24, cornerRadius: PiggyTheme.CornerRadius.xl) {
            VStack(spacing: 8) {
                Text("dashboard.total_balance".localized)
                    .font(PiggyTheme.Typography.subheadline)
                    .foregroundColor(.white.opacity(0.6))
                
                AnimatedCounter(
                    value: totalFiatValue,
                    prefix: "$",
                    font: PiggyTheme.Typography.balanceLarge
                )
                
                HStack(spacing: 4) {
                    Image(systemName: "shield.checkmark.fill")
                        .font(.system(size: 12))
                        .foregroundColor(PiggyTheme.Colors.accentGreen)
                    
                    Text("dashboard.secured".localized)
                        .font(PiggyTheme.Typography.caption)
                        .foregroundColor(PiggyTheme.Colors.accentGreen.opacity(0.8))
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
        }
        .opacity(showContent ? 1 : 0)
        .scaleEffect(showContent ? 1.0 : 0.95)
    }
    
    // MARK: - Quick Actions
    private var quickActions: some View {
        HStack(spacing: 12) {
            QuickActionButton(
                icon: "arrow.down.circle.fill",
                title: "dashboard.action.deposit".localized,
                color: PiggyTheme.Colors.accentGreen
            ) {
                // Navigate to deposit
            }
            
            QuickActionButton(
                icon: "lock.fill",
                title: "dashboard.action.new_piggy".localized,
                color: PiggyTheme.Colors.primary
            ) {
                // Navigate to create piggy bank
            }
            
            QuickActionButton(
                icon: "arrow.left.arrow.right",
                title: "dashboard.action.swap".localized,
                color: PiggyTheme.Colors.accent
            ) {
                // Navigate to swap
            }
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 20)
    }
    
    // MARK: - Assets Section
    private var assetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("dashboard.assets".localized)
                .font(PiggyTheme.Typography.title3)
                .foregroundColor(.white)
            
            if appState.totalBalance.isEmpty {
                GlassCard {
                    VStack(spacing: 12) {
                        FloatingIcon(
                            systemName: "wallet.pass",
                            gradient: LinearGradient(colors: [.white.opacity(0.4), .white.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing),
                            bgColor: .white,
                            size: 56
                        )
                        
                        Text("dashboard.no_assets".localized)
                            .font(PiggyTheme.Typography.body)
                            .foregroundColor(.white.opacity(0.5))
                        
                        Text("dashboard.no_assets_desc".localized)
                            .font(PiggyTheme.Typography.caption)
                            .foregroundColor(.white.opacity(0.3))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(appState.totalBalance) { balance in
                        AssetRow(balance: balance)
                    }
                }
            }
        }
        .opacity(showContent ? 1 : 0)
    }
    
    // MARK: - Piggy Banks Preview
    private var piggyBanksPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("dashboard.piggy_banks".localized)
                    .font(PiggyTheme.Typography.title3)
                    .foregroundColor(.white)
                
                Spacer()
                
                if !appState.piggyBanks.isEmpty {
                    Button {
                        // Navigate to piggy banks tab
                    } label: {
                        Text("dashboard.see_all".localized)
                            .font(PiggyTheme.Typography.captionBold)
                            .foregroundColor(PiggyTheme.Colors.primary)
                    }
                }
            }
            
            if appState.piggyBanks.isEmpty {
                GlassCard {
                    VStack(spacing: 16) {
                        FloatingIcon(
                            systemName: "lock.shield.fill",
                            gradient: PiggyTheme.Colors.primaryGradient,
                            bgColor: PiggyTheme.Colors.primary,
                            size: 72
                        )
                        
                        VStack(spacing: 8) {
                            Text("dashboard.no_piggy_banks".localized)
                                .font(PiggyTheme.Typography.headline)
                                .foregroundColor(.white)
                            
                            Text("dashboard.no_piggy_banks_desc".localized)
                                .font(PiggyTheme.Typography.body)
                                .foregroundColor(.white.opacity(0.5))
                                .multilineTextAlignment(.center)
                        }
                        
                        GlassButton(
                            title: "dashboard.create_first_piggy".localized,
                            icon: "plus"
                        ) {
                            // Navigate to create piggy bank
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
            } else {
                VStack(spacing: 12) {
                    ForEach(appState.piggyBanks.prefix(3)) { piggy in
                        PiggyCard(piggyBank: piggy)
                    }
                }
            }
        }
        .opacity(showContent ? 1 : 0)
    }
}

struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    @State private var isPressed = false
    @State private var iconBounce: CGFloat = 1.0
    
    var body: some View {
        Button(action: {
            HapticManager.lightTap()
            withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                isPressed = true
                iconBounce = 1.3
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) {
                    isPressed = false
                    iconBounce = 1.0
                }
                action()
            }
        }) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(color.opacity(isPressed ? 0.25 : 0.15))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: icon)
                        .font(.system(size: 22))
                        .foregroundColor(color)
                        .scaleEffect(iconBounce)
                }
                
                Text(title)
                    .font(PiggyTheme.Typography.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: PiggyTheme.CornerRadius.large)
                    .fill(PiggyTheme.Colors.surface.opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: PiggyTheme.CornerRadius.large)
                            .stroke(color.opacity(isPressed ? 0.2 : 0.06), lineWidth: 0.5)
                    )
            )
            .scaleEffect(isPressed ? 0.92 : 1.0)
            .shadow(color: color.opacity(isPressed ? 0.3 : 0), radius: 8, y: 2)
        }
        .buttonStyle(.plain)
    }
}
