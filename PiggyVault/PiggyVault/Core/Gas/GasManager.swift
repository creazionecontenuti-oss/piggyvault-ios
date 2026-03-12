import Foundation

enum GasError: LocalizedError {
    case insufficientGas
    case swapFailed(String)
    case relayerUnavailable
    case relayerRejected(String)
    case quoteFailed
    
    var errorDescription: String? {
        switch self {
        case .insufficientGas: return "error.gas.insufficient".localized
        case .swapFailed(let msg): return String(format: "error.gas.swap_failed".localized, msg)
        case .relayerUnavailable: return "error.gas.relayer_unavailable".localized
        case .relayerRejected(let msg): return String(format: "error.gas.relayer_rejected".localized, msg)
        case .quoteFailed: return "error.gas.quote_failed".localized
        }
    }
}

struct GasStatus {
    let ethBalance: Double
    let needsRefill: Bool
    let estimatedTxsRemaining: Int
    let ethPriceUSD: Double
}

actor GasManager {
    private let blockchainService: BlockchainService
    private var transactionSender: TransactionSender?
    
    // Thresholds (USD-based, converted to ETH at runtime)
    private let minGasBalanceUSD: Double = 0.50  // Trigger auto-swap when owner ETH < $0.50
    private let autoSwapTargetUSD: Double = 1.50  // Swap enough USDC to give owner ~$1.50 of ETH
    private let avgTxCostETH: Double = 0.00006 // Average Base L2 tx cost
    
    // Relayer endpoint for sponsored transactions (Safe deployment)
    private let relayerURL = "https://zhkaswhxscxbxwdevaos.supabase.co/functions/v1/relay"
    
    // Uniswap V3 SwapRouter02 on Base
    private let uniswapRouter = "0x2626664c2603336E57B271c5C0b26F421741e481"
    // WETH on Base
    private let wethAddress = "0x4200000000000000000000000000000000000006"
    // Uniswap pool fee tier (0.05% for stablecoin/ETH)
    private let poolFee: UInt64 = 500
    
    // Cached ETH price
    private var cachedETHPrice: Double?
    private var priceTimestamp: Date?
    private let priceCacheDuration: TimeInterval = 300 // 5 min
    
    init(blockchainService: BlockchainService = BlockchainService()) {
        self.blockchainService = blockchainService
    }
    
    func setTransactionSender(_ sender: TransactionSender) {
        self.transactionSender = sender
    }
    
    // MARK: - Gas Status
    
    func checkGasBalance(address: String) async throws -> Double {
        return try await blockchainService.getETHBalance(address: address)
    }
    
    func getGasStatus(address: String) async -> GasStatus {
        do {
            let balance = try await checkGasBalance(address: address)
            let ethPrice = try await getETHPrice()
            let txsRemaining = Int(balance / avgTxCostETH)
            
            return GasStatus(
                ethBalance: balance,
                needsRefill: balance < (minGasBalanceUSD / ethPrice),
                estimatedTxsRemaining: txsRemaining,
                ethPriceUSD: ethPrice
            )
        } catch {
            return GasStatus(
                ethBalance: 0,
                needsRefill: true,
                estimatedTxsRemaining: 0,
                ethPriceUSD: 2500
            )
        }
    }
    
    func needsGasRefill(address: String) async -> Bool {
        do {
            let balance = try await checkGasBalance(address: address)
            let ethPrice = try await getETHPrice()
            let minETH = minGasBalanceUSD / ethPrice
            return balance < minETH
        } catch {
            return true
        }
    }
    
    // MARK: - Sponsored Transactions (Relayer)
    
    /// Sponsor the Safe deployment transaction via PiggyVault relayer.
    /// The relayer pays gas for account creation so the user doesn't need ETH upfront.
    func sponsorFirstTransaction(safeAddress: String, deployData: Data) async throws -> String {
        guard let url = URL(string: relayerURL + "/v1/sponsor") else {
            throw GasError.relayerUnavailable
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "chainId": BaseNetwork.chainId,
            "to": BaseNetwork.Contract.safeProxyFactory,
            "data": deployData.hexString,
            "safeAddress": safeAddress,
            "type": "safe_deployment"
        ]
        
        print("[Relayer] 📤 Sponsoring Safe deployment:")
        print("[Relayer]   safeAddress: \(safeAddress)")
        print("[Relayer]   to: \(BaseNetwork.Contract.safeProxyFactory)")
        print("[Relayer]   data length: \(deployData.count) bytes")
        print("[Relayer]   data hex prefix: \(deployData.prefix(20).hexString)")
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("[Relayer] ❌ No HTTP response")
            throw GasError.relayerUnavailable
        }
        
        let responseString = String(data: data, encoding: .utf8) ?? "nil"
        print("[Relayer] 📥 Response \(httpResponse.statusCode): \(responseString)")
        
        guard httpResponse.statusCode == 200 else {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = json["error"] as? String {
                throw GasError.relayerRejected(error)
            }
            throw GasError.relayerRejected("HTTP \(httpResponse.statusCode)")
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let txHash = json["txHash"] as? String else {
            throw GasError.relayerRejected("Invalid response — no txHash")
        }
        
        print("[Relayer] ✅ TX sent: \(txHash)")
        return txHash
    }
    
    /// Sponsor a module installation transaction via relayer
    func sponsorModuleInstall(safeAddress: String, moduleData: Data) async throws -> String {
        guard let url = URL(string: relayerURL + "/v1/sponsor") else {
            throw GasError.relayerUnavailable
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "chainId": BaseNetwork.chainId,
            "to": safeAddress,
            "data": moduleData.hexString,
            "safeAddress": safeAddress,
            "type": "module_install"
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let txHash = json["txHash"] as? String else {
            throw GasError.relayerUnavailable
        }
        
        return txHash
    }
    
    // MARK: - Gas Stipend (Bootstrap)
    
    /// Request a small ETH stipend from the relayer to bootstrap gas for the owner.
    /// The relayer sends ~0.0003 ETH to the owner address so they can submit Safe transactions.
    /// Rate limited to 1 per Safe per 24 hours.
    func requestGasStipend(ownerAddress: String, safeAddress: String) async throws -> String {
        guard let url = URL(string: relayerURL + "/v1/sponsor") else {
            throw GasError.relayerUnavailable
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "chainId": BaseNetwork.chainId,
            "safeAddress": safeAddress,
            "ownerAddress": ownerAddress,
            "type": "gas_stipend"
        ]
        
        print("[GasManager] 📤 Requesting gas stipend for owner: \(ownerAddress)")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GasError.relayerUnavailable
        }
        
        let responseString = String(data: data, encoding: .utf8) ?? "nil"
        print("[GasManager] 📥 Stipend response \(httpResponse.statusCode): \(responseString)")
        
        guard httpResponse.statusCode == 200 else {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = json["error"] as? String {
                throw GasError.relayerRejected(error)
            }
            throw GasError.relayerRejected("HTTP \(httpResponse.statusCode)")
        }
        
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let txHash = json["txHash"] as? String {
            print("[GasManager] ✅ Gas stipend sent: \(txHash)")
            return txHash
        }
        
        // Recipient may already have sufficient gas
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let message = json["message"] as? String {
            print("[GasManager] ℹ️ \(message)")
            return ""
        }
        
        throw GasError.relayerRejected("Invalid stipend response")
    }
    
    // MARK: - Auto-Swap for Gas
    
    /// Automatically swap stablecoin → ETH when the owner's ETH balance is low.
    /// Checks OWNER's ETH (not Safe's) since the owner pays gas for Safe transactions.
    /// Sends ETH to the OWNER via Uniswap V3 SwapRouter02 multicall.
    /// Returns the tx hash of the swap or nil if no swap was needed.
    func autoSwapForGas(ownerAddress: String, safeAddress: String, asset: AssetType) async throws -> String? {
        // Check OWNER's ETH balance — the owner pays gas, not the Safe
        let ownerETH = try await checkGasBalance(address: ownerAddress)
        let ethPrice = try await getETHPrice()
        let minETH = minGasBalanceUSD / ethPrice
        
        NSLog("%@", "[AutoSwap] Owner ETH: \(ownerETH) (min: \(minETH), price: $\(ethPrice))")
        
        // Only swap if owner ETH is below $0.50 threshold
        guard ownerETH < minETH else {
            NSLog("%@", "[AutoSwap] Owner has sufficient ETH, no swap needed")
            return nil
        }
        
        let targetETH = autoSwapTargetUSD / ethPrice
        let ethNeeded = targetETH - ownerETH
        
        // Calculate stablecoin amount needed (add 3% slippage buffer)
        let stablecoinAmount = ethNeeded * ethPrice * 1.03
        let amountIn = UInt64(stablecoinAmount * pow(10.0, Double(asset.decimals)))
        
        // Minimum ETH out (5% slippage tolerance for small amounts on Base)
        let minETHOut = UInt64(ethNeeded * 0.95 * 1e18)
        
        NSLog("%@", "[AutoSwap] Swapping ~$\(String(format: "%.2f", stablecoinAmount)) \(asset.symbol) → ~\(String(format: "%.6f", ethNeeded)) ETH for owner")
        
        // Step 1: Approve Uniswap Router to spend stablecoin (Safe approves)
        let approveData = ABIEncoder.encodeERC20Approve(
            spender: uniswapRouter,
            amount: amountIn
        )
        
        // Step 2: Build Uniswap V3 router.multicall that does:
        //   a) exactInputSingle(USDC → WETH, recipient = router itself)
        //   b) unwrapWETH9(minAmount, ownerAddress) — sends ETH to OWNER
        // Using multicall ensures WETH stays in router between swap and unwrap.
        let swapCalldata = encodeExactInputSingle(
            tokenIn: asset.contractAddress,
            tokenOut: wethAddress,
            fee: poolFee,
            recipient: uniswapRouter, // Send WETH to router for unwrap step
            amountIn: amountIn,
            amountOutMinimum: minETHOut,
            sqrtPriceLimitX96: 0
        )
        let unwrapCalldata = encodeUnwrapWETH9(minAmount: minETHOut, recipient: ownerAddress)
        let multicallData = encodeMulticall(calls: [swapCalldata, unwrapCalldata])
        
        // Execute as a MultiSend batch through the Safe:
        // [approve USDC, router.multicall(swap+unwrap)]
        let multiSendData = encodeMultiSend(transactions: [
            (to: asset.contractAddress, value: 0, data: approveData),
            (to: uniswapRouter, value: 0, data: multicallData)
        ])
        
        // Build Safe execTransaction for the MultiSend
        // Pre-validated signature: r = owner (32 bytes), s = 0 (32 bytes), v = 1
        var ownerSig = ABIEncoder.encodeAddress(ownerAddress)
        ownerSig.append(Data(repeating: 0, count: 32))
        ownerSig.append(Data([0x01]))
        
        let safeTxData = ABIEncoder.encodeSafeExecTransaction(
            to: BaseNetwork.Contract.multiSend,
            value: 0,
            data: multiSendData,
            operation: 1, // DelegateCall for MultiSend
            signatures: ownerSig
        )
        
        guard let sender = transactionSender else {
            throw GasError.swapFailed("TransactionSender not configured")
        }
        return try await sender.sendTransaction(
            from: ownerAddress,
            to: safeAddress,
            data: safeTxData,
            value: 0
        )
    }
    
    /// Swap excess ETH → USDC when owner's ETH exceeds $1.50.
    /// Keeps ~$1.00 of ETH (midpoint of healthy range) and sends USDC to the Safe.
    /// Owner sends native ETH to Uniswap router which wraps → swaps → sends USDC to Safe.
    func autoSwapExcessETH(ownerAddress: String, safeAddress: String) async throws -> String? {
        let ownerETH = try await checkGasBalance(address: ownerAddress)
        let ethPrice = try await getETHPrice()
        let ethValueUSD = ownerETH * ethPrice
        
        guard ethValueUSD > autoSwapTargetUSD else {
            NSLog("%@", "[SwapExcess] ETH=$\(String(format: "%.2f", ethValueUSD)) <= $\(autoSwapTargetUSD), no excess swap needed")
            return nil
        }
        
        // Keep $1.00 worth of ETH (midpoint of $0.50–$1.50 range)
        let keepUSD = 1.00
        let keepETH = keepUSD / ethPrice
        let excessETH = ownerETH - keepETH
        let excessWei = UInt64(excessETH * 1e18)
        
        // Min USDC out (5% slippage for small amounts)
        let expectedUSDC = excessETH * ethPrice * 0.95
        let minUSDCOut = UInt64(expectedUSDC * 1e6) // USDC has 6 decimals
        
        NSLog("%@", "[SwapExcess] Swapping \(String(format: "%.6f", excessETH)) ETH (~$\(String(format: "%.2f", excessETH * ethPrice))) → USDC for Safe")
        
        // Build Uniswap V3 exactInputSingle: WETH → USDC, recipient = Safe
        let swapCalldata = encodeExactInputSingle(
            tokenIn: wethAddress,
            tokenOut: AssetType.usdc.contractAddress,
            fee: poolFee,
            recipient: safeAddress,
            amountIn: excessWei,
            amountOutMinimum: minUSDCOut,
            sqrtPriceLimitX96: 0
        )
        
        // Send tx from owner with value = excessETH, to = Uniswap router
        // The router accepts native ETH and wraps it internally for WETH swaps
        guard let sender = transactionSender else {
            throw GasError.swapFailed("TransactionSender not configured")
        }
        return try await sender.sendTransaction(
            from: ownerAddress,
            to: uniswapRouter,
            data: swapCalldata,
            value: excessWei
        )
    }
    
    // MARK: - Gas Estimation
    
    func estimateGasCost(for transactionType: TransactionType) async throws -> Double {
        let gasPrice = try await blockchainService.getGasPrice()
        let gasPriceETH = Double(gasPrice) / 1e18
        
        let gasUnits: UInt64
        switch transactionType {
        case .deposit:
            gasUnits = 65_000
        case .withdraw:
            gasUnits = 120_000
        case .lock:
            gasUnits = 300_000 // Module deployment + enableModule
        case .unlock:
            gasUnits = 80_000
        }
        
        return Double(gasUnits) * gasPriceETH
    }
    
    /// Estimate gas cost in USD
    func estimateGasCostUSD(for transactionType: TransactionType) async throws -> Double {
        let costETH = try await estimateGasCost(for: transactionType)
        let ethPrice = try await getETHPrice()
        return costETH * ethPrice
    }
    
    // MARK: - ETH Price
    
    func getETHPrice() async throws -> Double {
        // Return cached price if still valid
        if let cached = cachedETHPrice,
           let ts = priceTimestamp,
           Date().timeIntervalSince(ts) < priceCacheDuration {
            return cached
        }
        
        // Fetch from CoinGecko simple price API (no key needed)
        guard let url = URL(string: "https://api.coingecko.com/api/v3/simple/price?ids=ethereum&vs_currencies=usd") else {
            return cachedETHPrice ?? 2500
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let eth = json["ethereum"] as? [String: Any],
               let price = eth["usd"] as? Double {
                cachedETHPrice = price
                priceTimestamp = Date()
                return price
            }
        } catch {
            // Fall back to cached or default
        }
        
        return cachedETHPrice ?? 2500
    }
    
    // MARK: - Uniswap V3 ABI Encoding
    
    /// Encode Uniswap V3 SwapRouter02.exactInputSingle
    private func encodeExactInputSingle(
        tokenIn: String,
        tokenOut: String,
        fee: UInt64,
        recipient: String,
        amountIn: UInt64,
        amountOutMinimum: UInt64,
        sqrtPriceLimitX96: UInt64
    ) -> Data {
        // exactInputSingle((address,address,uint24,address,uint256,uint256,uint160))
        let selector = ABIEncoder.functionSelector(
            "exactInputSingle((address,address,uint24,address,uint256,uint256,uint160))"
        )
        
        // Encode the struct as a tuple
        var params = Data()
        params.append(ABIEncoder.encodeAddress(tokenIn))
        params.append(ABIEncoder.encodeAddress(tokenOut))
        params.append(ABIEncoder.encodeUint256(fee))
        params.append(ABIEncoder.encodeAddress(recipient))
        params.append(ABIEncoder.encodeUint256(amountIn))
        params.append(ABIEncoder.encodeUint256(amountOutMinimum))
        params.append(ABIEncoder.encodeUint256(sqrtPriceLimitX96))
        
        // Offset to the tuple data (32 bytes)
        var encoded = selector
        encoded.append(ABIEncoder.encodeUint256(32)) // offset
        encoded.append(params)
        
        return encoded
    }
    
    /// Encode unwrapWETH9(uint256 amountMinimum, address recipient)
    private func encodeUnwrapWETH9(minAmount: UInt64, recipient: String) -> Data {
        let selector = ABIEncoder.functionSelector("unwrapWETH9(uint256,address)")
        var data = selector
        data.append(ABIEncoder.encodeUint256(minAmount))
        data.append(ABIEncoder.encodeAddress(recipient))
        return data
    }
    
    /// Encode Uniswap V3 SwapRouter02.multicall(bytes[] data)
    /// Bundles multiple router calls (e.g. swap + unwrap) into a single atomic transaction.
    private func encodeMulticall(calls: [Data]) -> Data {
        // multicall(bytes[]) selector = 0xac9650d8
        let selector = ABIEncoder.functionSelector("multicall(bytes[])")
        
        // ABI encode bytes[] dynamic array
        // Layout: offset(32) | array_length(32) | offsets[n] | element_length+data[n]
        var body = Data()
        
        // Array length
        body.append(ABIEncoder.encodeUint256(UInt64(calls.count)))
        
        // Calculate offsets: each offset points from start of array data to the element
        // First element starts after all offset words (calls.count * 32 bytes)
        var currentOffset = calls.count * 32
        for call in calls {
            body.append(ABIEncoder.encodeUint256(UInt64(currentOffset)))
            // Each element is: length(32) + data + padding to 32-byte boundary
            let paddedLen = call.count + (call.count % 32 == 0 ? 0 : 32 - (call.count % 32))
            currentOffset += 32 + paddedLen
        }
        
        // Encode each bytes element: length(32) + data + padding
        for call in calls {
            body.append(ABIEncoder.encodeUint256(UInt64(call.count)))
            body.append(call)
            let remainder = call.count % 32
            if remainder != 0 {
                body.append(Data(repeating: 0, count: 32 - remainder))
            }
        }
        
        // Final: selector + offset_to_array + body
        var encoded = selector
        encoded.append(ABIEncoder.encodeUint256(32)) // offset to bytes[]
        encoded.append(body)
        return encoded
    }
    
    /// Encode a MultiSend batch of transactions
    /// Each tx: operation (1 byte) + to (20 bytes) + value (32 bytes) + dataLength (32 bytes) + data
    private func encodeMultiSend(
        transactions: [(to: String, value: UInt64, data: Data)]
    ) -> Data {
        let selector = ABIEncoder.functionSelector("multiSend(bytes)")
        
        var packed = Data()
        for tx in transactions {
            // operation: 0 = Call
            packed.append(Data([0x00]))
            
            // to: 20 bytes (strip 0x prefix, decode hex, pad)
            let toClean = tx.to.hasPrefix("0x") ? String(tx.to.dropFirst(2)) : tx.to
            if let toBytes = Data(hexString: toClean) {
                if toBytes.count < 20 {
                    packed.append(Data(repeating: 0, count: 20 - toBytes.count))
                }
                packed.append(toBytes.suffix(20))
            }
            
            // value: 32 bytes big-endian
            packed.append(ABIEncoder.encodeUint256(tx.value))
            
            // data length: 32 bytes
            packed.append(ABIEncoder.encodeUint256(UInt64(tx.data.count)))
            
            // data bytes
            packed.append(tx.data)
        }
        
        // Encode as multiSend(bytes)
        // offset to bytes data (32) + length + packed
        var encoded = selector
        encoded.append(ABIEncoder.encodeUint256(32)) // offset
        encoded.append(ABIEncoder.encodeUint256(UInt64(packed.count))) // length
        encoded.append(packed)
        
        // Pad to 32-byte boundary
        let remainder = packed.count % 32
        if remainder != 0 {
            encoded.append(Data(repeating: 0, count: 32 - remainder))
        }
        
        return encoded
    }
}
