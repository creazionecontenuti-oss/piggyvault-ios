import SwiftUI
import UserNotifications

@main
struct PiggyVaultApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var localization = LocalizationManager.shared
    @StateObject private var notificationService = NotificationService.shared
    @Environment(\.scenePhase) private var scenePhase
    
    init() {
        UserDefaults.standard.register(defaults: ["biometricLockEnabled": true])
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(localization)
                .environmentObject(notificationService)
                .preferredColorScheme(.dark)
                .task {
                    notificationService.registerCategories()
                    await notificationService.requestAuthorization()
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                appState.lockApp()
            case .active:
                Task { await notificationService.checkAuthorizationStatus() }
            default:
                break
            }
        }
    }
}
