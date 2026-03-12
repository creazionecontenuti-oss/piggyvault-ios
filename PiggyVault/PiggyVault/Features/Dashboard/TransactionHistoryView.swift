import SwiftUI

struct TransactionHistoryView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var showContent = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                PiggyTheme.Colors.background
                    .ignoresSafeArea()
                
                if appState.recentTransactions.isEmpty {
                    emptyState
                } else {
                    transactionList
                }
            }
            .navigationTitle("transactions.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        HapticManager.lightTap()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(PiggyTheme.Colors.textSecondary)
                    }
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) {
                showContent = true
            }
        }
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            
            FloatingIcon(
                systemName: "clock.arrow.circlepath",
                gradient: PiggyTheme.Colors.primaryGradient,
                bgColor: PiggyTheme.Colors.primary,
                size: 90
            )
            
            VStack(spacing: 8) {
                Text("transactions.empty.title".localized)
                    .font(PiggyTheme.Typography.headline)
                    .foregroundColor(.white)
                
                Text("transactions.empty.subtitle".localized)
                    .font(PiggyTheme.Typography.body)
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - Transaction List
    private var transactionList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 8) {
                ForEach(Array(appState.recentTransactions.enumerated()), id: \.element.id) { index, transaction in
                    TransactionRow(transaction: transaction)
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)
                        .animation(
                            .spring(response: 0.5, dampingFraction: 0.8)
                            .delay(Double(index) * 0.05),
                            value: showContent
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
    }
}

// MARK: - Transaction Row
struct TransactionRow: View {
    let transaction: Transaction
    @State private var isPressed = false
    @State private var iconBounce: CGFloat = 1.0
    
    var body: some View {
        Button {
            HapticManager.lightTap()
            withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                iconBounce = 1.2
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    iconBounce = 1.0
                }
            }
            if let url = transaction.explorerURL {
                UIApplication.shared.open(url)
            }
        } label: {
            HStack(spacing: 14) {
                // Icon
                ZStack {
                    Circle()
                        .fill(transaction.type.color.opacity(isPressed ? 0.25 : 0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: transaction.type.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(transaction.type.color)
                        .scaleEffect(iconBounce)
                }
                
                // Details
                VStack(alignment: .leading, spacing: 4) {
                    Text(transaction.type.rawValue.capitalized)
                        .font(PiggyTheme.Typography.bodyBold)
                        .foregroundColor(.white)
                    
                    HStack(spacing: 6) {
                        statusBadge
                        
                        Text(transaction.timestamp.formatted(date: .abbreviated, time: .shortened))
                            .font(PiggyTheme.Typography.caption)
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
                
                Spacer()
                
                // Amount
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(transaction.type == .deposit ? "+" : "-")\(String(format: "%.4f", transaction.amount))")
                        .font(PiggyTheme.Typography.bodyBold)
                        .foregroundColor(transaction.type == .deposit ? PiggyTheme.Colors.accentGreen : .white)
                    
                    Text(transaction.asset.symbol)
                        .font(PiggyTheme.Typography.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(isPressed ? 0.4 : 0.2))
                    .offset(x: isPressed ? 3 : 0)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: PiggyTheme.CornerRadius.medium)
                    .fill(PiggyTheme.Colors.surface.opacity(isPressed ? 0.7 : 0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: PiggyTheme.CornerRadius.medium)
                            .stroke(transaction.type.color.opacity(isPressed ? 0.15 : 0.04), lineWidth: 0.5)
                    )
            )
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPressed)
        }
        .buttonStyle(TransactionButtonStyle(isPressed: $isPressed))
    }
    
    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
            
            Text(transaction.status.rawValue.capitalized)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(statusColor)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(statusColor.opacity(0.12))
        )
    }
    
    private var statusColor: Color {
        switch transaction.status {
        case .confirmed: return PiggyTheme.Colors.accentGreen
        case .pending: return PiggyTheme.Colors.warning
        case .failed: return PiggyTheme.Colors.error
        }
    }
}

struct TransactionButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, newValue in
                isPressed = newValue
            }
    }
}
