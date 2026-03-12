import SwiftUI

struct BlockchainErrorView: View {
    let errorMessage: String
    let retryAction: (() -> Void)?
    @State private var showContent = false
    @State private var pulseScale: CGFloat = 1.0
    
    init(errorMessage: String, retryAction: (() -> Void)? = nil) {
        self.errorMessage = errorMessage
        self.retryAction = retryAction
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Animated error icon
            ZStack {
                Circle()
                    .fill(PiggyTheme.Colors.error.opacity(0.08))
                    .frame(width: 140, height: 140)
                    .scaleEffect(pulseScale)
                
                Circle()
                    .fill(PiggyTheme.Colors.error.opacity(0.04))
                    .frame(width: 110, height: 110)
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [PiggyTheme.Colors.error, PiggyTheme.Colors.warning],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(showContent ? 1.0 : 0.5)
                    .rotationEffect(.degrees(showContent ? 0 : -15))
            }
            
            VStack(spacing: 12) {
                Text("network.error".localized)
                    .font(PiggyTheme.Typography.title2)
                    .foregroundColor(.white)
                
                Text(errorMessage)
                    .font(PiggyTheme.Typography.body)
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)
            }
            .offset(y: showContent ? 0 : 20)
            .opacity(showContent ? 1 : 0)
            
            if let retryAction = retryAction {
                Button {
                    HapticManager.mediumTap()
                    retryAction()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .bold))
                        Text("network.retry".localized)
                            .font(PiggyTheme.Typography.bodyBold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(
                        Capsule()
                            .fill(PiggyTheme.Colors.error.opacity(0.25))
                            .overlay(
                                Capsule()
                                    .stroke(PiggyTheme.Colors.error.opacity(0.4), lineWidth: 1)
                            )
                    )
                }
                .scaleEffect(showContent ? 1 : 0.8)
                .opacity(showContent ? 1 : 0)
            }
            
            Spacer()
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.6).delay(0.1)) {
                showContent = true
            }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                pulseScale = 1.15
            }
        }
    }
}

// MARK: - Inline Error Banner (for sections)

// MARK: - Safe Deployment Warning Banner

struct SafeDeploymentWarningBanner: View {
    let error: String
    let isRetrying: Bool
    let retryAction: () -> Void
    @State private var appear = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        VStack(spacing: 16) {
            // Warning icon
            ZStack {
                Circle()
                    .fill(PiggyTheme.Colors.warning.opacity(0.1))
                    .frame(width: 64, height: 64)
                    .scaleEffect(pulseScale)
                
                if isRetrying {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: PiggyTheme.Colors.warning))
                        .scaleEffect(1.2)
                } else {
                    Image(systemName: "exclamationmark.shield.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [PiggyTheme.Colors.warning, PiggyTheme.Colors.error],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
            
            VStack(spacing: 8) {
                Text("safe.deploy.failed.title".localized)
                    .font(PiggyTheme.Typography.headline)
                    .foregroundColor(.white)
                
                Text("safe.deploy.failed.desc".localized)
                    .font(PiggyTheme.Typography.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                
                // Error detail
                Text(error)
                    .font(PiggyTheme.Typography.caption)
                    .foregroundColor(PiggyTheme.Colors.error.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(PiggyTheme.Colors.error.opacity(0.08))
                    )
            }
            
            // Blocked notice
            HStack(spacing: 6) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 11))
                Text("safe.deploy.failed.blocked".localized)
                    .font(PiggyTheme.Typography.captionBold)
            }
            .foregroundColor(PiggyTheme.Colors.error.opacity(0.9))
            
            // Retry button
            Button {
                HapticManager.mediumTap()
                retryAction()
            } label: {
                HStack(spacing: 8) {
                    if isRetrying {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .bold))
                    }
                    Text(isRetrying ? "safe.deploy.retrying".localized : "safe.deploy.retry".localized)
                        .font(PiggyTheme.Typography.bodyBold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [PiggyTheme.Colors.warning, PiggyTheme.Colors.warning.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
            }
            .disabled(isRetrying)
            .opacity(isRetrying ? 0.7 : 1.0)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(PiggyTheme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(PiggyTheme.Colors.warning.opacity(0.3), lineWidth: 1)
                )
        )
        .opacity(appear ? 1 : 0)
        .offset(y: appear ? 0 : 20)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                appear = true
            }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                pulseScale = 1.12
            }
        }
    }
}

struct InlineErrorBanner: View {
    let message: String
    let retryAction: (() -> Void)?
    @State private var appear = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 18))
                .foregroundColor(PiggyTheme.Colors.error)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("network.error".localized)
                    .font(PiggyTheme.Typography.captionBold)
                    .foregroundColor(.white)
                
                Text(message)
                    .font(PiggyTheme.Typography.caption)
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(2)
            }
            
            Spacer()
            
            if let retryAction = retryAction {
                Button {
                    HapticManager.lightTap()
                    retryAction()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(PiggyTheme.Colors.error)
                        .padding(8)
                        .background(
                            Circle()
                                .fill(PiggyTheme.Colors.error.opacity(0.15))
                        )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(PiggyTheme.Colors.error.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(PiggyTheme.Colors.error.opacity(0.2), lineWidth: 1)
                )
        )
        .opacity(appear ? 1 : 0)
        .offset(y: appear ? 0 : 10)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                appear = true
            }
        }
    }
}
