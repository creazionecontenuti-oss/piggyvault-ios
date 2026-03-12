import SwiftUI

struct PiggyCard: View {
    let piggyBank: PiggyBank
    var onTap: (() -> Void)? = nil
    
    @State private var isPressed = false
    @State private var shimmerOffset: CGFloat = -200
    @State private var appeared = false
    
    var body: some View {
        Button(action: {
            HapticManager.lightTap()
            withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) {
                    isPressed = false
                }
                onTap?()
            }
        }) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(piggyBank.name)
                            .font(PiggyTheme.Typography.headline)
                            .foregroundColor(.white)
                        
                        HStack(spacing: 6) {
                            Image(systemName: piggyBank.lockType.icon)
                                .font(.system(size: 12))
                            Text(piggyBank.lockType.displayName)
                                .font(PiggyTheme.Typography.caption)
                        }
                        .foregroundColor(.white.opacity(0.6))
                    }
                    
                    Spacer()
                    
                    ProgressRing(
                        progress: piggyBank.progress,
                        size: 52,
                        lineWidth: 5,
                        gradient: piggyBank.color.gradient,
                        showPercentage: true
                    )
                }
                
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(piggyBank.asset.symbol)
                            .font(PiggyTheme.Typography.caption)
                            .foregroundColor(piggyBank.asset.color)
                        
                        Text(piggyBank.formattedAmount)
                            .font(PiggyTheme.Typography.balanceSmall)
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        if let target = piggyBank.targetAmount {
                            Text("piggy.target".localized)
                                .font(PiggyTheme.Typography.caption)
                                .foregroundColor(.white.opacity(0.5))
                            Text("\(String(format: "%.2f", target)) \(piggyBank.asset.symbol)")
                                .font(PiggyTheme.Typography.captionBold)
                                .foregroundColor(.white.opacity(0.7))
                        } else if let remaining = piggyBank.remainingTime {
                            Text("piggy.remaining".localized)
                                .font(PiggyTheme.Typography.caption)
                                .foregroundColor(.white.opacity(0.5))
                            Text(remaining)
                                .font(PiggyTheme.Typography.captionBold)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
                
                if piggyBank.isUnlockable {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(PiggyTheme.Colors.accentGreen)
                        Text("piggy.ready_to_unlock".localized)
                            .font(PiggyTheme.Typography.captionBold)
                            .foregroundColor(PiggyTheme.Colors.accentGreen)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(PiggyTheme.Colors.accentGreen.opacity(0.15))
                    )
                }
            }
            .padding(PiggyTheme.Spacing.md)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: PiggyTheme.CornerRadius.large)
                        .fill(PiggyTheme.Colors.surface)
                    
                    RoundedRectangle(cornerRadius: PiggyTheme.CornerRadius.large)
                        .fill(
                            LinearGradient(
                                colors: [
                                    piggyBank.color.primary.opacity(0.12),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    RoundedRectangle(cornerRadius: PiggyTheme.CornerRadius.large)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    piggyBank.color.primary.opacity(0.3),
                                    piggyBank.color.primary.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                    
                    // Shimmer effect
                    RoundedRectangle(cornerRadius: PiggyTheme.CornerRadius.large)
                        .fill(
                            LinearGradient(
                                colors: [
                                    .clear,
                                    Color.white.opacity(0.03),
                                    .clear
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .offset(x: shimmerOffset)
                        .mask(
                            RoundedRectangle(cornerRadius: PiggyTheme.CornerRadius.large)
                        )
                }
            )
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .rotation3DEffect(.degrees(isPressed ? 1.5 : 0), axis: (x: 1, y: 0, z: 0))
        }
        .buttonStyle(.plain)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                appeared = true
            }
            withAnimation(
                .linear(duration: 3.0)
                .repeatForever(autoreverses: false)
                .delay(Double.random(in: 0...2))
            ) {
                shimmerOffset = 400
            }
        }
    }
}

struct AssetRow: View {
    let balance: AssetBalance
    
    @State private var appeared = false
    @State private var isPressed = false
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(balance.asset.color.opacity(isPressed ? 0.25 : 0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: balance.asset.icon)
                    .font(.system(size: 20))
                    .foregroundColor(balance.asset.color)
                    .scaleEffect(isPressed ? 1.15 : 1.0)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(balance.asset.symbol)
                    .font(PiggyTheme.Typography.bodyBold)
                    .foregroundColor(.white)
                
                Text(balance.asset.name)
                    .font(PiggyTheme.Typography.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(balance.formattedBalance)
                    .font(PiggyTheme.Typography.bodyBold)
                    .foregroundColor(.white)
                
                Text(balance.formattedFiatValue)
                    .font(PiggyTheme.Typography.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, PiggyTheme.Spacing.md)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: PiggyTheme.CornerRadius.medium)
                .fill(PiggyTheme.Colors.surface.opacity(isPressed ? 0.7 : 0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: PiggyTheme.CornerRadius.medium)
                        .stroke(balance.asset.color.opacity(isPressed ? 0.15 : 0.04), lineWidth: 0.5)
                )
        )
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPressed)
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .opacity(appeared ? 1 : 0)
        .offset(x: appeared ? 0 : 20)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) {
                appeared = true
            }
        }
    }
}
