import SwiftUI
import Combine
import LocalAuthentication

enum AppScreen {
    case splash
    case onboarding
    case auth
    case creatingWallet
    case dashboard
}

@MainActor
final class AppState: ObservableObject {
    @Published var currentScreen: AppScreen = .splash
    @Published var isAuthenticated: Bool = false
    @Published var userWallet: UserWallet?
    @Published var piggyBanks: [PiggyBank] = []
    @Published var totalBalance: [AssetBalance] = []
    @Published var recentTransactions: [Transaction] = []
    @Published var isLoading: Bool = false
    @Published var loadingMessage: String = ""
    @Published var loadingProgress: Double = 0.0
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""
    @Published var isLocked: Bool = false
    @Published var safeDeploymentFailed: Bool = false
    @Published var safeDeploymentError: String = ""
    @Published var isDeployingRetry: Bool = false
    
    /// True ONLY if the Safe is confirmed deployed on-chain (safeAddress set after verification)
    var isSafeDeployed: Bool {
        guard let sa = userWallet?.safeAddress, !sa.isEmpty else { return false }
        return !safeDeploymentFailed
    }
    
    private let keychainService = KeychainService()
    private let biometricService = BiometricService()
    private let blockchainService = BlockchainService()
    private let cacheService = WalletCacheService.shared
    let litSigningBridge = LitSigningBridge()
    private(set) lazy var transactionSender: LitTransactionSender = LitTransactionSender(
        blockchainService: blockchainService,
        litBridge: litSigningBridge
    )
    private(set) lazy var safeService: SafeService = SafeService(
        blockchainService: blockchainService,
        transactionSender: transactionSender
    )
    private let secureEnclaveService = SecureEnclaveService()
    private let gasManager: GasManager
    
    init() {
        self.gasManager = GasManager(blockchainService: blockchainService)
        Task { [gasManager, transactionSender] in
            await gasManager.setTransactionSender(transactionSender)
        }
        checkExistingSession()
    }
    
    func checkExistingSession() {
        Task {
            currentScreen = .splash
            
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            
            if let storedAddress = keychainService.getWalletAddress() {
                userWallet = UserWallet(
                    address: storedAddress,
                    authMethod: keychainService.getAuthMethod() ?? .apple
                )
                
                // Try biometric/passcode unlock if enabled
                let biometricEnabled = UserDefaults.standard.bool(forKey: "biometricLockEnabled")
                var authenticated = false
                
                if biometricEnabled {
                    let canUseBiometrics = await biometricService.canEvaluatePolicy()
                    if canUseBiometrics {
                        authenticated = await biometricService.authenticate(
                            reason: "auth.biometric.reason".localized
                        )
                    } else {
                        // Biometric lock enabled but device can't use biometrics
                        // (e.g. fingerprints removed) — fallback to device passcode
                        let context = LAContext()
                        var error: NSError?
                        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
                            authenticated = (try? await context.evaluatePolicy(
                                .deviceOwnerAuthentication,
                                localizedReason: "auth.biometric.reason".localized
                            )) ?? false
                        }
                        // If passcode also unavailable, fall through to auth screen
                    }
                } else {
                    // No biometric lock configured — auto-restore session
                    authenticated = true
                }
                
                if authenticated {
                    isAuthenticated = true
                    loadCachedData()
                    await litSigningBridge.initialize()
                    
                    // Check if Safe needs to be deployed (retrofix for pre-relayer accounts)
                    await ensureSafeDeployed(for: storedAddress)
                    
                    currentScreen = .dashboard
                    await loadDashboardData()
                    return
                }
                
                currentScreen = .auth
            } else {
                let hasSeenOnboarding = UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
                currentScreen = hasSeenOnboarding ? .auth : .onboarding
            }
        }
    }
    
    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            currentScreen = .auth
        }
    }
    
    func signIn(wallet: UserWallet) {
        Task {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                currentScreen = .creatingWallet
                isLoading = true
                loadingMessage = "loading.creating_wallet".localized
                loadingProgress = 0.0
            }
            
            var updatedWallet = wallet
            
            do {
                // Step 1: Store credentials
                loadingProgress = 0.1
                loadingMessage = "loading.creating_wallet".localized
                keychainService.storeWalletAddress(wallet.address)
                keychainService.storeAuthMethod(wallet.authMethod)
                
                // Step 2: Generate Secure Enclave key + initialize Lit signing bridge
                loadingProgress = 0.2
                loadingMessage = "loading.securing_keys".localized
                do {
                    let _ = try secureEnclaveService.generateSigningKey()
                } catch {
                    // SE key generation is for local biometric auth, not critical for Safe deployment
                    print("[SignIn] ⚠️ Secure Enclave key generation failed (non-fatal): \(error.localizedDescription)")
                }
                await litSigningBridge.initialize()
                
                // Step 3: Predict Safe address (deterministic via CREATE2)
                loadingProgress = 0.35
                loadingMessage = "loading.deploying_safe".localized
                let safeAddress = await safeService.predictSafeAddress(owner: wallet.address)
                print("[SignIn] 🔑 Owner: \(wallet.address)")
                print("[SignIn] 🏠 Predicted Safe: \(safeAddress)")
                updatedWallet.safeAddress = safeAddress
                
                // Step 4: Check if Safe is already deployed
                let code = try await blockchainService.getCode(at: safeAddress)
                let isDeployed = code.count > 2 // "0x" means no code
                print("[SignIn] 📋 Safe code length: \(code.count), isDeployed: \(isDeployed)")
                
                if !isDeployed {
                    // Step 5: Deploy Safe via relayer (sponsored)
                    loadingProgress = 0.5
                    loadingMessage = "loading.deploying_safe".localized
                    
                    let deployData = await safeService.buildDeployData(owner: wallet.address)
                    let _ = try await gasManager.sponsorFirstTransaction(
                        safeAddress: safeAddress,
                        deployData: deployData
                    )
                    
                    // Wait for deployment confirmation
                    loadingProgress = 0.65
                    loadingMessage = "loading.confirming_deploy".localized
                    try await waitForDeployment(address: safeAddress)
                    
                    // Verify deployment actually succeeded on-chain
                    let verifyCode = try await blockchainService.getCode(at: safeAddress)
                    guard verifyCode.count > 2 else {
                        throw GasError.relayerRejected("Safe deployment tx sent but not confirmed on-chain")
                    }
                    print("[SafeDeploy] ✅ Safe deployed and verified at \(safeAddress)")
                } else {
                    loadingProgress = 0.65
                    print("[SafeDeploy] ✅ Safe already deployed at \(safeAddress)")
                }
                
                // Step 6: Cache Safe address in both UserDefaults and Keychain + notify
                loadingProgress = 0.8
                loadingMessage = "loading.configuring_modules".localized
                cacheService.cacheSafeAddress(safeAddress)
                keychainService.storeSafeAddress(safeAddress)
                NotificationService.shared.notifyTransactionConfirmed(type: .safeDeployed, asset: "Safe", amount: nil)
                
                // Step 7: Finalize
                loadingProgress = 0.95
                loadingMessage = "loading.finalizing".localized
                try? await Task.sleep(nanoseconds: 300_000_000)
                
                loadingProgress = 1.0
                userWallet = updatedWallet
                isAuthenticated = true
                
                try? await Task.sleep(nanoseconds: 300_000_000)
                
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    currentScreen = .dashboard
                    isLoading = false
                }
                
                await loadDashboardData()
                
            } catch {
                // Safe deployment FAILED — do NOT set safeAddress, block all money ops
                loadingProgress = 1.0
                updatedWallet.safeAddress = nil
                userWallet = updatedWallet
                isAuthenticated = true
                safeDeploymentFailed = true
                safeDeploymentError = error.localizedDescription
                cacheService.clearSafeAddress()
                
                print("[SafeDeploy] ❌ Deploy failed at sign-in: \(error.localizedDescription)")
                
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    currentScreen = .dashboard
                    isLoading = false
                }
            }
        }
    }
    
    /// Retrofix: for accounts created before the relayer was implemented,
    /// checks if the Safe exists on-chain and deploys it via relayer if not.
    /// On failure: does NOT set safeAddress, sets safeDeploymentFailed + error.
    private func ensureSafeDeployed(for ownerAddress: String) async {
        // 1. Predict Safe address
        let safeAddress = await safeService.predictSafeAddress(owner: ownerAddress)
        
        // 2. Check if already deployed on-chain
        do {
            let code = try await blockchainService.getCode(at: safeAddress)
            if code.count > 2 {
                // Already deployed — safe to set address
                print("[SafeRetrofix] ✅ Safe already deployed at \(safeAddress)")
                userWallet?.safeAddress = safeAddress
                cacheService.cacheSafeAddress(safeAddress)
                keychainService.storeSafeAddress(safeAddress)
                safeDeploymentFailed = false
                safeDeploymentError = ""
                return
            }
        } catch {
            print("[SafeRetrofix] ⚠️ Could not check Safe code: \(error.localizedDescription)")
            safeDeploymentFailed = true
            safeDeploymentError = error.localizedDescription
            userWallet?.safeAddress = nil
            cacheService.clearSafeAddress()
            return
        }
        
        // 3. Not deployed — deploy via relayer
        print("[SafeRetrofix] 🔧 Safe not deployed, deploying via relayer...")
        
        do {
            let deployData = await safeService.buildDeployData(owner: ownerAddress)
            let txHash = try await gasManager.sponsorFirstTransaction(
                safeAddress: safeAddress,
                deployData: deployData
            )
            print("[SafeRetrofix] 📤 Deploy tx sent: \(txHash)")
            
            // Wait for confirmation (up to 40s)
            try await waitForDeployment(address: safeAddress)
            
            // Verify it's actually deployed
            let code = try await blockchainService.getCode(at: safeAddress)
            guard code.count > 2 else {
                throw GasError.relayerRejected("Safe deployment not confirmed on-chain")
            }
            
            // SUCCESS — now safe to set the address
            userWallet?.safeAddress = safeAddress
            cacheService.cacheSafeAddress(safeAddress)
            keychainService.storeSafeAddress(safeAddress)
            safeDeploymentFailed = false
            safeDeploymentError = ""
            print("[SafeRetrofix] ✅ Safe deployed at \(safeAddress)")
            
            NotificationService.shared.notifyTransactionConfirmed(
                type: .safeDeployed, asset: "Safe", amount: nil
            )
        } catch {
            // FAILED — do NOT set safeAddress, block everything
            print("[SafeRetrofix] ❌ Deploy failed: \(error.localizedDescription)")
            safeDeploymentFailed = true
            safeDeploymentError = error.localizedDescription
            userWallet?.safeAddress = nil
            cacheService.clearSafeAddress()
        }
    }
    
    /// User taps "Retry" — attempt Safe deployment again
    func retrySafeDeployment() {
        guard let ownerAddress = userWallet?.address else { return }
        Task {
            isDeployingRetry = true
            await ensureSafeDeployed(for: ownerAddress)
            isDeployingRetry = false
            
            // If succeeded, load dashboard data
            if isSafeDeployed {
                await loadDashboardData()
            }
        }
    }
    
    private func waitForDeployment(address: String, maxAttempts: Int = 30) async throws {
        for attempt in 0..<maxAttempts {
            try await Task.sleep(nanoseconds: 2_000_000_000)
            do {
                let code = try await blockchainService.getCode(at: address)
                if code.count > 2 {
                    print("[SafeDeploy] ✅ Deployment confirmed at attempt \(attempt + 1)")
                    return
                }
            } catch {
                print("[SafeDeploy] ⚠️ getCode attempt \(attempt + 1) failed: \(error.localizedDescription)")
                // Continue polling — transient RPC errors should not abort
            }
        }
        throw GasError.relayerRejected("Safe deployment not confirmed on-chain after \(maxAttempts * 2)s")
    }
    
    func lockApp() {
        let biometricEnabled = UserDefaults.standard.bool(forKey: "biometricLockEnabled")
        guard biometricEnabled, isAuthenticated, currentScreen == .dashboard else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            isLocked = true
        }
    }
    
    func unlockApp() {
        Task {
            let authenticated = await biometricService.authenticate(
                reason: "auth.biometric.reason".localized
            )
            if authenticated {
                HapticManager.success()
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                    isLocked = false
                }
            }
        }
    }
    
    func signOut() {
        // Clear session state AND active PKP/Safe so a different account doesn't
        // inherit the previous account's wallet. The pkpMap is KEPT because it's
        // correctly keyed by authMethodId — Layer 1a will find the right PKP
        // when the SAME account re-logs in.
        NSLog("%@", "[SignOut] ═══════════════════════════════════════")
        NSLog("%@", "[SignOut] Clearing active PKP: \(keychainService.retrieve(for: .pkpPublicKey)?.prefix(40).description ?? "nil")")
        NSLog("%@", "[SignOut] Clearing safeAddress: \(keychainService.getSafeAddress() ?? "nil")")
        NSLog("%@", "[SignOut] Clearing litAuthSig")
        NSLog("%@", "[SignOut] KEEPING pkpMap: \(keychainService.retrieve(for: .pkpMap)?.prefix(60).description ?? "nil")")
        keychainService.deleteWalletAddress()
        keychainService.deleteAuthMethod()
        keychainService.delete(for: .pkpPublicKey)
        keychainService.delete(for: .litAuthSig)
        keychainService.delete(for: .safeAddress)
        // NOTE: pkpMap is PRESERVED — it maps authMethodId→PKP per account
        NSLog("%@", "[SignOut] After clear — pkpPublicKey: \(keychainService.retrieve(for: .pkpPublicKey) != nil)")
        NSLog("%@", "[SignOut] After clear — pkpMap still: \(keychainService.retrieve(for: .pkpMap) != nil)")
        cacheService.clearAll()
        userWallet = nil
        isAuthenticated = false
        safeDeploymentFailed = false
        safeDeploymentError = ""
        piggyBanks = []
        totalBalance = []
        recentTransactions = []
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            currentScreen = .auth
        }
    }
    
    func loadCachedData() {
        if let cached = cacheService.loadCachedBalances() {
            let balances = cached.compactMap { $0.toAssetBalance() }
            if !balances.isEmpty { totalBalance = balances }
        }
        if let cached = cacheService.loadCachedPiggyBanks() {
            let piggies = cached.compactMap { $0.toPiggyBank() }
            if !piggies.isEmpty { piggyBanks = piggies }
        }
        if let cached = cacheService.loadCachedTransactions() {
            let txns = cached.compactMap { $0.toTransaction() }
            if !txns.isEmpty { recentTransactions = txns }
        }
        // Recover safe address: try UserDefaults first, then keychain
        if let safeAddr = cacheService.loadCachedSafeAddress() ?? keychainService.getSafeAddress() {
            userWallet?.safeAddress = safeAddr
        }
    }
    
    func loadDashboardData() async {
        guard let wallet = userWallet else { return }
        
        do {
            // Always query the Safe address for balances — owner address holds no funds
            guard let safeAddress = wallet.safeAddress else {
                print("[Dashboard] ⚠️ No Safe address set, skipping balance fetch")
                return
            }
            
            let balances = try await blockchainService.fetchBalances(for: safeAddress)
            withAnimation(.easeInOut(duration: 0.3)) {
                totalBalance = balances
            }
            cacheService.cacheBalances(balances.map { CachedBalance(from: $0) })
            
            let piggies = try await blockchainService.fetchPiggyBanks(for: safeAddress)
            withAnimation(.easeInOut(duration: 0.3)) {
                piggyBanks = piggies
            }
            cacheService.cachePiggyBanks(piggies.map { CachedPiggyBank(from: $0) })
            
            if let safe = wallet.safeAddress {
                cacheService.cacheSafeAddress(safe)
                
                // Auto-swap: if Safe has stablecoin but low ETH, swap some for gas
                await checkAndAutoSwapForGas(
                    ownerAddress: wallet.address,
                    safeAddress: safe,
                    balances: balances
                )
            }
        } catch {
            if totalBalance.isEmpty {
                showError = true
                errorMessage = error.localizedDescription
            }
        }
    }
    
    /// Silently checks if the owner needs ETH for gas.
    /// Step 1: If owner has 0 ETH, request a gas stipend from the relayer.
    /// Step 2: Auto-swap stablecoin → ETH if owner ETH < $0.50 (target $1.50).
    private func checkAndAutoSwapForGas(
        ownerAddress: String,
        safeAddress: String,
        balances: [AssetBalance]
    ) async {
        // Need at least $1.60 stablecoin to swap (target $1.50 + slippage)
        let usdcBalance = balances.first(where: { $0.asset == .usdc })?.balance ?? 0
        let eurcBalance = balances.first(where: { $0.asset == .eurc })?.balance ?? 0
        let hasStablecoin = usdcBalance >= 1.60 || eurcBalance >= 1.60
        
        NSLog("%@", "[GasBootstrap] USDC: \(usdcBalance), EURC: \(eurcBalance), hasStablecoin: \(hasStablecoin)")
        guard hasStablecoin else {
            NSLog("%@", "[GasBootstrap] Not enough stablecoin for auto-swap (need >= $1.60)")
            return
        }
        
        // Step 1: Check owner's ETH balance — if near 0, request gas stipend from relayer
        // The stipend gives owner enough ETH to send at least 1 transaction (the swap)
        let ownerETH = (try? await gasManager.checkGasBalance(address: ownerAddress)) ?? 0
        NSLog("%@", "[GasBootstrap] Owner ETH: \(ownerETH), owner: \(ownerAddress)")
        
        if ownerETH < 0.00005 {
            NSLog("%@", "[GasBootstrap] Owner has ~0 ETH — requesting gas stipend from relayer...")
            do {
                let _ = try await gasManager.requestGasStipend(
                    ownerAddress: ownerAddress,
                    safeAddress: safeAddress
                )
                NSLog("%@", "[GasBootstrap] ✅ Gas stipend requested, waiting for arrival...")
                // Wait for the stipend tx to confirm on Base (~2s block time)
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                
                // Verify stipend arrived
                let newETH = (try? await gasManager.checkGasBalance(address: ownerAddress)) ?? 0
                NSLog("%@", "[GasBootstrap] Owner ETH after stipend: \(newETH)")
                if newETH < 0.00002 {
                    NSLog("%@", "[GasBootstrap] ⚠️ Stipend not yet arrived, skipping auto-swap")
                    return
                }
            } catch {
                NSLog("%@", "[GasBootstrap] ⚠️ Gas stipend failed: \(error.localizedDescription)")
                return
            }
        }
        
        // Step 2: Auto-swap stablecoin → ETH (sends ETH to owner, not Safe)
        let preferredAsset: AssetType = usdcBalance >= 1.60 ? .usdc : .eurc
        NSLog("%@", "[GasBootstrap] Starting auto-swap: \(preferredAsset.symbol) → ETH for owner")
        
        do {
            let txHash = try await gasManager.autoSwapForGas(
                ownerAddress: ownerAddress,
                safeAddress: safeAddress,
                asset: preferredAsset
            )
            if let hash = txHash {
                NSLog("%@", "[GasBootstrap] ✅ Auto-swap tx sent: \(hash)")
            } else {
                NSLog("%@", "[GasBootstrap] ℹ️ No swap needed — owner ETH sufficient")
            }
        } catch {
            NSLog("%@", "[GasBootstrap] ❌ Auto-swap failed: \(error.localizedDescription)")
        }
    }
    
    func refreshData() async {
        await loadDashboardData()
    }
}
