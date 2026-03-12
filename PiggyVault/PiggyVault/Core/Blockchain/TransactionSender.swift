import Foundation

// MARK: - Transaction Sender Protocol
// Abstract interface for signing and broadcasting Ethereum transactions.
// Implementations provide the actual signing mechanism (Lit PKP, local key, relayer, etc.)

protocol TransactionSender {
    /// Sign and send a raw Ethereum transaction
    /// - Parameters:
    ///   - to: Destination address
    ///   - data: Transaction calldata
    ///   - value: ETH value in wei (default 0)
    ///   - from: Sender address (needed for nonce lookup)
    /// - Returns: Transaction hash
    func sendTransaction(
        from: String,
        to: String,
        data: Data,
        value: UInt64
    ) async throws -> String
}

// MARK: - Lit Protocol Transaction Sender
// Signs transactions via Lit Protocol's PKP threshold signing network
// and broadcasts via Base RPC

actor LitTransactionSender: TransactionSender {
    
    private let blockchainService: BlockchainService
    private let keychainService: KeychainService
    private let litBridge: LitSigningBridge
    
    init(
        blockchainService: BlockchainService = BlockchainService(),
        keychainService: KeychainService = KeychainService(),
        litBridge: LitSigningBridge
    ) {
        self.blockchainService = blockchainService
        self.keychainService = keychainService
        self.litBridge = litBridge
    }
    
    func sendTransaction(
        from: String,
        to: String,
        data: Data,
        value: UInt64 = 0
    ) async throws -> String {
        // 1. Get transaction parameters from the network
        let nonce = try await blockchainService.getNonce(for: from)
        let baseFee = try await blockchainService.getGasPrice()
        let maxPriorityFee: UInt64 = 1_500_000 // 0.0015 gwei — Base L2 is cheap
        let maxFeePerGas = baseFee * 2 + maxPriorityFee
        
        let gasLimit = try await blockchainService.estimateGas(
            to: to,
            data: data.hexString,
            from: from,
            value: "0x" + String(value, radix: 16)
        )
        // Add 20% buffer to gas limit
        let adjustedGasLimit = gasLimit + gasLimit / 5
        
        // 2. Build the unsigned EIP-1559 transaction
        let chainId = UInt64(BaseNetwork.chainId)
        let (unsignedTxHash, _) = RLP.encodeEIP1559ForSigning(
            chainId: chainId,
            nonce: nonce,
            maxPriorityFeePerGas: maxPriorityFee,
            maxFeePerGas: maxFeePerGas,
            gasLimit: adjustedGasLimit,
            to: to,
            value: value,
            data: data
        )
        
        // 3. Sign the transaction hash with Lit PKP
        guard let storedPKP = keychainService.retrieve(for: .pkpPublicKey),
              let authSig = keychainService.retrieve(for: .litAuthSig)
        else {
            throw TransactionSenderError.noPKP
        }
        
        // PKP may be stored as JSON PKPInfo or legacy raw public key
        let pkpPublicKey: String
        if let data = storedPKP.data(using: .utf8),
           let info = try? JSONDecoder().decode(PKPInfo.self, from: data) {
            pkpPublicKey = info.publicKey
        } else {
            pkpPublicKey = storedPKP
        }
        
        let signature = try await litBridge.signTransaction(
            toSign: unsignedTxHash,
            pkpPublicKey: pkpPublicKey,
            authSig: authSig
        )
        
        // 4. Parse signature components
        let rClean = signature.r.hasPrefix("0x") ? String(signature.r.dropFirst(2)) : signature.r
        let sClean = signature.s.hasPrefix("0x") ? String(signature.s.dropFirst(2)) : signature.s
        guard let rData = Data(hexString: "0x" + rClean),
              let sData = Data(hexString: "0x" + sClean)
        else {
            throw TransactionSenderError.invalidSignature
        }
        
        // 5. Build the signed transaction
        let signedTx = RLP.encodeSignedEIP1559(
            chainId: chainId,
            nonce: nonce,
            maxPriorityFeePerGas: maxPriorityFee,
            maxFeePerGas: maxFeePerGas,
            gasLimit: adjustedGasLimit,
            to: to,
            value: value,
            data: data,
            v: signature.v,
            r: rData,
            s: sData
        )
        
        // 6. Broadcast
        let txHash = try await blockchainService.sendRawTransaction(signedTx.hexString)
        return txHash
    }
}

// MARK: - Errors

enum TransactionSenderError: LocalizedError {
    case noPKP
    case invalidSignature
    case broadcastFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .noPKP: return "error.tx.no_pkp".localized
        case .invalidSignature: return "error.tx.invalid_signature".localized
        case .broadcastFailed(let msg): return String(format: "error.tx.broadcast_failed".localized, msg)
        }
    }
}
