import Foundation

enum SafeError: LocalizedError {
    case deploymentFailed(String)
    case moduleInstallFailed
    case invalidOwner
    case transactionFailed(String)
    case notDeployed
    case moduleRestriction(String)
    
    var errorDescription: String? {
        switch self {
        case .deploymentFailed(let msg): return String(format: "error.safe.deployment_failed".localized, msg)
        case .moduleInstallFailed: return "error.safe.module_install_failed".localized
        case .invalidOwner: return "error.safe.invalid_owner".localized
        case .transactionFailed(let msg): return String(format: "error.tx.signing_failed".localized, msg)
        case .notDeployed: return "error.safe.not_deployed".localized
        case .moduleRestriction(let msg): return String(format: "error.safe.module_restriction".localized, msg)
        }
    }
}

actor SafeService {
    private let blockchainService: BlockchainService
    private let transactionSender: TransactionSender
    private let keychainService = KeychainService()
    
    // Safe v1.3.0 proxy creation code (used for CREATE2)
    // This is the bytecode of the SafeProxy that delegates to the singleton
    // Fetched from SafeProxyFactory.proxyCreationCode() on Base mainnet
    private let proxyCreationCode = "608060405234801561001057600080fd5b506040516101e63803806101e68339818101604052602081101561003357600080fd5b8101908080519060200190929190505050600073ffffffffffffffffffffffffffffffffffffffff168173ffffffffffffffffffffffffffffffffffffffff1614156100ca576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825260228152602001806101c46022913960400191505060405180910390fd5b806000806101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff1602179055505060ab806101196000396000f3fe608060405273ffffffffffffffffffffffffffffffffffffffff600054167fa619486e0000000000000000000000000000000000000000000000000000000060003514156050578060005260206000f35b3660008037600080366000845af43d6000803e60008114156070573d6000fd5b3d6000f3fea2646970667358221220d1429297349653a4918076d650332de1a1068c5f3e07c5c82360c277770b955264736f6c63430007060033496e76616c69642073696e676c65746f6e20616464726573732070726f7669646564"
    
    init(blockchainService: BlockchainService = BlockchainService(), transactionSender: TransactionSender) {
        self.blockchainService = blockchainService
        self.transactionSender = transactionSender
    }
    
    // MARK: - Safe Deployment
    
    /// Predicts the Safe address and returns it. The Safe gets deployed when the first transaction is sent.
    func predictSafeAddress(owner: String) -> String {
        let setupData = encodeSetupData(owners: [owner], threshold: 1)
        let saltNonce = generateSaltNonce(owner: owner)
        
        // Compute the initializer hash for CREATE2
        _ = ABIEncoder.encodeCreateProxyWithNonce(
            singleton: BaseNetwork.Contract.safeSingleton,
            initializer: setupData,
            saltNonce: saltNonce
        )
        
        // The salt for CREATE2 is keccak256(keccak256(initializer) + saltNonce)
        let initializerHash = Keccak256.hash(setupData)
        var saltInput = initializerHash
        saltInput.append(ABIEncoder.encodeUint256(saltNonce))
        let salt = Keccak256.hash(saltInput)
        
        // Init code = proxyCreationCode + abi.encode(singleton)
        let singletonEncoded = ABIEncoder.encodeAddress(BaseNetwork.Contract.safeSingleton)
        guard var initCode = Data(hexString: proxyCreationCode) else {
            return EthConstants.zeroAddress
        }
        initCode.append(singletonEncoded)
        let initCodeHash = Keccak256.hash(initCode)
        
        // CREATE2 address prediction
        let predictedAddress = EthAddress.computeCREATE2(
            factory: BaseNetwork.Contract.safeProxyFactory,
            salt: salt,
            initCodeHash: initCodeHash
        )
        
        return EthAddress.checksum(predictedAddress)
    }
    
    /// Deploys the Safe by calling createProxyWithNonce on the factory
    func deploySafe(ownerAddress: String) async throws -> String {
        let setupData = encodeSetupData(owners: [ownerAddress], threshold: 1)
        let saltNonce = generateSaltNonce(owner: ownerAddress)
        
        let deployData = ABIEncoder.encodeCreateProxyWithNonce(
            singleton: BaseNetwork.Contract.safeSingleton,
            initializer: setupData,
            saltNonce: saltNonce
        )
        
        // Send deployment transaction to Safe Proxy Factory
        _ = try await transactionSender.sendTransaction(
            from: ownerAddress,
            to: BaseNetwork.Contract.safeProxyFactory,
            data: deployData,
            value: 0
        )
        
        // The Safe address is deterministic (CREATE2), so we can return it immediately
        let safeAddress = predictSafeAddress(owner: ownerAddress)
        
        // Store Safe address
        keychainService.storeSafeAddress(safeAddress)
        
        return safeAddress
    }
    
    /// Builds enableModule calldata for relayer-sponsored module installation
    func buildEnableModuleData(moduleAddress: String) -> Data {
        return ABIEncoder.functionSelector("enableModule(address)")
            + ABIEncoder.encodeAddress(moduleAddress)
    }
    
    /// Builds the raw deploy calldata for relayer-sponsored deployment
    func buildDeployData(owner: String) -> Data {
        let setupData = encodeSetupData(owners: [owner], threshold: 1)
        let saltNonce = generateSaltNonce(owner: owner)
        return ABIEncoder.encodeCreateProxyWithNonce(
            singleton: BaseNetwork.Contract.safeSingleton,
            initializer: setupData,
            saltNonce: saltNonce
        )
    }
    
    /// Checks if a Safe is already deployed at the predicted address
    func isSafeDeployed(address: String) async throws -> Bool {
        let code = try await blockchainService.getCode(at: address)
        return code != "0x" && code != "0x0" && !code.isEmpty
    }
    
    // MARK: - ERC20 Operations
    
    func deposit(ownerAddress: String, safeAddress: String, asset: AssetType, amount: Double) async throws -> String {
        let amountInSmallestUnit = toSmallestUnit(amount: amount, decimals: asset.decimals)
        let transferData = ABIEncoder.encodeERC20Transfer(to: safeAddress, amount: amountInSmallestUnit)
        
        let txHash = try await transactionSender.sendTransaction(
            from: ownerAddress,
            to: asset.contractAddress,
            data: transferData,
            value: 0
        )
        return txHash
    }
    
    func withdraw(ownerAddress: String, safeAddress: String, asset: AssetType, amount: Double, to: String) async throws -> String {
        let amountInSmallestUnit = toSmallestUnit(amount: amount, decimals: asset.decimals)
        let transferData = ABIEncoder.encodeERC20Transfer(to: to, amount: amountInSmallestUnit)
        
        let safeTxData = ABIEncoder.encodeSafeExecTransaction(
            to: asset.contractAddress,
            value: 0,
            data: transferData,
            operation: 0,
            signatures: generateOwnerSignature(owner: ownerAddress)
        )
        
        return try await transactionSender.sendTransaction(
            from: ownerAddress,
            to: safeAddress,
            data: safeTxData,
            value: 0
        )
    }
    
    // MARK: - Piggy Module Management
    
    func installTimeLockModule(
        ownerAddress: String,
        safeAddress: String,
        unlockTimestamp: UInt64,
        asset: AssetType
    ) async throws -> String {
        let factoryAddress = BaseNetwork.Contract.piggyModuleFactory
        let tokenAddress = asset.contractAddress
        
        var moduleAddress: String
        
        if !factoryAddress.isEmpty {
            // Production: Deploy via factory + parse actual address from event logs
            let createCalldata = ABIEncoder.functionSelector("createTimeLock(address,address,uint256)")
                + ABIEncoder.encodeAddress(safeAddress)
                + ABIEncoder.encodeAddress(tokenAddress)
                + ABIEncoder.encodeUint256(unlockTimestamp)
            
            let txHash = try await transactionSender.sendTransaction(
                from: ownerAddress,
                to: factoryAddress,
                data: createCalldata,
                value: 0
            )
            let receipt = try await blockchainService.getTransactionReceipt(txHash: txHash)
            
            // Parse deployed module address from TimeLockCreated event
            if let addr = blockchainService.parseAddressFromLogs(
                receipt: receipt,
                eventSignature: "TimeLockCreated(address,address,address,uint256)"
            ) {
                moduleAddress = addr
            } else {
                // Fallback to prediction
                let moduleParams = encodeTimeLockParams(safeAddress: safeAddress, unlockTimestamp: unlockTimestamp, tokenAddress: tokenAddress)
                moduleAddress = predictModuleAddress(safeAddress: safeAddress, moduleType: .timeLock, params: moduleParams)
            }
        } else {
            let moduleParams = encodeTimeLockParams(
                safeAddress: safeAddress,
                unlockTimestamp: unlockTimestamp,
                tokenAddress: tokenAddress
            )
            moduleAddress = predictModuleAddress(safeAddress: safeAddress, moduleType: .timeLock, params: moduleParams)
        }
        
        // Enable module on Safe
        try await enableModuleOnSafe(ownerAddress: ownerAddress, safeAddress: safeAddress, moduleAddress: moduleAddress)
        
        // Register module with guard (if guard is deployed)
        await registerModuleWithGuard(ownerAddress: ownerAddress, safeAddress: safeAddress, moduleAddress: moduleAddress)
        
        return moduleAddress
    }
    
    func installTargetLockModule(
        ownerAddress: String,
        safeAddress: String,
        targetAmount: UInt64,
        asset: AssetType
    ) async throws -> String {
        let factoryAddress = BaseNetwork.Contract.piggyModuleFactory
        let tokenAddress = asset.contractAddress
        
        var moduleAddress: String
        
        if !factoryAddress.isEmpty {
            // Production: Deploy via factory + parse actual address from event logs
            let createCalldata = ABIEncoder.functionSelector("createTargetLock(address,address,uint256)")
                + ABIEncoder.encodeAddress(safeAddress)
                + ABIEncoder.encodeAddress(tokenAddress)
                + ABIEncoder.encodeUint256(targetAmount)
            
            let txHash = try await transactionSender.sendTransaction(
                from: ownerAddress,
                to: factoryAddress,
                data: createCalldata,
                value: 0
            )
            let receipt = try await blockchainService.getTransactionReceipt(txHash: txHash)
            
            // Parse deployed module address from TargetLockCreated event
            if let addr = blockchainService.parseAddressFromLogs(
                receipt: receipt,
                eventSignature: "TargetLockCreated(address,address,address,uint256)"
            ) {
                moduleAddress = addr
            } else {
                // Fallback to prediction
                let moduleParams = encodeTargetLockParams(safeAddress: safeAddress, targetAmount: targetAmount, tokenAddress: tokenAddress)
                moduleAddress = predictModuleAddress(safeAddress: safeAddress, moduleType: .targetLock, params: moduleParams)
            }
        } else {
            let moduleParams = encodeTargetLockParams(
                safeAddress: safeAddress,
                targetAmount: targetAmount,
                tokenAddress: tokenAddress
            )
            moduleAddress = predictModuleAddress(safeAddress: safeAddress, moduleType: .targetLock, params: moduleParams)
        }
        
        // Enable module on Safe
        try await enableModuleOnSafe(ownerAddress: ownerAddress, safeAddress: safeAddress, moduleAddress: moduleAddress)
        
        // Register module with guard
        await registerModuleWithGuard(ownerAddress: ownerAddress, safeAddress: safeAddress, moduleAddress: moduleAddress)
        
        return moduleAddress
    }
    
    // MARK: - Module Helpers
    
    private func enableModuleOnSafe(ownerAddress: String, safeAddress: String, moduleAddress: String) async throws {
        let enableModuleData = ABIEncoder.functionSelector("enableModule(address)")
            + ABIEncoder.encodeAddress(moduleAddress)
        
        let safeTxData = ABIEncoder.encodeSafeExecTransaction(
            to: safeAddress,
            value: 0,
            data: enableModuleData,
            operation: 0,
            signatures: generateOwnerSignature(owner: ownerAddress)
        )
        
        let txHash = try await transactionSender.sendTransaction(
            from: ownerAddress,
            to: safeAddress,
            data: safeTxData,
            value: 0
        )
        try await blockchainService.waitForTransactionReceipt(txHash: txHash)
    }
    
    private func registerModuleWithGuard(ownerAddress: String, safeAddress: String, moduleAddress: String) async {
        let guardAddress = BaseNetwork.Contract.piggyVaultGuard
        guard !guardAddress.isEmpty else { return }
        
        // Ensure the guard is set on the Safe (idempotent — only sets if not already set)
        await ensureGuardSet(ownerAddress: ownerAddress, safeAddress: safeAddress, guardAddress: guardAddress)
        
        // Call guard.registerModule(moduleAddress) via Safe execTransaction
        let registerCalldata = ABIEncoder.functionSelector("registerModule(address)")
            + ABIEncoder.encodeAddress(moduleAddress)
        
        let safeTxData = ABIEncoder.encodeSafeExecTransaction(
            to: guardAddress,
            value: 0,
            data: registerCalldata,
            operation: 0,
            signatures: generateOwnerSignature(owner: ownerAddress)
        )
        
        _ = try? await transactionSender.sendTransaction(
            from: ownerAddress,
            to: safeAddress,
            data: safeTxData,
            value: 0
        )
    }
    
    /// Set the PiggyVaultGuard as the Safe's transaction guard if not already set
    /// Safe stores guard at slot keccak256("guard_manager.guard_address")
    private func ensureGuardSet(ownerAddress: String, safeAddress: String, guardAddress: String) async {
        let guardSlot = "0x8fddaf5b61f947b6325ba5e19ba1d54ee034cdc56b0399a852828ba47aed3c55"
        
        if let currentGuard = try? await blockchainService.getStorageAt(
            address: safeAddress,
            slot: guardSlot
        ) {
            let currentAddr = "0x" + currentGuard.suffix(40)
            if currentAddr.lowercased() == guardAddress.lowercased() {
                return // Guard already set
            }
        }
        
        let setGuardCalldata = ABIEncoder.functionSelector("setGuard(address)")
            + ABIEncoder.encodeAddress(guardAddress)
        
        let safeTxData = ABIEncoder.encodeSafeExecTransaction(
            to: safeAddress,
            value: 0,
            data: setGuardCalldata,
            operation: 0,
            signatures: generateOwnerSignature(owner: ownerAddress)
        )
        
        _ = try? await transactionSender.sendTransaction(
            from: ownerAddress,
            to: safeAddress,
            data: safeTxData,
            value: 0
        )
    }
    
    /// Disable a module on the Safe (for unlocking a piggy bank)
    /// Order: unregister from guard first, then disable on Safe
    func disableModule(ownerAddress: String, safeAddress: String, moduleAddress: String) async throws {
        // Step 1: Unregister from guard (guard allows when isLocked==false)
        let guardAddress = BaseNetwork.Contract.piggyVaultGuard
        if !guardAddress.isEmpty {
            let unregisterCalldata = ABIEncoder.functionSelector("unregisterModule(address)")
                + ABIEncoder.encodeAddress(moduleAddress)
            
            let guardTxData = ABIEncoder.encodeSafeExecTransaction(
                to: guardAddress,
                value: 0,
                data: unregisterCalldata,
                operation: 0,
                signatures: generateOwnerSignature(owner: ownerAddress)
            )
            let unregTx = try await transactionSender.sendTransaction(
                from: ownerAddress,
                to: safeAddress,
                data: guardTxData,
                value: 0
            )
            try await blockchainService.waitForTransactionReceipt(txHash: unregTx)
        }
        
        // Step 2: Disable module on Safe (guard allows since module is unregistered)
        let modules = try await getEnabledModules(safeAddress: safeAddress)
        let prevModule = findPrevModule(module: moduleAddress, modules: modules)
        
        let disableCalldata = ABIEncoder.functionSelector("disableModule(address,address)")
            + ABIEncoder.encodeAddress(prevModule)
            + ABIEncoder.encodeAddress(moduleAddress)
        
        let safeTxData = ABIEncoder.encodeSafeExecTransaction(
            to: safeAddress,
            value: 0,
            data: disableCalldata,
            operation: 0,
            signatures: generateOwnerSignature(owner: ownerAddress)
        )
        
        let txHash = try await transactionSender.sendTransaction(
            from: ownerAddress,
            to: safeAddress,
            data: safeTxData,
            value: 0
        )
        try await blockchainService.waitForTransactionReceipt(txHash: txHash)
    }
    
    /// Find the previous module in the linked list for disableModule
    /// Safe modules form a linked list: SENTINEL -> module1 -> module2 -> ... -> SENTINEL
    private func findPrevModule(module: String, modules: [String]) -> String {
        let sentinel = "0x0000000000000000000000000000000000000001"
        guard let idx = modules.firstIndex(where: { $0.lowercased() == module.lowercased() }) else {
            return sentinel
        }
        return idx == 0 ? sentinel : modules[idx - 1]
    }
    
    /// Returns the list of enabled modules on a Safe
    func getEnabledModules(safeAddress: String) async throws -> [String] {
        try await blockchainService.getEnabledModules(safeAddress: safeAddress)
    }
    
    // MARK: - Private Helpers
    
    private func encodeSetupData(owners: [String], threshold: Int) -> Data {
        ABIEncoder.encodeSafeSetup(
            owners: owners,
            threshold: UInt64(threshold),
            fallbackHandler: BaseNetwork.Contract.safeFallbackHandler
        )
    }
    
    private func generateSaltNonce(owner: String) -> UInt64 {
        // Deterministic salt based on owner address + app identifier
        // This ensures the same owner always gets the same Safe address
        let input = "piggyvault:" + owner.lowercased()
        let hash = Keccak256.hash(Data(input.utf8))
        // Take first 8 bytes as UInt64
        let bytes = Array(hash.prefix(8))
        return bytes.enumerated().reduce(UInt64(0)) { acc, pair in
            acc | (UInt64(pair.element) << (pair.offset * 8))
        }
    }
    
    func generateOwnerSignature(owner: String) -> Data {
        // For a 1-of-1 Safe, we need a signature from the owner
        // EIP-1271 pre-validated signature format:
        // r = owner address padded to 32 bytes
        // s = offset to data (0)
        // v = 1 (pre-validated)
        var sig = ABIEncoder.encodeAddress(owner)
        sig.append(Data(repeating: 0, count: 32)) // s = 0
        sig.append(Data([0x01])) // v = 1
        return sig
    }
    
    private func encodeTimeLockParams(safeAddress: String, unlockTimestamp: UInt64, tokenAddress: String) -> Data {
        ABIEncoder.encodeAddress(safeAddress)
            + ABIEncoder.encodeUint256(unlockTimestamp)
            + ABIEncoder.encodeAddress(tokenAddress)
    }
    
    private func encodeTargetLockParams(safeAddress: String, targetAmount: UInt64, tokenAddress: String) -> Data {
        ABIEncoder.encodeAddress(safeAddress)
            + ABIEncoder.encodeUint256(targetAmount)
            + ABIEncoder.encodeAddress(tokenAddress)
    }
    
    private func predictModuleAddress(safeAddress: String, moduleType: LockType, params: Data) -> String {
        let factoryAddress = BaseNetwork.Contract.piggyModuleFactory
        guard !factoryAddress.isEmpty else {
            // Factory not yet deployed — return deterministic placeholder
            let saltInput = Data(safeAddress.utf8) + Data(moduleType.rawValue.utf8) + params
            let salt = Keccak256.hash(saltInput)
            let hash = Keccak256.hash(salt)
            return "0x" + hash.suffix(20).map { String(format: "%02x", $0) }.joined()
        }
        
        // CREATE2 prediction: keccak256(0xff ++ factory ++ salt ++ keccak256(initCode))
        // salt = keccak256(abi.encodePacked(safe, token, lockType, params))
        let saltInput = ABIEncoder.encodeAddress(safeAddress)
            + params  // params already contain token + type-specific data
        let salt = Keccak256.hash(Data(moduleType.rawValue.utf8) + saltInput)
        
        // The initCode is the contract bytecode + constructor args
        // For now, use the same salt-based deterministic approach
        // Full CREATE2 prediction requires the bytecode which is embedded in the factory
        var create2Input = Data([0xff])
        if let factoryBytes = Data(hexString: factoryAddress.hasPrefix("0x") ? String(factoryAddress.dropFirst(2)) : factoryAddress) {
            create2Input.append(factoryBytes)
        }
        create2Input.append(salt)
        create2Input.append(Keccak256.hash(params))
        
        let hash = Keccak256.hash(create2Input)
        return "0x" + hash.suffix(20).map { String(format: "%02x", $0) }.joined()
    }
    
    private func toSmallestUnit(amount: Double, decimals: Int) -> UInt64 {
        UInt64(amount * pow(10.0, Double(decimals)))
    }
}
