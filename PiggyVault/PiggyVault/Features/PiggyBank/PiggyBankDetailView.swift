import SwiftUI

struct PiggyBankDetailView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    let piggyBank: PiggyBank
    
    @State private var showContent = false
    @State private var showDepositSheet = false
    @State private var depositAmount: String = ""
    @State private var isDepositing = false
    @State private var depositProgress: Double = 0
    @State private var toast: ToastData? = nil
    @State private var showUnlockConfirm = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                PiggyTheme.Colors.background
                    .ignoresSafeArea()
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Hero section
                        heroSection
                        
                        // Progress section
                        progressSection
                        
                        // Details
                        detailsSection
                        
                        // Actions
                        actionsSection
                        
                        Color.clear.frame(height: 20)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationTitle(piggyBank.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(isPresented: $showDepositSheet) {
                depositSheet
            }
            .alert("piggy.detail.unlock_confirm.title".localized, isPresented: $showUnlockConfirm) {
                Button("piggy.detail.unlock".localized, role: .destructive) {
                    HapticManager.heavyTap()
                    executeUnlock()
                }
                Button("cancel".localized, role: .cancel) { }
            } message: {
                Text("piggy.detail.unlock_confirm.message".localized)
            }
            .toast($toast)
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                    showContent = true
                }
            }
        }
    }
    
    @State private var heroGlow: Double = 0.15
    @State private var badgeScale: CGFloat = 0.5
    
    // MARK: - Hero Section
    private var heroSection: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(piggyBank.color.gradient.opacity(heroGlow))
                    .frame(width: 160, height: 160)
                    .blur(radius: 30)
                
                ProgressRing(
                    progress: piggyBank.progress,
                    size: 120,
                    lineWidth: 10,
                    gradient: piggyBank.color.gradient
                )
            }
            
            VStack(spacing: 8) {
                AnimatedCounter(
                    value: piggyBank.currentAmount,
                    font: PiggyTheme.Typography.balanceLarge,
                    color: .white,
                    decimals: 2,
                    duration: 1.0
                )
                
                Text(piggyBank.asset.symbol)
                    .font(PiggyTheme.Typography.headline)
                    .foregroundColor(piggyBank.asset.color)
            }
            
            // Status badge
            HStack(spacing: 6) {
                Image(systemName: piggyBank.status.icon)
                    .symbolEffect(.pulse, options: .repeating, value: piggyBank.status == .locked)
                Text(piggyBank.status.rawValue.capitalized)
                    .font(PiggyTheme.Typography.captionBold)
            }
            .foregroundColor(piggyBank.status.color)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(piggyBank.status.color.opacity(0.15))
            )
            .scaleEffect(badgeScale)
        }
        .padding(.top, 20)
        .opacity(showContent ? 1 : 0)
        .scaleEffect(showContent ? 1 : 0.9)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                heroGlow = 0.35
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.5).delay(0.4)) {
                badgeScale = 1.0
            }
        }
    }
    
    // MARK: - Progress Section
    private var progressSection: some View {
        GlassCard(padding: 20) {
            VStack(spacing: 16) {
                HStack {
                    Text("piggy.detail.progress".localized)
                        .font(PiggyTheme.Typography.headline)
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(Int(piggyBank.progress * 100))%")
                        .font(PiggyTheme.Typography.headline)
                        .foregroundColor(piggyBank.color.primary)
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 12)
                        
                        RoundedRectangle(cornerRadius: 6)
                            .fill(piggyBank.color.gradient)
                            .frame(width: geometry.size.width * piggyBank.progress, height: 12)
                            .animation(.spring(response: 1.0, dampingFraction: 0.8), value: piggyBank.progress)
                    }
                }
                .frame(height: 12)
                
                if piggyBank.lockType == .timeLock, let remaining = piggyBank.remainingTime {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(.white.opacity(0.5))
                        Text("piggy.detail.time_remaining".localized)
                            .font(PiggyTheme.Typography.caption)
                            .foregroundColor(.white.opacity(0.5))
                        Spacer()
                        Text(remaining)
                            .font(PiggyTheme.Typography.captionBold)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                
                if piggyBank.lockType == .targetLock, let target = piggyBank.targetAmount {
                    HStack {
                        Image(systemName: "target")
                            .foregroundColor(.white.opacity(0.5))
                        Text("piggy.detail.target".localized)
                            .font(PiggyTheme.Typography.caption)
                            .foregroundColor(.white.opacity(0.5))
                        Spacer()
                        Text("\(String(format: "%.2f", target)) \(piggyBank.asset.symbol)")
                            .font(PiggyTheme.Typography.captionBold)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 20)
    }
    
    // MARK: - Details Section
    private var detailsSection: some View {
        GlassCard(padding: 20) {
            VStack(spacing: 14) {
                Text("piggy.detail.info".localized)
                    .font(PiggyTheme.Typography.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Divider().background(Color.white.opacity(0.1))
                
                DetailRow(
                    icon: "calendar",
                    label: "piggy.detail.created".localized,
                    value: piggyBank.createdAt.formatted(date: .abbreviated, time: .omitted)
                )
                
                DetailRow(
                    icon: piggyBank.lockType.icon,
                    label: "piggy.detail.lock_type".localized,
                    value: piggyBank.lockType.displayName
                )
                
                DetailRow(
                    icon: "link",
                    label: "piggy.detail.contract".localized,
                    value: String(piggyBank.contractAddress.prefix(10)) + "..." + String(piggyBank.contractAddress.suffix(4))
                )
                
                DetailRow(
                    icon: "network",
                    label: "piggy.detail.network".localized,
                    value: "Base (L2)"
                )
            }
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 20)
    }
    
    // MARK: - Actions
    private var actionsSection: some View {
        VStack(spacing: 12) {
            if !appState.isSafeDeployed {
                SafeDeploymentWarningBanner(
                    error: appState.safeDeploymentError,
                    isRetrying: appState.isDeployingRetry,
                    retryAction: { appState.retrySafeDeployment() }
                )
            }
            
            GlassButton(
                title: "piggy.detail.deposit".localized,
                icon: "arrow.down.circle.fill",
                gradient: LinearGradient(colors: [PiggyTheme.Colors.accentGreen, Color(hex: "00C853")], startPoint: .leading, endPoint: .trailing)
            ) {
                HapticManager.mediumTap()
                showDepositSheet = true
            }
            .disabled(!appState.isSafeDeployed)
            .opacity(appState.isSafeDeployed ? 1.0 : 0.4)
            
            if piggyBank.isUnlockable {
                GlassButton(
                    title: "piggy.detail.unlock".localized,
                    icon: "lock.open.fill",
                    gradient: PiggyTheme.Colors.primaryGradient
                ) {
                    HapticManager.warning()
                    showUnlockConfirm = true
                }
            }
        }
        .opacity(showContent ? 1 : 0)
    }
    
    // MARK: - Deposit Sheet
    private var depositSheet: some View {
        NavigationStack {
            ZStack {
                PiggyTheme.Colors.background
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Piggy bank icon
                    ZStack {
                        Circle()
                            .fill(piggyBank.color.gradient.opacity(0.15))
                            .frame(width: 64, height: 64)
                        
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(piggyBank.color.gradient)
                    }
                    .padding(.top, 12)
                    
                    VStack(spacing: 8) {
                        Text("piggy.detail.deposit_amount".localized)
                            .font(PiggyTheme.Typography.subheadline)
                            .foregroundColor(.white.opacity(0.6))
                        
                        HStack(alignment: .bottom, spacing: 8) {
                            TextField("0.00", text: $depositAmount)
                                .font(PiggyTheme.Typography.balanceLarge)
                                .foregroundColor(.white)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.center)
                            
                            Text(piggyBank.asset.symbol)
                                .font(PiggyTheme.Typography.title2)
                                .foregroundColor(piggyBank.asset.color)
                                .padding(.bottom, 6)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    
                    // Quick amount presets
                    HStack(spacing: 10) {
                        ForEach([10.0, 25.0, 50.0, 100.0], id: \.self) { amount in
                            Button {
                                HapticManager.selection()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    depositAmount = String(format: "%.0f", amount)
                                }
                            } label: {
                                Text("$\(Int(amount))")
                                    .font(PiggyTheme.Typography.captionBold)
                                    .foregroundColor(depositAmount == String(format: "%.0f", amount) ? .white : .white.opacity(0.6))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(
                                        Capsule()
                                            .fill(depositAmount == String(format: "%.0f", amount)
                                                  ? piggyBank.color.primary.opacity(0.3)
                                                  : PiggyTheme.Colors.surface)
                                            .overlay(
                                                Capsule()
                                                    .stroke(depositAmount == String(format: "%.0f", amount)
                                                            ? piggyBank.color.primary.opacity(0.5)
                                                            : Color.white.opacity(0.06), lineWidth: 1)
                                            )
                                    )
                            }
                        }
                    }
                    
                    if isDepositing {
                        VStack(spacing: 12) {
                            ProgressRing(
                                progress: depositProgress,
                                size: 60,
                                lineWidth: 6
                            )
                            Text("piggy.detail.depositing".localized)
                                .font(PiggyTheme.Typography.caption)
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .transition(.scale.combined(with: .opacity))
                    } else {
                        GlassButton(
                            title: "piggy.detail.confirm_deposit".localized,
                            icon: "faceid"
                        ) {
                            HapticManager.heavyTap()
                            confirmDeposit()
                        }
                        .opacity(depositAmount.isEmpty ? 0.5 : 1.0)
                        .disabled(depositAmount.isEmpty)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
            }
            .navigationTitle("piggy.detail.deposit".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel".localized) {
                        if !isDepositing { showDepositSheet = false }
                    }
                    .foregroundColor(.white.opacity(0.7))
                    .disabled(isDepositing)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled(isDepositing)
    }
    
    // MARK: - Deposit Confirmation
    private func confirmDeposit() {
        guard let amount = Double(depositAmount), amount > 0 else {
            HapticManager.error()
            toast = ToastData(type: .error, message: "piggy.detail.invalid_amount".localized)
            return
        }
        
        // Step 0: Biometric auth via Secure Enclave
        let secureEnclave = SecureEnclaveService()
        do {
            let challenge = "deposit:\(piggyBank.id):\(amount):\(Date().timeIntervalSince1970)"
            _ = try secureEnclave.sign(data: Data(challenge.utf8))
        } catch {
            HapticManager.error()
            toast = ToastData(type: .error, message: "piggy.create.error.biometric_failed".localized)
            return
        }
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isDepositing = true
            depositProgress = 0
        }
        
        executeDeposit(amount: amount)
    }
    
    private func executeDeposit(amount: Double) {
        Task { @MainActor in
            guard let wallet = appState.userWallet else { return }
            let ownerAddress = wallet.address
            let safeAddress = wallet.safeAddress ?? wallet.address
            
            do {
                // Step 1: Build ERC-20 transfer from EOA to Safe
                withAnimation { depositProgress = 0.15 }
                
                let decimals = piggyBank.asset.decimals
                let amountWei = UInt64(amount * pow(10.0, Double(decimals)))
                let transferData = ABIEncoder.functionSelector("transfer(address,uint256)")
                    + ABIEncoder.encodeAddress(safeAddress)
                    + ABIEncoder.encodeUint256(amountWei)
                
                withAnimation { depositProgress = 0.35 }
                let tokenAddress = piggyBank.asset.contractAddress
                
                // Step 2: Sign and send via TransactionSender (Lit PKP)
                withAnimation { depositProgress = 0.6 }
                
                let txHash = try await appState.transactionSender.sendTransaction(
                    from: ownerAddress,
                    to: tokenAddress,
                    data: transferData,
                    value: 0
                )
                
                // Step 3: Wait for confirmation
                withAnimation { depositProgress = 0.85 }
                
                try await BlockchainService().waitForTransactionReceipt(txHash: txHash)
                
                // Step 4: Success
                withAnimation { depositProgress = 1.0 }
                HapticManager.success()
                
                try await Task.sleep(nanoseconds: 400_000_000)
                
                showDepositSheet = false
                isDepositing = false
                depositAmount = ""
                depositProgress = 0
                toast = ToastData(type: .success, message: String(format: "piggy.detail.deposit_success".localized, String(format: "%.2f", amount), piggyBank.asset.symbol))
                
                NotificationService.shared.notifyTransactionConfirmed(
                    type: .deposit,
                    asset: piggyBank.asset.symbol,
                    amount: String(format: "%.2f", amount)
                )
                
                await appState.refreshData()
                
            } catch {
                HapticManager.error()
                withAnimation {
                    isDepositing = false
                    depositProgress = 0
                }
                toast = ToastData(type: .error, message: error.localizedDescription)
                NotificationService.shared.notifyTransactionFailed(type: .deposit, asset: piggyBank.asset.symbol)
            }
        }
    }
    
    // MARK: - Unlock via Smart Contract
    private func executeUnlock() {
        Task { @MainActor in
            let secureEnclave = SecureEnclaveService()
            
            // Biometric auth
            do {
                let challenge = "unlock:\(piggyBank.id):\(Date().timeIntervalSince1970)"
                _ = try secureEnclave.sign(data: Data(challenge.utf8))
            } catch {
                toast = ToastData(type: .error, message: "piggy.create.error.biometric_failed".localized)
                return
            }
            
            guard let wallet = appState.userWallet else { return }
            let ownerAddress = wallet.address
            let safeAddress = wallet.safeAddress ?? wallet.address
            
            do {
                try await appState.safeService.disableModule(
                    ownerAddress: ownerAddress,
                    safeAddress: safeAddress,
                    moduleAddress: piggyBank.contractAddress
                )
                
                HapticManager.success()
                toast = ToastData(type: .success, message: "piggy.detail.unlock_success".localized)
                
                NotificationService.shared.notifyPiggyBankUnlocked(name: piggyBank.name)
                NotificationService.shared.cancelUnlockReminder(moduleAddress: piggyBank.contractAddress)
                
                await appState.refreshData()
                
            } catch {
                HapticManager.error()
                toast = ToastData(type: .error, message: error.localizedDescription)
                NotificationService.shared.notifyTransactionFailed(type: .unlock, asset: piggyBank.asset.symbol)
            }
        }
    }
}

struct DetailRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.4))
                .frame(width: 20)
            
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
