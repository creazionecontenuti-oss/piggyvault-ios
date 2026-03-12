import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var localization: LocalizationManager
    @State private var showContent = false
    @State private var showLanguagePicker = false
    @State private var showSignOutAlert = false
    @State private var showAccountProfile = false
    @AppStorage("biometricLockEnabled") private var biometricLockEnabled = true
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("settings.title".localized)
                        .font(PiggyTheme.Typography.title)
                        .foregroundColor(.white)
                    
                    Text("settings.subtitle".localized)
                        .font(PiggyTheme.Typography.subheadline)
                        .foregroundColor(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 60)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : -20)
                
                // Account Section
                accountSection
                
                // Wallet Section
                walletSection
                
                // App Section
                appSection
                
                // Security Section
                securitySection
                
                // About Section
                aboutSection
                
                // Sign Out
                signOutButton
                
                // Version
                Text("PiggyVault v1.0.0")
                    .font(PiggyTheme.Typography.caption)
                    .foregroundColor(.white.opacity(0.2))
                    .padding(.top, 8)
                
                Color.clear.frame(height: 100)
            }
            .padding(.horizontal, 20)
        }
        .background(PiggyTheme.Colors.background.ignoresSafeArea())
        .sheet(isPresented: $showAccountProfile) {
            AccountProfileView()
                .environmentObject(appState)
        }
        .sheet(isPresented: $showLanguagePicker) {
            languagePickerSheet
        }
        .alert("settings.sign_out_confirm.title".localized, isPresented: $showSignOutAlert) {
            Button("settings.sign_out".localized, role: .destructive) {
                appState.signOut()
            }
            Button("cancel".localized, role: .cancel) { }
        } message: {
            Text("settings.sign_out_confirm.message".localized)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                showContent = true
            }
        }
    }
    
    // MARK: - Account Section
    private var accountSection: some View {
        SettingsSection(title: "settings.account".localized) {
            if let wallet = appState.userWallet {
                Button {
                    HapticManager.lightTap()
                    showAccountProfile = true
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(PiggyTheme.Colors.primaryGradient)
                                .frame(width: 48, height: 48)
                            
                            Image(systemName: wallet.authMethod == .apple ? "apple.logo" : "g.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(wallet.shortAddress)
                                .font(PiggyTheme.Typography.bodyBold)
                                .foregroundColor(.white)
                            
                            HStack(spacing: 4) {
                                Text(wallet.authMethod == .apple ? "Apple ID" : "Google")
                                    .font(PiggyTheme.Typography.caption)
                                    .foregroundColor(.white.opacity(0.5))
                                
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(PiggyTheme.Colors.accentGreen)
                            }
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.2))
                    }
                    .padding(16)
                }
                .buttonStyle(.plain)
            }
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 20)
    }
    
    // MARK: - Wallet Section
    private var walletSection: some View {
        SettingsSection(title: "settings.wallet".localized) {
            VStack(spacing: 0) {
                SettingsRow(
                    icon: "shield.checkmark.fill",
                    iconColor: PiggyTheme.Colors.accentGreen,
                    title: "settings.safe_address".localized,
                    subtitle: appState.userWallet?.safeAddress.map { String($0.prefix(16)) + "..." } ?? "settings.not_deployed".localized
                ) { }
                
                Divider().background(Color.white.opacity(0.06)).padding(.leading, 52)
                
                SettingsRow(
                    icon: "network",
                    iconColor: PiggyTheme.Colors.accent,
                    title: "settings.network".localized,
                    subtitle: "Base (Chain ID: 8453)"
                ) { }
                
                Divider().background(Color.white.opacity(0.06)).padding(.leading, 52)
                
                SettingsRow(
                    icon: "arrow.triangle.2.circlepath",
                    iconColor: PiggyTheme.Colors.primary,
                    title: "settings.explorer".localized,
                    subtitle: "basescan.org",
                    showChevron: true
                ) {
                    HapticManager.lightTap()
                    if let url = appState.userWallet?.explorerURL {
                        UIApplication.shared.open(url)
                    }
                }
            }
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 20)
    }
    
    // MARK: - App Section
    private var appSection: some View {
        SettingsSection(title: "settings.app".localized) {
            VStack(spacing: 0) {
                SettingsRow(
                    icon: "globe",
                    iconColor: PiggyTheme.Colors.piggyBlue,
                    title: "settings.language".localized,
                    subtitle: "\(localization.currentLanguage.flag) \(localization.currentLanguage.displayName)",
                    showChevron: true
                ) {
                    HapticManager.lightTap()
                    showLanguagePicker = true
                }
                
                Divider().background(Color.white.opacity(0.06)).padding(.leading, 52)
                
                HStack(spacing: 14) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 18))
                        .foregroundColor(PiggyTheme.Colors.piggyOrange)
                        .frame(width: 32, height: 32)
                        .background(PiggyTheme.Colors.piggyOrange.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("settings.notifications".localized)
                            .font(PiggyTheme.Typography.body)
                            .foregroundColor(.white)
                        Text("settings.notifications_desc".localized)
                            .font(PiggyTheme.Typography.caption)
                            .foregroundColor(.white.opacity(0.4))
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: Binding(
                        get: { NotificationService.shared.notificationsEnabled },
                        set: { newValue in
                            NotificationService.shared.notificationsEnabled = newValue
                            if newValue {
                                Task { await NotificationService.shared.requestAuthorization() }
                            }
                            HapticManager.selection()
                        }
                    ))
                    .labelsHidden()
                    .tint(PiggyTheme.Colors.piggyOrange)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 20)
    }
    
    // MARK: - Security Section
    private var securitySection: some View {
        SettingsSection(title: "settings.security".localized) {
            VStack(spacing: 0) {
                // Biometric toggle row
                HStack(spacing: 14) {
                    Image(systemName: "faceid")
                        .font(.system(size: 18))
                        .foregroundColor(PiggyTheme.Colors.primary)
                        .frame(width: 28)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("settings.biometric".localized)
                            .font(PiggyTheme.Typography.body)
                            .foregroundColor(.white)
                        
                        Text("settings.biometric_desc".localized)
                            .font(PiggyTheme.Typography.caption)
                            .foregroundColor(.white.opacity(0.4))
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $biometricLockEnabled)
                        .labelsHidden()
                        .tint(PiggyTheme.Colors.primary)
                        .onChange(of: biometricLockEnabled) { _, newValue in
                            HapticManager.selection()
                        }
                }
                .padding(16)
                
                Divider().background(Color.white.opacity(0.06)).padding(.leading, 52)
                
                SettingsRow(
                    icon: "key.fill",
                    iconColor: PiggyTheme.Colors.accentGold,
                    title: "settings.recovery".localized,
                    subtitle: "settings.recovery_desc".localized,
                    showChevron: true
                ) { }
            }
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 20)
    }
    
    // MARK: - About Section
    private var aboutSection: some View {
        SettingsSection(title: "settings.about".localized) {
            VStack(spacing: 0) {
                SettingsRow(
                    icon: "doc.text.fill",
                    iconColor: .white.opacity(0.5),
                    title: "settings.terms".localized,
                    showChevron: true
                ) { }
                
                Divider().background(Color.white.opacity(0.06)).padding(.leading, 52)
                
                SettingsRow(
                    icon: "hand.raised.fill",
                    iconColor: .white.opacity(0.5),
                    title: "settings.privacy".localized,
                    showChevron: true
                ) { }
                
                Divider().background(Color.white.opacity(0.06)).padding(.leading, 52)
                
                SettingsRow(
                    icon: "questionmark.circle.fill",
                    iconColor: .white.opacity(0.5),
                    title: "settings.help".localized,
                    showChevron: true
                ) { }
            }
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 20)
    }
    
    // MARK: - Sign Out
    private var signOutButton: some View {
        Button {
            HapticManager.warning()
            showSignOutAlert = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text("settings.sign_out".localized)
            }
            .font(PiggyTheme.Typography.bodyBold)
            .foregroundColor(PiggyTheme.Colors.error)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: PiggyTheme.CornerRadius.medium)
                    .fill(PiggyTheme.Colors.error.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: PiggyTheme.CornerRadius.medium)
                            .stroke(PiggyTheme.Colors.error.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .opacity(showContent ? 1 : 0)
    }
    
    // MARK: - Language Picker Sheet
    private var languagePickerSheet: some View {
        NavigationStack {
            ZStack {
                PiggyTheme.Colors.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(SupportedLanguage.allCases) { language in
                            Button {
                                HapticManager.selection()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    localization.currentLanguage = language
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    showLanguagePicker = false
                                }
                            } label: {
                                HStack(spacing: 14) {
                                    Text(language.flag)
                                        .font(.system(size: 28))
                                    
                                    Text(language.displayName)
                                        .font(PiggyTheme.Typography.body)
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    if localization.currentLanguage == language {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 22))
                                            .foregroundColor(PiggyTheme.Colors.accentGreen)
                                            .transition(.scale.combined(with: .opacity))
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: PiggyTheme.CornerRadius.medium)
                                        .fill(localization.currentLanguage == language
                                              ? PiggyTheme.Colors.primary.opacity(0.1)
                                              : Color.clear)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                }
            }
            .navigationTitle("settings.language".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel".localized) { showLanguagePicker = false }
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

// MARK: - Reusable Settings Components

struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(PiggyTheme.Typography.caption)
                .foregroundColor(.white.opacity(0.4))
                .padding(.leading, 4)
            
            content
                .background(
                    RoundedRectangle(cornerRadius: PiggyTheme.CornerRadius.large)
                        .fill(PiggyTheme.Colors.surface.opacity(0.5))
                        .overlay(
                            RoundedRectangle(cornerRadius: PiggyTheme.CornerRadius.large)
                                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                        )
                )
        }
    }
}

struct SettingsRow: View {
    let icon: String
    var iconColor: Color = .white.opacity(0.5)
    let title: String
    var subtitle: String? = nil
    var showChevron: Bool = false
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button {
            HapticManager.lightTap()
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isPressed = false
                }
                action()
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(iconColor)
                    .frame(width: 28)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(PiggyTheme.Typography.body)
                        .foregroundColor(.white)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(PiggyTheme.Typography.caption)
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
                
                Spacer()
                
                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.2))
                        .offset(x: isPressed ? 2 : 0)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(isPressed ? 0.04 : 0))
            )
        }
        .buttonStyle(.plain)
    }
}
