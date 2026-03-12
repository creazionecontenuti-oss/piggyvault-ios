import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Tab = .dashboard
    @State private var previousTab: Tab = .dashboard
    @State private var tabBarVisible = true
    
    enum Tab: String, CaseIterable {
        case dashboard
        case piggyBanks
        case deposit
        case settings
        
        var icon: String {
            switch self {
            case .dashboard: return "house.fill"
            case .piggyBanks: return "lock.shield.fill"
            case .deposit: return "plus.circle.fill"
            case .settings: return "gearshape.fill"
            }
        }
        
        var titleKey: String {
            switch self {
            case .dashboard: return "tab.dashboard"
            case .piggyBanks: return "tab.piggy_banks"
            case .deposit: return "tab.deposit"
            case .settings: return "tab.settings"
            }
        }
    }
    
    private var tabIndex: Int {
        Tab.allCases.firstIndex(of: selectedTab) ?? 0
    }
    private var previousIndex: Int {
        Tab.allCases.firstIndex(of: previousTab) ?? 0
    }
    private var tabTransition: AnyTransition {
        let goingRight = tabIndex > previousIndex
        return .asymmetric(
            insertion: .move(edge: goingRight ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: goingRight ? .leading : .trailing).combined(with: .opacity)
        )
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ZStack {
                switch selectedTab {
                case .dashboard:
                    DashboardView()
                        .transition(tabTransition)
                case .piggyBanks:
                    PiggyBankListView()
                        .transition(tabTransition)
                case .deposit:
                    DepositView()
                        .transition(tabTransition)
                case .settings:
                    SettingsView()
                        .transition(tabTransition)
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.88), value: selectedTab)
            
            // Custom Tab Bar
            if tabBarVisible {
                CustomTabBar(selectedTab: $selectedTab, previousTab: $previousTab)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // Network offline banner overlay
            VStack {
                NetworkBanner()
                    .padding(.top, 50)
                Spacer()
            }
            .allowsHitTesting(true)
        }
        .ignoresSafeArea(.keyboard)
    }
}

struct CustomTabBar: View {
    @Binding var selectedTab: MainTabView.Tab
    @Binding var previousTab: MainTabView.Tab
    @Namespace private var namespace
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(MainTabView.Tab.allCases, id: \.rawValue) { tab in
                TabBarButton(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    namespace: namespace
                ) {
                    HapticManager.selection()
                    previousTab = selectedTab
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        selectedTab = tab
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 12)
        .padding(.bottom, 28)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(PiggyTheme.Colors.surface.opacity(0.95))
                
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.06), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
            }
            .shadow(color: Color.black.opacity(0.3), radius: 20, y: -5)
        )
        .padding(.horizontal, 16)
    }
}

struct TabBarButton: View {
    let tab: MainTabView.Tab
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void
    @State private var isPressed = false
    @State private var iconBounce: CGFloat = 1.0
    
    var body: some View {
        Button {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.45)) {
                isPressed = true
                iconBounce = 0.7
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.4)) {
                    isPressed = false
                    iconBounce = 1.0
                }
            }
            action()
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    if isSelected {
                        Capsule()
                            .fill(PiggyTheme.Colors.primary.opacity(0.2))
                            .frame(width: 56, height: 32)
                            .matchedGeometryEffect(id: "tab_bg", in: namespace)
                        
                        Capsule()
                            .fill(PiggyTheme.Colors.primary.opacity(0.08))
                            .frame(width: 64, height: 36)
                            .blur(radius: 4)
                    }
                    
                    Image(systemName: tab.icon)
                        .font(.system(size: tab == .deposit ? 24 : 20, weight: .semibold))
                        .foregroundColor(isSelected ? PiggyTheme.Colors.primary : .white.opacity(0.4))
                        .scaleEffect(iconBounce * (isSelected ? 1.1 : 1.0))
                        .symbolEffect(.bounce, value: isSelected)
                }
                .frame(height: 32)
                
                Text(tab.titleKey.localized)
                    .font(PiggyTheme.Typography.caption)
                    .foregroundColor(isSelected ? PiggyTheme.Colors.primary : .white.opacity(0.4))
            }
            .frame(maxWidth: .infinity)
            .scaleEffect(isPressed ? 0.85 : 1.0)
        }
        .buttonStyle(.plain)
    }
}
