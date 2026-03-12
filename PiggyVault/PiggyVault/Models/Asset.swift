import SwiftUI

enum AssetType: String, Codable, CaseIterable, Identifiable {
    case usdc = "USDC"
    case eurc = "EURC"
    case paxg = "PAXG"
    
    var id: String { rawValue }
    
    var name: String {
        switch self {
        case .usdc: return "USD Coin"
        case .eurc: return "Euro Coin"
        case .paxg: return "Paxos Gold"
        }
    }
    
    var symbol: String { rawValue }
    
    var icon: String {
        switch self {
        case .usdc: return "dollarsign.circle.fill"
        case .eurc: return "eurosign.circle.fill"
        case .paxg: return "bitcoinsign.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .usdc: return Color(hex: "2775CA")
        case .eurc: return Color(hex: "1A73E8")
        case .paxg: return PiggyTheme.Colors.accentGold
        }
    }
    
    var contractAddress: String {
        switch self {
        case .usdc: return "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"
        case .eurc: return "0x60a3E35Cc302bFA44Cb288Bc5a4F316Fdb1adb42"
        case .paxg: return "0x0000000000000000000000000000000000000000"
        }
    }
    
    var decimals: Int {
        switch self {
        case .usdc, .eurc: return 6
        case .paxg: return 18
        }
    }
    
    var currencySymbol: String {
        switch self {
        case .usdc: return "$"
        case .eurc: return "€"
        case .paxg: return "oz"
        }
    }
}

struct AssetBalance: Identifiable, Equatable {
    let id = UUID()
    let asset: AssetType
    var balance: Double
    var fiatValue: Double
    
    var formattedBalance: String {
        switch asset {
        case .usdc, .eurc:
            return String(format: "%.2f", balance)
        case .paxg:
            return String(format: "%.4f", balance)
        }
    }
    
    var formattedFiatValue: String {
        return String(format: "$%.2f", fiatValue)
    }
}
