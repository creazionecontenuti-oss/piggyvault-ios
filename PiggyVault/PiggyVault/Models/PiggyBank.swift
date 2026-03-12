import SwiftUI

enum LockType: String, Codable, CaseIterable, Identifiable {
    case timeLock = "time_lock"
    case targetLock = "target_lock"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .timeLock: return "piggy.lock_type.time".localized
        case .targetLock: return "piggy.lock_type.target".localized
        }
    }
    
    var icon: String {
        switch self {
        case .timeLock: return "clock.fill"
        case .targetLock: return "target"
        }
    }
    
    var description: String {
        switch self {
        case .timeLock: return "piggy.lock_type.time_desc".localized
        case .targetLock: return "piggy.lock_type.target_desc".localized
        }
    }
}

enum PiggyBankStatus: String, Codable {
    case active
    case locked
    case unlocked
    case completed
    
    var color: Color {
        switch self {
        case .active: return PiggyTheme.Colors.accentGreen
        case .locked: return PiggyTheme.Colors.warning
        case .unlocked: return PiggyTheme.Colors.accent
        case .completed: return PiggyTheme.Colors.primaryLight
        }
    }
    
    var icon: String {
        switch self {
        case .active: return "checkmark.circle.fill"
        case .locked: return "lock.fill"
        case .unlocked: return "lock.open.fill"
        case .completed: return "star.fill"
        }
    }
}

struct PiggyBank: Identifiable, Equatable {
    let id: String
    let name: String
    let asset: AssetType
    let lockType: LockType
    let createdAt: Date
    var currentAmount: Double
    var targetAmount: Double?
    var unlockDate: Date?
    var status: PiggyBankStatus
    let contractAddress: String
    let color: PiggyBankColor
    
    var progress: Double {
        if let target = targetAmount, target > 0 {
            return min(currentAmount / target, 1.0)
        }
        if let unlock = unlockDate {
            let total = unlock.timeIntervalSince(createdAt)
            let elapsed = Date().timeIntervalSince(createdAt)
            return min(max(elapsed / total, 0), 1.0)
        }
        return 0
    }
    
    var isUnlockable: Bool {
        switch lockType {
        case .timeLock:
            guard let unlockDate = unlockDate else { return false }
            return Date() >= unlockDate
        case .targetLock:
            guard let target = targetAmount else { return false }
            return currentAmount >= target
        }
    }
    
    var remainingTime: String? {
        guard let unlockDate = unlockDate else { return nil }
        let remaining = unlockDate.timeIntervalSince(Date())
        if remaining <= 0 { return "piggy.time.ready".localized }
        
        let days = Int(remaining / 86400)
        let hours = Int((remaining.truncatingRemainder(dividingBy: 86400)) / 3600)
        
        if days > 365 {
            let years = days / 365
            let months = (days % 365) / 30
            return "\(years)y \(months)m"
        } else if days > 30 {
            let months = days / 30
            let remainDays = days % 30
            return "\(months)m \(remainDays)d"
        } else if days > 0 {
            return "\(days)d \(hours)h"
        } else {
            let minutes = Int((remaining.truncatingRemainder(dividingBy: 3600)) / 60)
            return "\(hours)h \(minutes)m"
        }
    }
    
    var formattedAmount: String {
        switch asset {
        case .usdc, .eurc:
            return String(format: "%.2f", currentAmount)
        case .paxg:
            return String(format: "%.4f", currentAmount)
        }
    }
    
    static func == (lhs: PiggyBank, rhs: PiggyBank) -> Bool {
        lhs.id == rhs.id
    }
}

enum PiggyBankColor: String, Codable, CaseIterable {
    case pink, blue, purple, orange, green, gold
    
    var gradient: LinearGradient {
        switch self {
        case .pink:
            return LinearGradient(colors: [Color(hex: "FF6B9D"), Color(hex: "C44569")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .blue:
            return LinearGradient(colors: [Color(hex: "4ECDC4"), Color(hex: "2C8C99")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .purple:
            return LinearGradient(colors: [Color(hex: "A29BFE"), Color(hex: "6C5CE7")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .orange:
            return LinearGradient(colors: [Color(hex: "F39C12"), Color(hex: "E67E22")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .green:
            return LinearGradient(colors: [Color(hex: "00E676"), Color(hex: "00C853")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .gold:
            return LinearGradient(colors: [Color(hex: "FFD700"), Color(hex: "D4A017")], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
    
    var primary: Color {
        switch self {
        case .pink: return Color(hex: "FF6B9D")
        case .blue: return Color(hex: "4ECDC4")
        case .purple: return Color(hex: "A29BFE")
        case .orange: return Color(hex: "F39C12")
        case .green: return Color(hex: "00E676")
        case .gold: return Color(hex: "FFD700")
        }
    }
}
