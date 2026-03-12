import SwiftUI

enum AuthMethod: String, Codable {
    case apple
    case google
}

struct UserWallet: Equatable {
    let address: String
    let authMethod: AuthMethod
    var safeAddress: String?
    
    var shortAddress: String {
        guard address.count > 10 else { return address }
        let start = address.prefix(6)
        let end = address.suffix(4)
        return "\(start)...\(end)"
    }
    
    var explorerURL: URL? {
        URL(string: "https://basescan.org/address/\(safeAddress ?? address)")
    }
}

struct Transaction: Identifiable, Equatable {
    let id: String
    let type: TransactionType
    let asset: AssetType
    let amount: Double
    let timestamp: Date
    let hash: String
    let status: TransactionStatus
    let piggyBankId: String?
    
    var formattedAmount: String {
        let prefix = type == .deposit ? "+" : "-"
        switch asset {
        case .usdc, .eurc:
            return "\(prefix)\(String(format: "%.2f", amount)) \(asset.symbol)"
        case .paxg:
            return "\(prefix)\(String(format: "%.4f", amount)) \(asset.symbol)"
        }
    }
    
    var explorerURL: URL? {
        URL(string: "https://basescan.org/tx/\(hash)")
    }
}

enum TransactionType: String, Codable {
    case deposit
    case withdraw
    case lock
    case unlock
    
    var icon: String {
        switch self {
        case .deposit: return "arrow.down.circle.fill"
        case .withdraw: return "arrow.up.circle.fill"
        case .lock: return "lock.fill"
        case .unlock: return "lock.open.fill"
        }
    }
    
    var color: SwiftUI.Color {
        switch self {
        case .deposit: return PiggyTheme.Colors.accentGreen
        case .withdraw: return PiggyTheme.Colors.error
        case .lock: return PiggyTheme.Colors.warning
        case .unlock: return PiggyTheme.Colors.accent
        }
    }
}

enum TransactionStatus: String, Codable {
    case pending
    case confirmed
    case failed
}
