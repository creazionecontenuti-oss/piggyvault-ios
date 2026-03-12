import Foundation

enum BlockchainError: LocalizedError {
    case invalidAddress
    case rpcError(String)
    case contractError(String)
    case insufficientBalance
    case transactionFailed
    case networkUnavailable
    
    var errorDescription: String? {
        switch self {
        case .invalidAddress: return "error.blockchain.invalid_address".localized
        case .rpcError(let msg): return String(format: "error.blockchain.rpc".localized, msg)
        case .contractError(let msg): return String(format: "error.blockchain.contract".localized, msg)
        case .insufficientBalance: return "error.tx.insufficient_balance".localized
        case .transactionFailed: return "error.tx.failed".localized
        case .networkUnavailable: return "error.tx.network_unavailable".localized
        }
    }
}

actor BlockchainService {
    private let rpcURL = BaseNetwork.rpcURL
    private let session: URLSession
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }
    
    func fetchBalances(for address: String) async throws -> [AssetBalance] {
        var balances: [AssetBalance] = []
        
        for asset in AssetType.allCases {
            guard asset.contractAddress != "0x0000000000000000000000000000000000000000" else {
                balances.append(AssetBalance(asset: asset, balance: 0, fiatValue: 0))
                continue
            }
            
            let balance = try await getERC20Balance(
                tokenAddress: asset.contractAddress,
                walletAddress: address,
                decimals: asset.decimals
            )
            
            let fiatValue = await convertToFiat(amount: balance, asset: asset)
            balances.append(AssetBalance(asset: asset, balance: balance, fiatValue: fiatValue))
        }
        
        return balances
    }
    
    func fetchPiggyBanks(for address: String) async throws -> [PiggyBank] {
        // Step 1: Get enabled modules on the Safe (read-only RPC call)
        let moduleAddresses = try await getEnabledModules(safeAddress: address)
        
        guard !moduleAddresses.isEmpty else { return [] }
        
        var piggyBanks: [PiggyBank] = []
        
        // Step 2: For each module, check if it's a PiggyVault lock module
        for moduleAddr in moduleAddresses {
            guard let piggy = await queryPiggyModule(moduleAddress: moduleAddr, safeAddress: address) else {
                continue
            }
            piggyBanks.append(piggy)
        }
        
        return piggyBanks
    }
    
    /// Query a module contract to see if it's a PiggyVault lock module
    private func queryPiggyModule(moduleAddress: String, safeAddress: String) async -> PiggyBank? {
        // Try calling lockType() — only PiggyVault modules implement this
        let lockTypeSelector = ABIEncoder.functionSelectorHex("lockType()")
        
        guard let lockTypeResult = try? await ethCall(to: moduleAddress, data: lockTypeSelector) else {
            return nil
        }
        
        // Decode the returned string
        let lockTypeStr = decodeABIString(from: lockTypeResult)
        guard lockTypeStr == "time_lock" || lockTypeStr == "target_lock" else {
            return nil
        }
        
        let lockType: LockType = lockTypeStr == "time_lock" ? .timeLock : .targetLock
        
        // Query token address
        let tokenSelector = ABIEncoder.functionSelectorHex("token()")
        guard let tokenResult = try? await ethCall(to: moduleAddress, data: tokenSelector) else {
            return nil
        }
        let tokenAddress = decodeABIAddress(from: tokenResult)
        
        // Determine asset from token address
        let asset = AssetType.allCases.first { $0.contractAddress.lowercased() == tokenAddress.lowercased() } ?? .usdc
        
        // Query isLocked
        let isLockedSelector = ABIEncoder.functionSelectorHex("isLocked()")
        let isLockedResult = (try? await ethCall(to: moduleAddress, data: isLockedSelector)) ?? "0x0"
        let isLocked = decodeABIBool(from: isLockedResult)
        
        // Get current balance of the token in the Safe
        let balance = (try? await getERC20Balance(
            tokenAddress: asset.contractAddress,
            walletAddress: safeAddress,
            decimals: asset.decimals
        )) ?? 0
        
        // Type-specific data
        var unlockDate: Date? = nil
        var targetAmount: Double? = nil
        
        if lockType == .timeLock {
            let tsSelector = ABIEncoder.functionSelectorHex("unlockTimestamp()")
            if let tsResult = try? await ethCall(to: moduleAddress, data: tsSelector) {
                let timestamp = decodeABIUint256(from: tsResult)
                if timestamp > 0 {
                    unlockDate = Date(timeIntervalSince1970: TimeInterval(timestamp))
                }
            }
        } else {
            let targetSelector = ABIEncoder.functionSelectorHex("targetAmount()")
            if let targetResult = try? await ethCall(to: moduleAddress, data: targetSelector) {
                let rawTarget = decodeABIUint256(from: targetResult)
                targetAmount = Double(rawTarget) / pow(10.0, Double(asset.decimals))
            }
        }
        
        let status: PiggyBankStatus = isLocked ? .active : .unlocked
        
        // Assign a deterministic color based on module address hash
        let colorIndex = abs(moduleAddress.hashValue) % PiggyBankColor.allCases.count
        let color = PiggyBankColor.allCases[colorIndex]
        
        return PiggyBank(
            id: moduleAddress,
            name: lockType == .timeLock ? "piggy.type.time_vault".localized : "piggy.type.target_vault".localized,
            asset: asset,
            lockType: lockType,
            createdAt: Date(), // On-chain creation time not stored; use now as fallback
            currentAmount: balance,
            targetAmount: targetAmount,
            unlockDate: unlockDate,
            status: status,
            contractAddress: moduleAddress,
            color: color
        )
    }
    
    // MARK: - ABI Decoding Helpers
    
    private func decodeABIString(from hex: String) -> String {
        let clean = hex.hasPrefix("0x") ? String(hex.dropFirst(2)) : hex
        guard clean.count >= 128 else { return "" }
        // offset (32 bytes) + length (32 bytes) + data
        let lengthHex = String(clean[clean.index(clean.startIndex, offsetBy: 64)..<clean.index(clean.startIndex, offsetBy: 128)])
        guard let length = UInt64(lengthHex, radix: 16), length > 0, length < 256 else { return "" }
        let dataStart = clean.index(clean.startIndex, offsetBy: 128)
        let dataEnd = clean.index(dataStart, offsetBy: min(Int(length) * 2, clean.count - 128))
        let dataHex = String(clean[dataStart..<dataEnd])
        guard let data = Data(hexString: dataHex) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    private func decodeABIAddress(from hex: String) -> String {
        let clean = hex.hasPrefix("0x") ? String(hex.dropFirst(2)) : hex
        guard clean.count >= 64 else { return "" }
        // Address is in the last 40 chars of the 64-char word
        let start = clean.index(clean.startIndex, offsetBy: 24)
        let end = clean.index(start, offsetBy: 40)
        return "0x" + String(clean[start..<end])
    }
    
    private func decodeABIBool(from hex: String) -> Bool {
        let clean = hex.hasPrefix("0x") ? String(hex.dropFirst(2)) : hex
        guard let val = UInt64(clean.suffix(2), radix: 16) else { return false }
        return val != 0
    }
    
    private func decodeABIUint256(from hex: String) -> UInt64 {
        let clean = hex.hasPrefix("0x") ? String(hex.dropFirst(2)) : hex
        // Take last 16 hex chars (64 bits) to avoid overflow
        let suffix = String(clean.suffix(16))
        return UInt64(suffix, radix: 16) ?? 0
    }
    
    private func getERC20Balance(tokenAddress: String, walletAddress: String, decimals: Int) async throws -> Double {
        let paddedAddress = walletAddress.replacingOccurrences(of: "0x", with: "").leftPadded(toLength: 64, withPad: "0")
        let data = "0x70a08231" + paddedAddress
        
        let params: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "eth_call",
            "params": [
                ["to": tokenAddress, "data": data],
                "latest"
            ],
            "id": 1
        ]
        
        let result = try await rpcCall(params: params)
        
        guard let hexString = result["result"] as? String else {
            throw BlockchainError.rpcError("Invalid response")
        }
        
        let cleanHex = hexString.replacingOccurrences(of: "0x", with: "")
        guard let bigInt = UInt64(cleanHex, radix: 16) else { return 0 }
        
        return Double(bigInt) / pow(10.0, Double(decimals))
    }
    
    func getETHBalance(address: String) async throws -> Double {
        let params: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "eth_getBalance",
            "params": [address, "latest"],
            "id": 1
        ]
        
        let result = try await rpcCall(params: params)
        guard let hexString = result["result"] as? String else {
            throw BlockchainError.rpcError("Invalid response")
        }
        
        let cleanHex = hexString.replacingOccurrences(of: "0x", with: "")
        guard let bigInt = UInt64(cleanHex, radix: 16) else { return 0 }
        return Double(bigInt) / 1e18
    }
    
    func getCode(at address: String) async throws -> String {
        let params: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "eth_getCode",
            "params": [address, "latest"],
            "id": 1
        ]
        
        let result = try await rpcCall(params: params)
        return result["result"] as? String ?? "0x"
    }
    
    // MARK: - Safe Module Queries
    
    func getEnabledModules(safeAddress: String) async throws -> [String] {
        let calldata = ABIEncoder.functionSelector("getModulesPaginated(address,uint256)")
            + ABIEncoder.encodeAddress("0x0000000000000000000000000000000000000001")
            + ABIEncoder.encodeUint256(10)
        
        let result = try await ethCall(to: safeAddress, data: calldata.hexString)
        return parseModuleAddresses(from: result)
    }
    
    private func parseModuleAddresses(from hexResult: String) -> [String] {
        let clean = hexResult.hasPrefix("0x") ? String(hexResult.dropFirst(2)) : hexResult
        guard clean.count >= 192 else { return [] }
        
        let countHex = String(clean[clean.index(clean.startIndex, offsetBy: 128)..<clean.index(clean.startIndex, offsetBy: 192)])
        guard let count = UInt64(countHex, radix: 16), count > 0, count < 50 else { return [] }
        
        var addresses: [String] = []
        for i in 0..<Int(count) {
            let wordStart = 192 + i * 64
            guard wordStart + 64 <= clean.count else { break }
            let start = clean.index(clean.startIndex, offsetBy: wordStart + 24)
            let end = clean.index(start, offsetBy: 40)
            let addr = "0x" + String(clean[start..<end])
            if addr != EthConstants.zeroAddress && addr != "0x0000000000000000000000000000000000000001" {
                addresses.append(addr)
            }
        }
        return addresses
    }
    
    func ethCall(to: String, data: String) async throws -> String {
        let params: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "eth_call",
            "params": [
                ["to": to, "data": data],
                "latest"
            ],
            "id": 1
        ]
        
        let result = try await rpcCall(params: params)
        guard let hexResult = result["result"] as? String else {
            throw BlockchainError.rpcError("Invalid eth_call response")
        }
        return hexResult
    }
    
    func getStorageAt(address: String, slot: String) async throws -> String {
        let params: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "eth_getStorageAt",
            "params": [address, slot, "latest"],
            "id": 1
        ]
        
        let result = try await rpcCall(params: params)
        guard let hexResult = result["result"] as? String else {
            throw BlockchainError.rpcError("Invalid eth_getStorageAt response")
        }
        return hexResult
    }
    
    func getNonce(for address: String) async throws -> UInt64 {
        let params: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "eth_getTransactionCount",
            "params": [address, "pending"],
            "id": 1
        ]
        
        let result = try await rpcCall(params: params)
        guard let hexString = result["result"] as? String else {
            throw BlockchainError.rpcError("Invalid nonce response")
        }
        let clean = hexString.replacingOccurrences(of: "0x", with: "")
        return UInt64(clean, radix: 16) ?? 0
    }
    
    func estimateGas(to: String, data: String, from: String? = nil, value: String = "0x0") async throws -> UInt64 {
        var txObj: [String: Any] = ["to": to, "data": data, "value": value]
        if let from = from { txObj["from"] = from }
        
        let params: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "eth_estimateGas",
            "params": [txObj],
            "id": 1
        ]
        
        let result = try await rpcCall(params: params)
        guard let hexString = result["result"] as? String else {
            throw BlockchainError.rpcError("Gas estimation failed")
        }
        let clean = hexString.replacingOccurrences(of: "0x", with: "")
        return UInt64(clean, radix: 16) ?? 21000
    }
    
    func getGasPrice() async throws -> UInt64 {
        let params: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "eth_gasPrice",
            "params": [],
            "id": 1
        ]
        
        let result = try await rpcCall(params: params)
        guard let hexString = result["result"] as? String else {
            throw BlockchainError.rpcError("Gas price fetch failed")
        }
        let clean = hexString.replacingOccurrences(of: "0x", with: "")
        return UInt64(clean, radix: 16) ?? 1_000_000_000
    }
    
    func sendRawTransaction(_ signedTxHex: String) async throws -> String {
        let params: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "eth_sendRawTransaction",
            "params": [signedTxHex],
            "id": 1
        ]
        
        let result = try await rpcCall(params: params)
        guard let txHash = result["result"] as? String else {
            if let error = result["error"] as? [String: Any], let msg = error["message"] as? String {
                throw BlockchainError.contractError("Broadcast failed: \(msg)")
            }
            throw BlockchainError.transactionFailed
        }
        return txHash
    }
    
    /// Poll for a transaction receipt until confirmed or timeout
    func waitForTransactionReceipt(txHash: String, maxAttempts: Int = 30, intervalSeconds: UInt64 = 2) async throws {
        _ = try await getTransactionReceipt(txHash: txHash, maxAttempts: maxAttempts, intervalSeconds: intervalSeconds)
    }
    
    /// Poll for a transaction receipt and return the full receipt data
    func getTransactionReceipt(txHash: String, maxAttempts: Int = 30, intervalSeconds: UInt64 = 2) async throws -> [String: Any] {
        for _ in 0..<maxAttempts {
            let params: [String: Any] = [
                "jsonrpc": "2.0",
                "method": "eth_getTransactionReceipt",
                "params": [txHash],
                "id": Int.random(in: 1...999999)
            ]
            
            let json = try await rpcCall(params: params)
            
            if let result = json["result"] as? [String: Any],
               let status = result["status"] as? String {
                if status == "0x1" {
                    return result
                } else if status == "0x0" {
                    throw BlockchainError.transactionFailed
                }
            }
            
            // Receipt not yet available, wait and retry
            try await Task.sleep(nanoseconds: intervalSeconds * 1_000_000_000)
        }
        
        throw BlockchainError.contractError("Transaction confirmation timeout")
    }
    
    /// Parse an address from the first matching event log topic
    /// Factory events emit: event TimeLockCreated(address indexed module, address indexed safe, ...)
    nonisolated func parseAddressFromLogs(receipt: [String: Any], eventSignature: String) -> String? {
        guard let logs = receipt["logs"] as? [[String: Any]] else { return nil }
        let eventTopic = Keccak256.hash(Data(eventSignature.utf8)).hexString
        
        for log in logs {
            guard let topics = log["topics"] as? [String],
                  !topics.isEmpty,
                  topics[0].lowercased() == eventTopic.lowercased(),
                  topics.count >= 2
            else { continue }
            
            // topic[1] = indexed module address (32 bytes, address in last 20)
            let raw = topics[1]
            let clean = raw.hasPrefix("0x") ? String(raw.dropFirst(2)) : raw
            if clean.count >= 40 {
                return "0x" + String(clean.suffix(40))
            }
        }
        return nil
    }
    
    private func rpcCall(params: [String: Any], maxRetries: Int = 3) async throws -> [String: Any] {
        var lastError: Error = BlockchainError.networkUnavailable
        
        for attempt in 0..<maxRetries {
            do {
                var request = URLRequest(url: rpcURL)
                request.httpMethod = "POST"
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try JSONSerialization.data(withJSONObject: params)
                
                let (data, response) = try await session.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    throw BlockchainError.networkUnavailable
                }
                
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    throw BlockchainError.rpcError("Invalid JSON response")
                }
                
                if let error = json["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    throw BlockchainError.rpcError(message)
                }
                
                return json
            } catch {
                lastError = error
                if attempt < maxRetries - 1 {
                    let delay = UInt64(pow(2.0, Double(attempt))) * 500_000_000
                    try? await Task.sleep(nanoseconds: delay)
                }
            }
        }
        
        throw lastError
    }
    
    private func convertToFiat(amount: Double, asset: AssetType) async -> Double {
        switch asset {
        case .usdc: return amount
        case .eurc: return amount * 1.08
        case .paxg: return amount * 2650.0
        }
    }
}

extension String {
    func leftPadded(toLength: Int, withPad character: Character) -> String {
        let currentLength = self.count
        if currentLength >= toLength { return self }
        return String(repeating: character, count: toLength - currentLength) + self
    }
}
