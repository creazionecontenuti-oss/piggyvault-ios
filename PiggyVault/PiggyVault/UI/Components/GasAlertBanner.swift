import SwiftUI

struct GasAlertBanner: View {
    @EnvironmentObject var appState: AppState
    @State private var appear = false
    @State private var pulseGlow = false
    
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
                        .lineLimit(2)
                }
                
                Spacer()
            }
            
            // Error message if swap failed
            if let error = appState.gasSwapError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(PiggyTheme.Colors.error)
                    Text(error)
                        .font(PiggyTheme.Typography.caption)
                        .foregroundColor(PiggyTheme.Colors.error.opacity(0.9))
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Swap button
            Button {
                HapticManager.mediumTap()
                appState.manualSwapForGas()
            } label: {
                HStack(spacing: 8) {
                    if appState.gasSwapInProgress {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                        Text("gas.alert.swapping".localized)
                            .font(PiggyTheme.Typography.captionBold)
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                        Text("gas.alert.swap_button".localized)
                            .font(PiggyTheme.Typography.captionBold)
                            .foregroundColor(.white)
                    }
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
            .disabled(appState.gasSwapInProgress)
            .opacity(appState.gasSwapInProgress ? 0.7 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: appState.gasSwapInProgress)
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
