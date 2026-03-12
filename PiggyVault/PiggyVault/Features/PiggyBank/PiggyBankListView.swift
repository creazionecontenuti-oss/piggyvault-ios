import SwiftUI

struct PiggyBankListView: View {
    @EnvironmentObject var appState: AppState
    @State private var showCreateSheet = false
    @State private var selectedPiggy: PiggyBank?
    @State private var showContent = false
    @State private var isLoadingData = true
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("piggy.title".localized)
                            .font(PiggyTheme.Typography.title)
                            .foregroundColor(.white)
                        
                        Text("piggy.subtitle".localized)
                            .font(PiggyTheme.Typography.subheadline)
                            .foregroundColor(.white.opacity(0.5))
                    }
                    
                    Spacer()
                    
                    Button {
                        HapticManager.mediumTap()
                        showCreateSheet = true
                    } label: {
                        ZStack {
                            Circle()
                                .fill(PiggyTheme.Colors.primaryGradient)
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .shadow(color: PiggyTheme.Colors.primary.opacity(0.4), radius: 8, y: 4)
                    }
                }
                .padding(.top, 60)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : -20)
                
                if isLoadingData {
                    PiggyListShimmer()
                        .transition(.opacity)
                } else if appState.piggyBanks.isEmpty {
                    emptyState
                } else {
                    // Stats Row
                    statsRow
                    
                    // Piggy Bank List
                    LazyVStack(spacing: 16) {
                        ForEach(Array(appState.piggyBanks.enumerated()), id: \.element.id) { index, piggy in
                            PiggyCard(piggyBank: piggy) {
                                HapticManager.lightTap()
                                selectedPiggy = piggy
                            }
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : 30)
                            .animation(
                                .spring(response: 0.5, dampingFraction: 0.8)
                                .delay(Double(index) * 0.1),
                                value: showContent
                            )
                        }
                    }
                }
                
                Color.clear.frame(height: 100)
            }
            .padding(.horizontal, 20)
        }
        .background(PiggyTheme.Colors.background.ignoresSafeArea())
        .refreshable {
            HapticManager.lightTap()
            await appState.refreshData()
            HapticManager.success()
        }
        .sheet(isPresented: $showCreateSheet) {
            CreatePiggyBankView()
                .environmentObject(appState)
        }
        .sheet(item: $selectedPiggy) { piggy in
            PiggyBankDetailView(piggyBank: piggy)
                .environmentObject(appState)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                showContent = true
            }
            Task {
                await appState.refreshData()
                withAnimation(.easeOut(duration: 0.3)) {
                    isLoadingData = false
                }
            }
        }
    }
    
    private var statsRow: some View {
        HStack(spacing: 12) {
            StatCard(
                title: "piggy.stats.total".localized,
                value: "\(appState.piggyBanks.count)",
                icon: "lock.shield.fill",
                color: PiggyTheme.Colors.primary
            )
            
            StatCard(
                title: "piggy.stats.locked".localized,
                value: "\(appState.piggyBanks.filter { $0.status == .locked }.count)",
                icon: "lock.fill",
                color: PiggyTheme.Colors.warning
            )
            
            StatCard(
                title: "piggy.stats.ready".localized,
                value: "\(appState.piggyBanks.filter { $0.isUnlockable }.count)",
                icon: "lock.open.fill",
                color: PiggyTheme.Colors.accentGreen
            )
        }
        .opacity(showContent ? 1 : 0)
    }
    
    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 40)
            
            FloatingIcon(
                systemName: "lock.shield.fill",
                gradient: PiggyTheme.Colors.primaryGradient,
                bgColor: PiggyTheme.Colors.primary,
                size: 100
            )
            
            VStack(spacing: 12) {
                Text("piggy.empty.title".localized)
                    .font(PiggyTheme.Typography.title2)
                    .foregroundColor(.white)
                
                Text("piggy.empty.description".localized)
                    .font(PiggyTheme.Typography.body)
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 20)
            
            GlassButton(
                title: "piggy.empty.create".localized,
                icon: "plus.circle.fill"
            ) {
                HapticManager.mediumTap()
                showCreateSheet = true
            }
            .padding(.horizontal, 40)
        }
        .opacity(showContent ? 1 : 0)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)
            
            Text(value)
                .font(PiggyTheme.Typography.title2)
                .foregroundColor(.white)
            
            Text(title)
                .font(PiggyTheme.Typography.caption)
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: PiggyTheme.CornerRadius.medium)
                .fill(PiggyTheme.Colors.surface.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: PiggyTheme.CornerRadius.medium)
                        .stroke(color.opacity(0.15), lineWidth: 0.5)
                )
        )
    }
}
