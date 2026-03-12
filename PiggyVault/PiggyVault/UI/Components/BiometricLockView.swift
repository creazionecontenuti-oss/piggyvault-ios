import SwiftUI

struct BiometricLockView: View {
    let onAuthenticate: () -> Void
    @State private var logoScale: CGFloat = 0.8
    @State private var lockRotation: Double = -10
    @State private var showButton = false
    @State private var pulseOpacity: Double = 0.0
    @State private var isAuthenticating = false
    @State private var bgTextOffset: CGFloat = 0
    @State private var bgTextScale: CGFloat = 0.9
    
    var body: some View {
        ZStack {
            PiggyTheme.Colors.background
                .ignoresSafeArea()
            
            // Repeating PiggyVault text background
            GeometryReader { geo in
                let rows = 14
                let cols = 5
                let cellW: CGFloat = 180
                let cellH: CGFloat = 52
                
                ZStack {
                    ForEach(0..<rows, id: \.self) { row in
                        ForEach(0..<cols, id: \.self) { col in
                            Text("PiggyVault")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(PiggyTheme.Colors.primary.opacity(0.04))
                                .rotationEffect(.degrees(-25))
                                .position(
                                    x: CGFloat(col) * cellW + (row.isMultiple(of: 2) ? cellW * 0.5 : 0) + bgTextOffset * 0.5,
                                    y: CGFloat(row) * cellH + bgTextOffset * 0.3
                                )
                        }
                    }
                }
                .frame(width: geo.size.width + 200, height: geo.size.height + 200)
                .offset(x: -100, y: -100)
                .scaleEffect(bgTextScale)
                .blendMode(.screen)
            }
            .ignoresSafeArea()
            
            // Subtle background glow
            Circle()
                .fill(PiggyTheme.Colors.primary.opacity(pulseOpacity))
                .frame(width: 250, height: 250)
                .blur(radius: 80)
            
            VStack(spacing: 32) {
                Spacer()
                
                // Lock icon with animation
                ZStack {
                    Circle()
                        .fill(PiggyTheme.Colors.primary.opacity(0.08))
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(PiggyTheme.Colors.primaryGradient)
                        .scaleEffect(logoScale)
                        .rotationEffect(.degrees(lockRotation))
                }
                
                VStack(spacing: 8) {
                    Text("PiggyVault")
                        .font(PiggyTheme.Typography.title)
                        .foregroundColor(.white)
                    
                    Text("biometric.locked".localized)
                        .font(PiggyTheme.Typography.body)
                        .foregroundColor(.white.opacity(0.5))
                }
                
                Spacer()
                
                // Unlock button
                if showButton {
                    Button {
                        HapticManager.mediumTap()
                        isAuthenticating = true
                        onAuthenticate()
                    } label: {
                        HStack(spacing: 12) {
                            if isAuthenticating {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "faceid")
                                    .font(.system(size: 22))
                            }
                            Text("biometric.unlock".localized)
                                .font(PiggyTheme.Typography.bodyBold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            Capsule()
                                .fill(PiggyTheme.Colors.primaryGradient)
                        )
                        .shadow(color: PiggyTheme.Colors.primary.opacity(0.3), radius: 12, y: 4)
                    }
                    .disabled(isAuthenticating)
                    .padding(.horizontal, 40)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                Spacer().frame(height: 40)
            }
        }
        .onAppear {
            isAuthenticating = false
            withAnimation(.spring(response: 0.7, dampingFraction: 0.6)) {
                logoScale = 1.0
                lockRotation = 0
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.4)) {
                showButton = true
            }
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                pulseOpacity = 0.06
            }
            withAnimation(.linear(duration: 15.0).repeatForever(autoreverses: false)) {
                bgTextOffset = 180
            }
            withAnimation(.easeInOut(duration: 5.0).repeatForever(autoreverses: true)) {
                bgTextScale = 1.1
            }
        }
    }
}
