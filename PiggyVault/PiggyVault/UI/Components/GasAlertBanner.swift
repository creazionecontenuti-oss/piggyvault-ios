import SwiftUI

struct GasAlertBanner: View {
    @EnvironmentObject var appState: AppState
    @State private var appear = false
    @State private var pulseGlow = false
    @State private var copiedFeedback = false
    
    var onBuyETH: (() -> Void)?
    
    private var ownerAddress: String {
        appState.userWallet?.address ?? ""
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Animated warning icon
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(pulseGlow ? 0.3 : 0.15))
                        .frame(width: 40, height: 40)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulseGlow)
                    
                    Image(systemName: "fuelpump.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.orange)
                        .symbolEffect(.pulse, isActive: pulseGlow)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("gas.alert.title".localized)
                        .font(PiggyTheme.Typography.captionBold)
                        .foregroundColor(.white)
                    
                    Text("gas.alert.description".localized)
                        .font(PiggyTheme.Typography.caption)
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(3)
                }
                
                Spacer()
            }
            
            // Two action buttons: Copy Address + Buy ETH
            HStack(spacing: 10) {
                // Copy owner address button
                Button {
                    HapticManager.mediumTap()
                    UIPasteboard.general.string = ownerAddress
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        copiedFeedback = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { copiedFeedback = false }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: copiedFeedback ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                        Text(copiedFeedback ? "gas.alert.copied".localized : "gas.alert.copy_address".localized)
                            .font(PiggyTheme.Typography.captionBold)
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                            )
                    )
                }
                
                // Buy ETH on Mt Pelerin button
                Button {
                    HapticManager.mediumTap()
                    onBuyETH?()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "creditcard.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                        Text("gas.alert.buy_eth".localized)
                            .font(PiggyTheme.Typography.captionBold)
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [Color.orange, Color.orange.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.orange.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.orange.opacity(0.25), lineWidth: 1)
                )
        )
        .opacity(appear ? 1 : 0)
        .offset(y: appear ? 0 : 10)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                appear = true
            }
            pulseGlow = true
        }
    }
}
