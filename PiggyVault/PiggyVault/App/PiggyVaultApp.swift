import SwiftUI
import UserNotifications

@main
struct PiggyVaultApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var localization = LocalizationManager.shared
    @StateObject private var notificationService = NotificationService.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var showPrivacyScreen = false
    
    init() {
        UserDefaults.standard.register(defaults: ["biometricLockEnabled": true])
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()
                    .environmentObject(appState)
                    .environmentObject(localization)
                    .environmentObject(notificationService)
                    .preferredColorScheme(.dark)
                    .task {
                        notificationService.registerCategories()
                        await notificationService.requestAuthorization()
                    }
                
                if showPrivacyScreen {
                    ZStack {
                        PiggyTheme.Colors.background
                            .ignoresSafeArea()
                        
                        VStack(spacing: 16) {
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(PiggyTheme.Colors.primaryGradient)
                            Text("PiggyVault")
                                .font(PiggyTheme.Typography.title)
                                .foregroundColor(.white)
                        }
                    }
                    .transition(.opacity)
                    .ignoresSafeArea()
                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                appState.lockApp()
                withAnimation(.easeIn(duration: 0.1)) { showPrivacyScreen = true }
            case .inactive:
                withAnimation(.easeIn(duration: 0.1)) { showPrivacyScreen = true }
            case .active:
                withAnimation(.easeOut(duration: 0.2)) { showPrivacyScreen = false }
                Task { await notificationService.checkAuthorizationStatus() }
            @unknown default:
                break
            }
        }
    }
}
