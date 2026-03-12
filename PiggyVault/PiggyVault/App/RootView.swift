import SwiftUI

struct RootView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ZStack {
            PiggyTheme.Colors.background
                .ignoresSafeArea()
            
            switch appState.currentScreen {
            case .splash:
                SplashView()
                    .transition(.opacity)
                
            case .onboarding:
                OnboardingView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                
            case .auth:
                AuthView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                
            case .creatingWallet:
                WalletCreationView()
                    .transition(.opacity)
                
            case .dashboard:
                MainTabView()
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.9).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.85), value: appState.currentScreen)
        .overlay {
            if appState.isLocked {
                BiometricLockView {
                    appState.unlockApp()
                }
                .transition(.opacity)
                .zIndex(100)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: appState.isLocked)
    }
}

struct SplashView: View {
    @State private var logoScale: CGFloat = 0.5
    @State private var logoOpacity: Double = 0.0
    @State private var ringRotation: Double = 0
    @State private var innerRingRotation: Double = 0
    @State private var subtitleOpacity: Double = 0
    @State private var particlePhase: CGFloat = 0
    @State private var bgTextOffset: CGFloat = 0
    @State private var bgTextScale: CGFloat = 0.85
    @State private var bgTextOpacity: Double = 0
    
    var body: some View {
        ZStack {
            PiggyTheme.Colors.background
                .ignoresSafeArea()
            
            // Repeating PiggyVault text background (oblique, blend, moving)
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
                                .foregroundColor(PiggyTheme.Colors.primary.opacity(0.06))
                                .rotationEffect(.degrees(-25))
                                .position(
                                    x: CGFloat(col) * cellW + (row.isMultiple(of: 2) ? cellW * 0.5 : 0) + bgTextOffset * 0.6,
                                    y: CGFloat(row) * cellH + bgTextOffset * 0.35
                                )
                        }
                    }
                }
                .frame(width: geo.size.width + 200, height: geo.size.height + 200)
                .offset(x: -100, y: -100)
                .scaleEffect(bgTextScale)
                .opacity(bgTextOpacity)
                .blendMode(.screen)
            }
            .ignoresSafeArea()
            
            // Floating particles
            ForEach(0..<6, id: \.self) { i in
                Circle()
                    .fill(PiggyTheme.Colors.primary.opacity(0.15))
                    .frame(width: CGFloat.random(in: 4...8), height: CGFloat.random(in: 4...8))
                    .offset(
                        x: cos(particlePhase + Double(i) * .pi / 3) * 100,
                        y: sin(particlePhase + Double(i) * .pi / 3) * 100
                    )
                    .blur(radius: 2)
            }
            
            // Outer ring
            Circle()
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            PiggyTheme.Colors.primary.opacity(0.0),
                            PiggyTheme.Colors.primary.opacity(0.5),
                            PiggyTheme.Colors.accent,
                            PiggyTheme.Colors.primary.opacity(0.0)
                        ]),
                        center: .center
                    ),
                    lineWidth: 3
                )
                .frame(width: 140, height: 140)
                .rotationEffect(.degrees(ringRotation))
            
            // Inner subtle ring
            Circle()
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            PiggyTheme.Colors.accent.opacity(0.0),
                            PiggyTheme.Colors.accent.opacity(0.3),
                            PiggyTheme.Colors.primary.opacity(0.2),
                            PiggyTheme.Colors.accent.opacity(0.0)
                        ]),
                        center: .center
                    ),
                    lineWidth: 1.5
                )
                .frame(width: 160, height: 160)
                .rotationEffect(.degrees(innerRingRotation))
            
            VStack(spacing: 16) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [PiggyTheme.Colors.primary, PiggyTheme.Colors.accent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("PiggyVault")
                    .font(PiggyTheme.Typography.largeTitle)
                    .foregroundColor(.white)
                
                Text("loading.tagline".localized)
                    .font(PiggyTheme.Typography.caption)
                    .foregroundColor(.white.opacity(0.4))
                    .opacity(subtitleOpacity)
            }
            .scaleEffect(logoScale)
            .opacity(logoOpacity)
        }
        .onAppear {
            // Logo entrance
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.8).delay(0.6)) {
                subtitleOpacity = 1.0
            }
            // Rings
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                ringRotation = 360
            }
            withAnimation(.linear(duration: 3.5).repeatForever(autoreverses: false)) {
                innerRingRotation = -360
            }
            // Particles
            withAnimation(.linear(duration: 6.0).repeatForever(autoreverses: false)) {
                particlePhase = .pi * 2
            }
            // Background text: fade in
            withAnimation(.easeOut(duration: 1.2).delay(0.3)) {
                bgTextOpacity = 1.0
            }
            // Background text: oblique linear movement
            withAnimation(.linear(duration: 12.0).repeatForever(autoreverses: false)) {
                bgTextOffset = 180
            }
            // Background text: grow in size
            withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true).delay(0.5)) {
                bgTextScale = 1.15
            }
        }
    }
}

struct WalletCreationView: View {
    @EnvironmentObject var appState: AppState
    @State private var shieldScale: CGFloat = 0.6
    @State private var shieldOpacity: Double = 0
    @State private var ringRotation: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var stepIndex: Int = 0
    
    private let stepIcons = ["key.fill", "shield.lefthalf.filled", "gearshape.2.fill", "checkmark.seal.fill"]
    
    var body: some View {
        ZStack {
            PiggyTheme.Colors.background
                .ignoresSafeArea()
            
            BackgroundOrbs()
            
            VStack(spacing: 40) {
                Spacer()
                
                ZStack {
                    // Pulsing glow
                    Circle()
                        .fill(PiggyTheme.Colors.primary.opacity(0.15))
                        .frame(width: 180, height: 180)
                        .scaleEffect(pulseScale)
                        .blur(radius: 30)
                    
                    // Background ring track
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 8)
                        .frame(width: 140, height: 140)
                    
                    // Progress ring
                    Circle()
                        .trim(from: 0, to: appState.loadingProgress)
                        .stroke(
                            AngularGradient(
                                colors: [PiggyTheme.Colors.primary, PiggyTheme.Colors.accent, PiggyTheme.Colors.primary],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 140, height: 140)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.5), value: appState.loadingProgress)
                    
                    // Spinning outer accent ring
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [
                                    PiggyTheme.Colors.accent.opacity(0),
                                    PiggyTheme.Colors.accent.opacity(0.3),
                                    PiggyTheme.Colors.accent.opacity(0)
                                ],
                                center: .center
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 160, height: 160)
                        .rotationEffect(.degrees(ringRotation))
                    
                    // Center content
                    VStack(spacing: 6) {
                        Image(systemName: currentStepIcon)
                            .font(.system(size: 28, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [PiggyTheme.Colors.primary, PiggyTheme.Colors.accent],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .contentTransition(.symbolEffect(.replace))
                            .animation(.easeInOut(duration: 0.3), value: currentStepIcon)
                        
                        Text("\(Int(appState.loadingProgress * 100))%")
                            .font(PiggyTheme.Typography.title2)
                            .foregroundColor(.white)
                            .contentTransition(.numericText())
                            .animation(.easeInOut, value: appState.loadingProgress)
                    }
                    .scaleEffect(shieldScale)
                    .opacity(shieldOpacity)
                }
                
                VStack(spacing: 14) {
                    Text(appState.loadingMessage)
                        .font(PiggyTheme.Typography.headline)
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .animation(.easeInOut(duration: 0.3), value: appState.loadingMessage)
                    
                    // Step dots
                    HStack(spacing: 8) {
                        ForEach(0..<4) { i in
                            Circle()
                                .fill(i <= currentStep ? PiggyTheme.Colors.primary : Color.white.opacity(0.15))
                                .frame(width: 8, height: 8)
                                .scaleEffect(i == currentStep ? 1.3 : 1.0)
                                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: currentStep)
                        }
                    }
                    .padding(.top, 4)
                    
                    Text("loading.please_wait".localized)
                        .font(PiggyTheme.Typography.caption)
                        .foregroundColor(.white.opacity(0.4))
                        .padding(.top, 4)
                }
                
                Spacer()
            }
            .padding(.horizontal, 40)
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.65)) {
                shieldScale = 1.0
                shieldOpacity = 1.0
            }
            withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
                ringRotation = 360
            }
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseScale = 1.2
            }
        }
    }
    
    private var currentStep: Int {
        if appState.loadingProgress < 0.2 { return 0 }
        if appState.loadingProgress < 0.5 { return 1 }
        if appState.loadingProgress < 0.8 { return 2 }
        return 3
    }
    
    private var currentStepIcon: String {
        stepIcons[min(currentStep, stepIcons.count - 1)]
    }
}
