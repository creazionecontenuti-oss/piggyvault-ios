import SwiftUI

struct AccountProfileView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var showContent = false
    @State private var copiedField: String?
    @State private var ethBalance: Double = 0
    @State private var ringRotation: Double = 0
    @ObservedObject var networkMonitor = NetworkMonitor.shared
    
    var body: some View {
        NavigationStack {
            ZStack {
                PiggyTheme.Colors.background.ignoresSafeArea()
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Profile avatar & auth
                        profileHeader
                        
                        // Address cards
                        addressSection
                        
                        // Network info
                        networkSection
                        
                        // Gas balance
                        gasSection
                        
                        // Recovery info
                        recoverySection
                        
                        // Danger zone
                        dangerZone
                        
                        Color.clear.frame(height: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            }
            .navigationTitle("account.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) {
                    showContent = true
                }
                withAnimation(.linear(duration: 4.0).repeatForever(autoreverses: false)) {
                    ringRotation = 360
                }
                Task {
                    await loadGasBalance()
                }
            }
        }
    }
    
    // MARK: - Profile Header
    private var profileHeader: some View {
        VStack(spacing: 16) {
            // Avatar ring
            ZStack {
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [PiggyTheme.Colors.primary, PiggyTheme.Colors.accent, PiggyTheme.Colors.accentGreen, PiggyTheme.Colors.primary],
                            center: .center
                        ),
                        lineWidth: 3
                    )
                    .frame(width: 88, height: 88)
                    .rotationEffect(.degrees(ringRotation))
                
                Circle()
                    .fill(PiggyTheme.Colors.surface)
                    .frame(width: 80, height: 80)
                
                if let wallet = appState.userWallet {
                    Image(systemName: wallet.authMethod == .apple ? "apple.logo" : "g.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.white)
                }
            }
            
            VStack(spacing: 6) {
                if let wallet = appState.userWallet {
                    Text(wallet.authMethod == .apple ? "Apple ID" : "Google")
                        .font(PiggyTheme.Typography.headline)
                        .foregroundColor(.white)
                    
                    Text("account.signed_in_via".localized)
                        .font(PiggyTheme.Typography.caption)
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            
            // Status badges
            HStack(spacing: 10) {
                StatusBadge(
                    icon: "checkmark.shield.fill",
                    text: "account.non_custodial".localized,
                    color: PiggyTheme.Colors.accentGreen
                )
                
                StatusBadge(
                    icon: "network",
                    text: "Base L2",
                    color: PiggyTheme.Colors.accent
                )
            }
        }
        .padding(.vertical, 8)
        .opacity(showContent ? 1 : 0)
        .scaleEffect(showContent ? 1.0 : 0.95)
    }
    
    // MARK: - Address Section
    private var addressSection: some View {
        VStack(spacing: 12) {
            if let wallet = appState.userWallet {
                AddressCard(
                    title: "account.eoa_address".localized,
                    address: wallet.address,
                    icon: "person.circle.fill",
                    color: PiggyTheme.Colors.primary,
                    isCopied: copiedField == "eoa"
                ) {
                    copyToClipboard(wallet.address, field: "eoa")
                }
                
                if let safeAddr = wallet.safeAddress {
                    AddressCard(
                        title: "account.safe_address".localized,
                        address: safeAddr,
                        icon: "shield.checkmark.fill",
                        color: PiggyTheme.Colors.accentGreen,
                        isCopied: copiedField == "safe"
                    ) {
                        copyToClipboard(safeAddr, field: "safe")
                    }
                } else {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(PiggyTheme.Colors.warning)
                        Text("account.safe_not_deployed".localized)
                            .font(PiggyTheme.Typography.caption)
                            .foregroundColor(PiggyTheme.Colors.warning)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(PiggyTheme.Colors.warning.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(PiggyTheme.Colors.warning.opacity(0.2), lineWidth: 1)
                            )
                    )
                }
            }
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 20)
    }
    
    // MARK: - Network Section
    private var networkSection: some View {
        GlassCard {
            VStack(spacing: 14) {
                HStack {
                    Text("account.network_info".localized)
                        .font(PiggyTheme.Typography.captionBold)
                        .foregroundColor(.white.opacity(0.5))
                    Spacer()
                }
                
                InfoRow(label: "account.network".localized, value: "Base (Ethereum L2)")
                InfoRow(label: "account.chain_id".localized, value: "8453")
                InfoRow(label: "account.rpc".localized, value: "mainnet.base.org")
                
                HStack {
                    Text("account.status".localized)
                        .font(PiggyTheme.Typography.caption)
                        .foregroundColor(.white.opacity(0.5))
                    Spacer()
                    HStack(spacing: 6) {
                        NetworkDot()
                        Text(networkMonitor.status.isOnline ? "network.connected".localized : "network.disconnected".localized)
                            .font(PiggyTheme.Typography.captionBold)
                            .foregroundColor(networkMonitor.status.isOnline ? PiggyTheme.Colors.accentGreen : .red)
                    }
                }
                
                if networkMonitor.status.isOnline {
                    HStack {
                        Text("account.latency".localized)
                            .font(PiggyTheme.Typography.caption)
                            .foregroundColor(.white.opacity(0.5))
                        Spacer()
                        Text("\(Int(networkMonitor.latency * 1000))ms")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 20)
    }
    
    // MARK: - Gas Section
    private var gasSection: some View {
        GlassCard {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "fuelpump.fill")
                        .font(.system(size: 16))
                        .foregroundColor(PiggyTheme.Colors.piggyOrange)
                    
                    Text("account.gas_balance".localized)
                        .font(PiggyTheme.Typography.captionBold)
                        .foregroundColor(.white.opacity(0.5))
                    
                    Spacer()
                }
                
                HStack {
                    Text(String(format: "%.6f ETH", ethBalance))
                        .font(.system(size: 18, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    if ethBalance < 0.0001 {
                        Text("account.gas_low".localized)
                            .font(PiggyTheme.Typography.captionBold)
                            .foregroundColor(PiggyTheme.Colors.warning)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(PiggyTheme.Colors.warning.opacity(0.15))
                            )
                    }
                }
                
                Text("account.gas_desc".localized)
                    .font(PiggyTheme.Typography.caption)
                    .foregroundColor(.white.opacity(0.3))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 20)
    }
    
    // MARK: - Recovery Section
    private var recoverySection: some View {
        GlassCard {
            VStack(spacing: 14) {
                HStack {
                    Image(systemName: "key.fill")
                        .font(.system(size: 16))
                        .foregroundColor(PiggyTheme.Colors.accentGold)
                    
                    Text("account.recovery".localized)
                        .font(PiggyTheme.Typography.captionBold)
                        .foregroundColor(.white.opacity(0.5))
                    
                    Spacer()
                }
                
                Text("account.recovery_desc".localized)
                    .font(PiggyTheme.Typography.body)
                    .foregroundColor(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
                
                HStack(spacing: 12) {
                    RecoveryMethodBadge(icon: "apple.logo", name: "Apple ID", isActive: appState.userWallet?.authMethod == .apple)
                    RecoveryMethodBadge(icon: "g.circle.fill", name: "Google", isActive: appState.userWallet?.authMethod == .google)
                }
            }
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 20)
    }
    
    // MARK: - Danger Zone
    private var dangerZone: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("account.danger_zone".localized)
                .font(PiggyTheme.Typography.captionBold)
                .foregroundColor(PiggyTheme.Colors.error.opacity(0.6))
                .padding(.leading, 4)
            
            Button {
                HapticManager.warning()
                if let url = appState.userWallet?.explorerURL {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.up.right.square")
                        .foregroundColor(PiggyTheme.Colors.error.opacity(0.7))
                    
                    Text("account.view_explorer".localized)
                        .font(PiggyTheme.Typography.body)
                        .foregroundColor(PiggyTheme.Colors.error.opacity(0.7))
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(PiggyTheme.Colors.error.opacity(0.3))
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: PiggyTheme.CornerRadius.medium)
                        .fill(PiggyTheme.Colors.error.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: PiggyTheme.CornerRadius.medium)
                                .stroke(PiggyTheme.Colors.error.opacity(0.15), lineWidth: 0.5)
                        )
                )
            }
        }
        .opacity(showContent ? 1 : 0)
    }
    
    // MARK: - Helpers
    private func copyToClipboard(_ text: String, field: String) {
        UIPasteboard.general.string = text
        HapticManager.success()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            copiedField = field
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { copiedField = nil }
        }
    }
    
    private func loadGasBalance() async {
        guard let address = appState.userWallet?.safeAddress ?? appState.userWallet?.address else { return }
        let service = BlockchainService()
        if let balance = try? await service.getETHBalance(address: address) {
            await MainActor.run {
                withAnimation { ethBalance = balance }
            }
        }
    }
}

// MARK: - Subcomponents

struct StatusBadge: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
            Text(text)
                .font(PiggyTheme.Typography.captionBold)
        }
        .foregroundColor(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(color.opacity(0.12))
                .overlay(
                    Capsule()
                        .stroke(color.opacity(0.2), lineWidth: 0.5)
                )
        )
    }
}

struct AddressCard: View {
    let title: String
    let address: String
    let icon: String
    let color: Color
    let isCopied: Bool
    let onCopy: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)
                Text(title)
                    .font(PiggyTheme.Typography.captionBold)
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
            }
            
            HStack {
                Text(address)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Spacer()
                
                Button(action: onCopy) {
                    Image(systemName: isCopied ? "checkmark.circle.fill" : "doc.on.doc")
                        .font(.system(size: 16))
                        .foregroundColor(isCopied ? PiggyTheme.Colors.accentGreen : .white.opacity(0.4))
                        .contentTransition(.symbolEffect(.replace))
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(PiggyTheme.Colors.surface.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.15), lineWidth: 0.5)
                )
        )
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(PiggyTheme.Typography.caption)
                .foregroundColor(.white.opacity(0.5))
            Spacer()
            Text(value)
                .font(PiggyTheme.Typography.captionBold)
                .foregroundColor(.white.opacity(0.8))
        }
    }
}

struct RecoveryMethodBadge: View {
    let icon: String
    let name: String
    let isActive: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(isActive ? .white : .white.opacity(0.3))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(PiggyTheme.Typography.captionBold)
                    .foregroundColor(isActive ? .white : .white.opacity(0.3))
                
                Text(isActive ? "account.active".localized : "account.inactive".localized)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isActive ? PiggyTheme.Colors.accentGreen : .white.opacity(0.2))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isActive ? PiggyTheme.Colors.primary.opacity(0.1) : PiggyTheme.Colors.surface.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isActive ? PiggyTheme.Colors.primary.opacity(0.2) : Color.white.opacity(0.05), lineWidth: 0.5)
                )
        )
    }
}
