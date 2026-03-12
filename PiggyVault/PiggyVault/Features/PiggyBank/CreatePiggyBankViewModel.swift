import SwiftUI

@MainActor
final class CreatePiggyBankViewModel: ObservableObject {
    @Published var currentStep: Int = 1
    @Published var name: String = ""
    @Published var selectedColor: PiggyBankColor = .purple
    @Published var selectedAsset: AssetType = .usdc
    @Published var selectedLockType: LockType = .timeLock
    @Published var unlockDate: Date = Calendar.current.date(byAdding: .month, value: 6, to: Date()) ?? Date()
    @Published var targetAmountText: String = ""
    @Published var isCreating: Bool = false
    @Published var creationProgress: Double = 0
    @Published var creationMessage: String = ""
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""
    
    private let secureEnclaveService = SecureEnclaveService()
    
    var targetAmount: Double {
        Double(targetAmountText) ?? 0
    }
    
    func createPiggyBank(appState: AppState, onComplete: @escaping () -> Void) {
        Task {
            guard let wallet = appState.userWallet else { return }
            let ownerAddress = wallet.address
            let safeAddress = wallet.safeAddress ?? wallet.address
            
            // Step 1: Biometric authorization via Secure Enclave
            do {
                let challenge = "create_piggy:\(name):\(selectedAsset.symbol):\(Date().timeIntervalSince1970)"
                _ = try secureEnclaveService.sign(data: Data(challenge.utf8))
            } catch {
                showError(message: "piggy.create.error.biometric_failed".localized)
                return
            }
            
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isCreating = true
                creationProgress = 0
                creationMessage = "piggy.create.progress.deploying".localized
            }
            
            do {
                // Step 2: Build module install data
                creationProgress = 0.15
                creationMessage = "piggy.create.progress.deploying".localized
                
                var moduleAddress: String
                
                creationProgress = 0.3
                if selectedLockType == .timeLock {
                    creationMessage = "piggy.create.progress.time_lock".localized
                    let timestamp = UInt64(unlockDate.timeIntervalSince1970)
                    moduleAddress = try await appState.safeService.installTimeLockModule(
                        ownerAddress: ownerAddress,
                        safeAddress: safeAddress,
                        unlockTimestamp: timestamp,
                        asset: selectedAsset
                    )
                } else {
                    creationMessage = "piggy.create.progress.target_lock".localized
                    let amountInWei = UInt64(targetAmount * pow(10.0, Double(selectedAsset.decimals)))
                    moduleAddress = try await appState.safeService.installTargetLockModule(
                        ownerAddress: ownerAddress,
                        safeAddress: safeAddress,
                        targetAmount: amountInWei,
                        asset: selectedAsset
                    )
                }
                
                // Step 3: Module deployed, enabled, and registered by SafeService
                creationProgress = 0.85
                creationMessage = "piggy.create.progress.finalizing".localized
                
                let newPiggy = PiggyBank(
                    id: moduleAddress,
                    name: name,
                    asset: selectedAsset,
                    lockType: selectedLockType,
                    createdAt: Date(),
                    currentAmount: 0,
                    targetAmount: selectedLockType == .targetLock ? targetAmount : nil,
                    unlockDate: selectedLockType == .timeLock ? unlockDate : nil,
                    status: .active,
                    contractAddress: moduleAddress,
                    color: selectedColor
                )
                
                creationProgress = 1.0
                creationMessage = "piggy.create.progress.done".localized
                HapticManager.success()
                
                NotificationService.shared.notifyPiggyBankCreated(name: name)
                if selectedLockType == .timeLock {
                    NotificationService.shared.scheduleUnlockReminder(
                        piggyName: name,
                        unlockDate: unlockDate,
                        moduleAddress: moduleAddress
                    )
                }
                
                try await Task.sleep(nanoseconds: 500_000_000)
                
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    appState.piggyBanks.append(newPiggy)
                    isCreating = false
                }
                
                onComplete()
                
                // Refresh data in background to sync with blockchain
                await appState.refreshData()
                
            } catch {
                HapticManager.error()
                withAnimation {
                    isCreating = false
                }
                showError(message: error.localizedDescription)
            }
        }
    }
    
    private func showError(message: String) {
        errorMessage = message
        showError = true
    }
}
