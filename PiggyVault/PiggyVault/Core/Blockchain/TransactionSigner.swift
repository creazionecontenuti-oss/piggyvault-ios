import Foundation

// MARK: - Transaction Signer
// Orchestrates the two-layer signing architecture:
// 1. Local authorization via Secure Enclave + Biometrics (proves physical presence)
// 2. Blockchain signature via Lit Protocol PKP (threshold signing network)
//
// Flow: User taps "Confirm" → FaceID/TouchID → Secure Enclave signs challenge →
//       Lit PKP signs the actual Ethereum transaction → broadcast to Base network

enum TransactionSignerError: LocalizedError {
    case notInitialized
    case authorizationFailed
    case signingFailed(String)
    case broadcastFailed(String)
    case noPKP
    
    var errorDescription: String? {
        switch self {
        case .notInitialized: return "error.tx.not_initialized".localized
        case .authorizationFailed: return "error.tx.auth_failed".localized
        case .signingFailed(let msg): return String(format: "error.tx.signing_failed".localized, msg)
        case .broadcastFailed(let msg): return String(format: "error.tx.broadcast_failed".localized, msg)
        case .noPKP: return "error.tx.no_pkp".localized
        }
    }
}

struct SignedTransaction {
    let hash: String
    let rawTransaction: String
    let from: String
    let to: String
    let value: String
    let data: String
}

@MainActor
final class TransactionSigner: ObservableObject {
    
    @Published private(set) var isSigning = false
    @Published private(set) var signingStep: SigningStep = .idle
    @Published private(set) var signingProgress: Double = 0
    
    enum SigningStep: String {
        case idle
        case authorizing
        case signing
        case broadcasting
        case confirmed
        case failed
        
        var localizedDescription: String {
            switch self {
            case .idle: return ""
            case .authorizing: return "signing.authorizing".localized
            case .signing: return "signing.signing".localized
            case .broadcasting: return "signing.broadcasting".localized
            case .confirmed: return "signing.confirmed".localized
            case .failed: return "signing.failed".localized
            }
        }
    }
    
    private let secureEnclaveService = SecureEnclaveService()
    private let keychainService = KeychainService()
    private let litSigningBridge: LitSigningBridge
    private let transactionSender: TransactionSender
    
    private var isInitialized = false
    
    init(litSigningBridge: LitSigningBridge, transactionSender: TransactionSender) {
        self.litSigningBridge = litSigningBridge
        self.transactionSender = transactionSender
    }
    
    // MARK: - Initialization
    
    /// Initialize the signer — call once after authentication
    func initialize() async {
        // Ensure Secure Enclave key exists
        if !secureEnclaveService.hasSigningKey() {
            do {
                try secureEnclaveService.generateSigningKey()
            } catch {
                print("[TransactionSigner] Secure Enclave key generation failed: \(error)")
            }
        }
        
        // Initialize Lit signing bridge
        await litSigningBridge.initialize()
        
        isInitialized = true
    }
    
    /// Check if the signer is ready
    var isReady: Bool {
        isInitialized && litSigningBridge.isReady && secureEnclaveService.hasSigningKey()
    }
    
    // MARK: - Sign & Send Transaction
    
    /// Full sign-and-send flow for a Safe transaction
    func signAndSendSafeTransaction(
        ownerAddress: String,
        safeAddress: String,
        to: String,
        value: UInt64 = 0,
        data: Data,
        operation: UInt8 = 0
    ) async throws -> SignedTransaction {
        guard isInitialized else { throw TransactionSignerError.notInitialized }
        
        isSigning = true
        signingProgress = 0
        
        defer {
            if signingStep != .confirmed {
                signingStep = .failed
            }
            isSigning = false
        }
        
        do {
            // Step 1: Local authorization via Secure Enclave
            signingStep = .authorizing
            signingProgress = 0.2
            
            let nonce = try await BlockchainService().getNonce(for: safeAddress)
            
            let authorization = try secureEnclaveService.authorizeTransaction(
                safeAddress: safeAddress,
                to: to,
                value: String(value),
                data: data.hexString,
                nonce: nonce
            )
            
            signingProgress = 0.4
            
            // Step 2: Create the Safe execTransaction calldata
            signingStep = .signing
            
            guard let storedPKP = keychainService.retrieve(for: .pkpPublicKey),
                  let authSig = keychainService.retrieve(for: .litAuthSig)
            else {
                throw TransactionSignerError.noPKP
            }
            
            // PKP may be stored as JSON PKPInfo or legacy raw public key
            let pkpPublicKey: String
            if let jsonData = storedPKP.data(using: .utf8),
               let info = try? JSONDecoder().decode(PKPInfo.self, from: jsonData) {
                pkpPublicKey = info.publicKey
            } else {
                pkpPublicKey = storedPKP
            }
            
            // Build the Safe transaction hash (EIP-712)
            let safeTxHash = buildSafeTransactionHash(
                safe: safeAddress,
                to: to,
                value: value,
                data: data,
                operation: operation,
                nonce: nonce
            )
            
            signingProgress = 0.5
            
            // Sign with Lit PKP
            let litSignature = try await litSigningBridge.signTransaction(
                toSign: safeTxHash,
                pkpPublicKey: pkpPublicKey,
                authSig: authSig
            )
            
            signingProgress = 0.7
            
            // Step 3: Encode and broadcast
            signingStep = .broadcasting
            
            let signatureData = packSignature(litSignature)
            
            let execTxData = ABIEncoder.encodeSafeExecTransaction(
                to: to,
                value: value,
                data: data,
                operation: operation,
                signatures: signatureData
            )
            
            signingProgress = 0.8
            
            let txHash = try await transactionSender.sendTransaction(
                from: ownerAddress,
                to: safeAddress,
                data: execTxData,
                value: 0
            )
            
            signingProgress = 1.0
            signingStep = .confirmed
            
            return SignedTransaction(
                hash: txHash,
                rawTransaction: execTxData.hexString,
                from: safeAddress,
                to: to,
                value: String(value),
                data: data.hexString
            )
            
        } catch {
            signingStep = .failed
            throw error
        }
    }
    
    /// Sign and send a simple ERC20 transfer from the Safe
    func sendERC20(
        ownerAddress: String,
        safeAddress: String,
        tokenAddress: String,
        to: String,
        amount: UInt64
    ) async throws -> SignedTransaction {
        let transferData = ABIEncoder.encodeERC20Transfer(to: to, amount: amount)
        
        return try await signAndSendSafeTransaction(
            ownerAddress: ownerAddress,
            safeAddress: safeAddress,
            to: tokenAddress,
            data: transferData
        )
    }
    
    // MARK: - Cleanup
    
    func tearDown() {
        litSigningBridge.tearDown()
        isInitialized = false
    }
    
    // MARK: - Private Helpers
    
    /// Build the EIP-712 Safe transaction hash
    private func buildSafeTransactionHash(
        safe: String,
        to: String,
        value: UInt64,
        data: Data,
        operation: UInt8,
        nonce: UInt64
    ) -> Data {
        // Domain separator for Safe on Base
        let domainSeparatorTypeHash = Keccak256.hash(Data(
            "EIP712Domain(uint256 chainId,address verifyingContract)".utf8
        ))
        
        var domainInput = domainSeparatorTypeHash
        domainInput.append(ABIEncoder.encodeUint256(UInt64(BaseNetwork.chainId)))
        domainInput.append(ABIEncoder.encodeAddress(safe))
        let domainSeparator = Keccak256.hash(domainInput)
        
        // Safe transaction type hash
        let safeTxTypeHash = Keccak256.hash(Data(
            "SafeTx(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,uint256 nonce)".utf8
        ))
        
        var messageInput = safeTxTypeHash
        messageInput.append(ABIEncoder.encodeAddress(to))
        messageInput.append(ABIEncoder.encodeUint256(value))
        messageInput.append(Keccak256.hash(data)) // keccak256(data)
        messageInput.append(ABIEncoder.encodeUint256(UInt64(operation)))
        messageInput.append(ABIEncoder.encodeUint256(0)) // safeTxGas
        messageInput.append(ABIEncoder.encodeUint256(0)) // baseGas
        messageInput.append(ABIEncoder.encodeUint256(0)) // gasPrice
        messageInput.append(ABIEncoder.encodeAddress(EthConstants.zeroAddress)) // gasToken
        messageInput.append(ABIEncoder.encodeAddress(EthConstants.zeroAddress)) // refundReceiver
        messageInput.append(ABIEncoder.encodeUint256(nonce))
        let messageHash = Keccak256.hash(messageInput)
        
        // EIP-712: \x19\x01 + domainSeparator + messageHash
        var eip712Input = Data([0x19, 0x01])
        eip712Input.append(domainSeparator)
        eip712Input.append(messageHash)
        
        return Keccak256.hash(eip712Input)
    }
    
    /// Pack a Lit signature into the format expected by Safe
    private func packSignature(_ sig: LitSignatureResult) -> Data {
        // Safe expects: r (32 bytes) + s (32 bytes) + v (1 byte)
        var packed = Data()
        
        // Parse r
        let rClean = sig.r.hasPrefix("0x") ? String(sig.r.dropFirst(2)) : sig.r
        if let rData = Data(hexString: rClean) {
            packed.append(rData.leftPadded(to: 32))
        }
        
        // Parse s
        let sClean = sig.s.hasPrefix("0x") ? String(sig.s.dropFirst(2)) : sig.s
        if let sData = Data(hexString: sClean) {
            packed.append(sData.leftPadded(to: 32))
        }
        
        // v byte (Ethereum uses 27/28)
        let v = sig.v < 27 ? sig.v + 27 : sig.v
        packed.append(Data([v]))
        
        return packed
    }
}

// MARK: - Data Helpers

private extension Data {
    func leftPadded(to size: Int) -> Data {
        if count >= size { return self.suffix(size) }
        return Data(repeating: 0, count: size - count) + self
    }
}
