import Foundation
import UserNotifications
import SwiftUI

@MainActor
final class NotificationService: ObservableObject {
    static let shared = NotificationService()
    
    @Published var isAuthorized: Bool = false
    @Published var notificationsEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled")
        }
    }
    
    private let center = UNUserNotificationCenter.current()
    
    private init() {
        notificationsEnabled = UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool ?? true
        Task { await checkAuthorizationStatus() }
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            isAuthorized = granted
            return granted
        } catch {
            print("[NotificationService] Authorization error: \(error)")
            return false
        }
    }
    
    func checkAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
    }
    
    // MARK: - Transaction Notifications
    
    func notifyTransactionConfirmed(type: TransactionNotificationType, asset: String, amount: String?) {
        guard notificationsEnabled else { return }
        
        let (title, body) = type.localizedContent(asset: asset, amount: amount)
        scheduleLocalNotification(
            id: "tx_confirmed_\(UUID().uuidString)",
            title: title,
            body: body,
            categoryIdentifier: "TRANSACTION",
            delay: 0.5
        )
    }
    
    func notifyTransactionFailed(type: TransactionNotificationType, asset: String) {
        guard notificationsEnabled else { return }
        
        let title = "notification.tx.failed.title".localized
        let body = String(format: "notification.tx.failed.body".localized, type.actionName, asset)
        scheduleLocalNotification(
            id: "tx_failed_\(UUID().uuidString)",
            title: title,
            body: body,
            categoryIdentifier: "TRANSACTION",
            delay: 0.5
        )
    }
    
    func notifyPiggyBankCreated(name: String) {
        guard notificationsEnabled else { return }
        
        scheduleLocalNotification(
            id: "piggy_created_\(UUID().uuidString)",
            title: "notification.piggy.created.title".localized,
            body: String(format: "notification.piggy.created.body".localized, name),
            categoryIdentifier: "PIGGY_BANK",
            delay: 0.5
        )
    }
    
    func notifyPiggyBankUnlocked(name: String) {
        guard notificationsEnabled else { return }
        
        scheduleLocalNotification(
            id: "piggy_unlocked_\(UUID().uuidString)",
            title: "notification.piggy.unlocked.title".localized,
            body: String(format: "notification.piggy.unlocked.body".localized, name),
            categoryIdentifier: "PIGGY_BANK",
            delay: 0.5
        )
    }
    
    func scheduleUnlockReminder(piggyName: String, unlockDate: Date, moduleAddress: String) {
        guard notificationsEnabled else { return }
        
        let reminderDate = Calendar.current.date(byAdding: .hour, value: -1, to: unlockDate) ?? unlockDate
        guard reminderDate > Date() else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "notification.piggy.unlock_soon.title".localized
        content.body = String(format: "notification.piggy.unlock_soon.body".localized, piggyName)
        content.sound = .default
        content.categoryIdentifier = "PIGGY_BANK"
        
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "unlock_reminder_\(moduleAddress)",
            content: content,
            trigger: trigger
        )
        
        center.add(request) { error in
            if let error = error {
                print("[NotificationService] Unlock reminder error: \(error)")
            }
        }
    }
    
    func cancelUnlockReminder(moduleAddress: String) {
        center.removePendingNotificationRequests(withIdentifiers: ["unlock_reminder_\(moduleAddress)"])
    }
    
    // MARK: - Private
    
    private func scheduleLocalNotification(id: String, title: String, body: String, categoryIdentifier: String, delay: TimeInterval) {
        Task {
            if !isAuthorized {
                let granted = await requestAuthorization()
                guard granted else { return }
            }
            
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            content.categoryIdentifier = categoryIdentifier
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(delay, 0.1), repeats: false)
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            
            do {
                try await center.add(request)
            } catch {
                print("[NotificationService] Schedule error: \(error)")
            }
        }
    }
    
    // MARK: - Setup Categories
    
    func registerCategories() {
        let txCategory = UNNotificationCategory(
            identifier: "TRANSACTION",
            actions: [],
            intentIdentifiers: [],
            options: .customDismissAction
        )
        let piggyCategory = UNNotificationCategory(
            identifier: "PIGGY_BANK",
            actions: [],
            intentIdentifiers: [],
            options: .customDismissAction
        )
        center.setNotificationCategories([txCategory, piggyCategory])
    }
}

// MARK: - Transaction Notification Type

enum TransactionNotificationType {
    case deposit
    case withdraw
    case lock
    case unlock
    case safeDeployed
    case piggyCreated
    
    var actionName: String {
        switch self {
        case .deposit: return "notification.action.deposit".localized
        case .withdraw: return "notification.action.withdraw".localized
        case .lock: return "notification.action.lock".localized
        case .unlock: return "notification.action.unlock".localized
        case .safeDeployed: return "notification.action.deploy".localized
        case .piggyCreated: return "notification.action.create".localized
        }
    }
    
    func localizedContent(asset: String, amount: String?) -> (title: String, body: String) {
        switch self {
        case .deposit:
            let title = "notification.tx.deposit.title".localized
            let body: String
            if let amount = amount {
                body = String(format: "notification.tx.deposit.body".localized, amount, asset)
            } else {
                body = String(format: "notification.tx.deposit.body_no_amount".localized, asset)
            }
            return (title, body)
        case .withdraw:
            let title = "notification.tx.withdraw.title".localized
            let body: String
            if let amount = amount {
                body = String(format: "notification.tx.withdraw.body".localized, amount, asset)
            } else {
                body = String(format: "notification.tx.withdraw.body_no_amount".localized, asset)
            }
            return (title, body)
        case .lock:
            let title = "notification.tx.lock.title".localized
            let body = String(format: "notification.tx.lock.body".localized, asset)
            return (title, body)
        case .unlock:
            let title = "notification.tx.unlock.title".localized
            let body = String(format: "notification.tx.unlock.body".localized, asset)
            return (title, body)
        case .safeDeployed:
            return ("notification.safe.deployed.title".localized, "notification.safe.deployed.body".localized)
        case .piggyCreated:
            return ("notification.piggy.created.title".localized, "notification.piggy.created.body_generic".localized)
        }
    }
}
