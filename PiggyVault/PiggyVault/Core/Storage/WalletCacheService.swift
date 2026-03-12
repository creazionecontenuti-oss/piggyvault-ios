import Foundation

final class WalletCacheService {
    static let shared = WalletCacheService()
    
    private let defaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    private enum Key: String {
        case cachedBalances = "pv_cached_balances"
        case cachedPiggyBanks = "pv_cached_piggy_banks"
        case cachedTransactions = "pv_cached_transactions"
        case lastSyncTimestamp = "pv_last_sync"
        case safeAddress = "pv_safe_address"
    }
    
    // MARK: - Balances
    
    func cacheBalances(_ balances: [CachedBalance]) {
        if let data = try? encoder.encode(balances) {
            defaults.set(data, forKey: Key.cachedBalances.rawValue)
            defaults.set(Date().timeIntervalSince1970, forKey: Key.lastSyncTimestamp.rawValue)
        }
    }
    
    func loadCachedBalances() -> [CachedBalance]? {
        guard let data = defaults.data(forKey: Key.cachedBalances.rawValue) else { return nil }
        return try? decoder.decode([CachedBalance].self, from: data)
    }
    
    // MARK: - Piggy Banks
    
    func cachePiggyBanks(_ piggies: [CachedPiggyBank]) {
        if let data = try? encoder.encode(piggies) {
            defaults.set(data, forKey: Key.cachedPiggyBanks.rawValue)
        }
    }
    
    func loadCachedPiggyBanks() -> [CachedPiggyBank]? {
        guard let data = defaults.data(forKey: Key.cachedPiggyBanks.rawValue) else { return nil }
        return try? decoder.decode([CachedPiggyBank].self, from: data)
    }
    
    // MARK: - Transactions
    
    func cacheTransactions(_ txns: [CachedTransaction]) {
        if let data = try? encoder.encode(txns) {
            defaults.set(data, forKey: Key.cachedTransactions.rawValue)
        }
    }
    
    func loadCachedTransactions() -> [CachedTransaction]? {
        guard let data = defaults.data(forKey: Key.cachedTransactions.rawValue) else { return nil }
        return try? decoder.decode([CachedTransaction].self, from: data)
    }
    
    // MARK: - Safe Address
    
    func cacheSafeAddress(_ address: String) {
        defaults.set(address, forKey: Key.safeAddress.rawValue)
    }
    
    func loadCachedSafeAddress() -> String? {
        defaults.string(forKey: Key.safeAddress.rawValue)
    }
    
    func clearSafeAddress() {
        defaults.removeObject(forKey: Key.safeAddress.rawValue)
    }
    
    // MARK: - Sync Info
    
    var lastSyncDate: Date? {
        let ts = defaults.double(forKey: Key.lastSyncTimestamp.rawValue)
        return ts > 0 ? Date(timeIntervalSince1970: ts) : nil
    }
    
    var isCacheStale: Bool {
        guard let lastSync = lastSyncDate else { return true }
        return Date().timeIntervalSince(lastSync) > 300 // 5 minutes
    }
    
    // MARK: - Clear
    
    func clearAll() {
        defaults.removeObject(forKey: Key.cachedBalances.rawValue)
        defaults.removeObject(forKey: Key.cachedPiggyBanks.rawValue)
        defaults.removeObject(forKey: Key.cachedTransactions.rawValue)
        defaults.removeObject(forKey: Key.lastSyncTimestamp.rawValue)
        defaults.removeObject(forKey: Key.safeAddress.rawValue)
    }
}

// MARK: - Codable Cache Models

struct CachedBalance: Codable {
    let assetRawValue: String
    let balance: Double
    let fiatValue: Double
    
    init(from assetBalance: AssetBalance) {
        self.assetRawValue = assetBalance.asset.rawValue
        self.balance = assetBalance.balance
        self.fiatValue = assetBalance.fiatValue
    }
    
    func toAssetBalance() -> AssetBalance? {
        guard let asset = AssetType(rawValue: assetRawValue) else { return nil }
        return AssetBalance(asset: asset, balance: balance, fiatValue: fiatValue)
    }
}

struct CachedPiggyBank: Codable {
    let id: String
    let name: String
    let targetAmount: Double?
    let currentAmount: Double
    let asset: String
    let lockTypeRaw: String
    let statusRaw: String
    let colorRaw: String
    let contractAddress: String
    let createdAt: Date
    let unlockDate: Date?
    
    init(from piggy: PiggyBank) {
        self.id = piggy.id
        self.name = piggy.name
        self.targetAmount = piggy.targetAmount
        self.currentAmount = piggy.currentAmount
        self.asset = piggy.asset.rawValue
        self.lockTypeRaw = piggy.lockType.rawValue
        self.statusRaw = piggy.status.rawValue
        self.colorRaw = piggy.color.rawValue
        self.contractAddress = piggy.contractAddress
        self.createdAt = piggy.createdAt
        self.unlockDate = piggy.unlockDate
    }
    
    func toPiggyBank() -> PiggyBank? {
        guard let assetType = AssetType(rawValue: asset),
              let lockType = LockType(rawValue: lockTypeRaw),
              let status = PiggyBankStatus(rawValue: statusRaw),
              let color = PiggyBankColor(rawValue: colorRaw) else { return nil }
        
        return PiggyBank(
            id: id,
            name: name,
            asset: assetType,
            lockType: lockType,
            createdAt: createdAt,
            currentAmount: currentAmount,
            targetAmount: targetAmount,
            unlockDate: unlockDate,
            status: status,
            contractAddress: contractAddress,
            color: color
        )
    }
}

struct CachedTransaction: Codable {
    let id: String
    let typeRaw: String
    let assetRaw: String
    let amount: Double
    let timestamp: Date
    let hash: String
    let statusRaw: String
    let piggyBankId: String?
    
    init(from txn: Transaction) {
        self.id = txn.id
        self.typeRaw = txn.type.rawValue
        self.assetRaw = txn.asset.rawValue
        self.amount = txn.amount
        self.timestamp = txn.timestamp
        self.hash = txn.hash
        self.statusRaw = txn.status.rawValue
        self.piggyBankId = txn.piggyBankId
    }
    
    func toTransaction() -> Transaction? {
        guard let type = TransactionType(rawValue: typeRaw),
              let asset = AssetType(rawValue: assetRaw),
              let status = TransactionStatus(rawValue: statusRaw) else { return nil }
        
        return Transaction(
            id: id,
            type: type,
            asset: asset,
            amount: amount,
            timestamp: timestamp,
            hash: hash,
            status: status,
            piggyBankId: piggyBankId
        )
    }
}
