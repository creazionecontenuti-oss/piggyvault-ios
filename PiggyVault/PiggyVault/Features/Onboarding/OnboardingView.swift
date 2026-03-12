import SwiftUI

struct OnboardingPage {
    let icon: String
    let titleKey: String
    let descriptionKey: String
    let gradient: LinearGradient
}

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentPage = 0
    @State private var showContent = false
    @State private var dragOffset: CGFloat = 0
    @State private var direction: Int = 1
    
    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "lock.shield.fill",
            titleKey: "onboarding.page1.title",
            descriptionKey: "onboarding.page1.description",
            gradient: LinearGradient(colors: [Color(hex: "6C5CE7"), Color(hex: "00D2FF")], startPoint: .topLeading, endPoint: .bottomTrailing)
        ),
        OnboardingPage(
            icon: "banknote.fill",
            titleKey: "onboarding.page2.title",
            descriptionKey: "onboarding.page2.description",
            gradient: LinearGradient(colors: [Color(hex: "00E676"), Color(hex: "4ECDC4")], startPoint: .topLeading, endPoint: .bottomTrailing)
        ),
        OnboardingPage(
            icon: "clock.badge.checkmark.fill",
            titleKey: "onboarding.page3.title",
            descriptionKey: "onboarding.page3.description",
            gradient: LinearGradient(colors: [Color(hex: "FFD700"), Color(hex: "F39C12")], startPoint: .topLeading, endPoint: .bottomTrailing)
        ),
        OnboardingPage(
            icon: "globe",
            titleKey: "onboarding.page4.title",
            descriptionKey: "onboarding.page4.description",
            gradient: LinearGradient(colors: [Color(hex: "FF6B9D"), Color(hex: "C44569")], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
    ]
    
    var body: some View {
        ZStack {
            PiggyTheme.Colors.background
                .ignoresSafeArea()
            
            // Animated background orbs
            BackgroundOrbs()
            
            VStack(spacing: 0) {
                // Page content with parallax gesture
                ZStack {
                    ForEach(0..<pages.count, id: \.self) { index in
                        if index == currentPage {
                            OnboardingPageView(page: pages[index], isActive: true, direction: direction)
                                .offset(x: dragOffset)
                                .transition(.asymmetric(
                                    insertion: .move(edge: direction > 0 ? .trailing : .leading).combined(with: .opacity),
                                    removal: .move(edge: direction > 0 ? .leading : .trailing).combined(with: .opacity)
                                ))
                        }
                    }
                }
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            dragOffset = value.translation.width * 0.4
                        }
                        .onEnded { value in
                            let threshold: CGFloat = 60
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                                dragOffset = 0
                            }
                            if value.translation.width < -threshold && currentPage < pages.count - 1 {
                                HapticManager.lightTap()
                                direction = 1
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                                    currentPage += 1
                                }
                            } else if value.translation.width > threshold && currentPage > 0 {
                                HapticManager.lightTap()
                                direction = -1
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                                    currentPage -= 1
                                }
                            }
                        }
                )
                .animation(.spring(response: 0.5, dampingFraction: 0.85), value: currentPage)
                
                // Bottom section
                VStack(spacing: 24) {
                    // Animated progress bar + page indicators
                    VStack(spacing: 12) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.08))
                                    .frame(height: 3)
                                Capsule()
                                    .fill(PiggyTheme.Colors.primaryGradient)
                                    .frame(width: geo.size.width * CGFloat(currentPage + 1) / CGFloat(pages.count), height: 3)
                                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: currentPage)
                            }
                        }
                        .frame(height: 3)
                        
                        HStack(spacing: 8) {
                            ForEach(0..<pages.count, id: \.self) { index in
                                Button {
                                    HapticManager.selection()
                                    direction = index > currentPage ? 1 : -1
                                    withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                                        currentPage = index
                                    }
                                } label: {
                                    Capsule()
                                        .fill(currentPage == index ? PiggyTheme.Colors.primary : Color.white.opacity(0.2))
                                        .frame(width: currentPage == index ? 28 : 8, height: 8)
                                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: currentPage)
                                }
                            }
                        }
                    }
                    
                    if currentPage == pages.count - 1 {
                        GlassButton(
                            title: "onboarding.get_started".localized,
                            icon: "arrow.right",
                            action: {
                                HapticManager.heavyTap()
                                appState.completeOnboarding()
                            }
                        )
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .opacity
                        ))
                    } else {
                        HStack {
                            Button {
                                HapticManager.lightTap()
                                appState.completeOnboarding()
                            } label: {
                                Text("onboarding.skip".localized)
                                    .font(PiggyTheme.Typography.callout)
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            
                            Spacer()
                            
                            Button {
                                HapticManager.lightTap()
                                direction = 1
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                    currentPage += 1
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Text("onboarding.next".localized)
                                        .font(PiggyTheme.Typography.bodyBold)
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 14, weight: .bold))
                                }
                                .foregroundColor(PiggyTheme.Colors.primary)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 14)
                                .background(
                                    Capsule()
                                        .fill(PiggyTheme.Colors.primary.opacity(0.15))
                                )
                            }
                        }
                        .transition(.opacity)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                showContent = true
            }
        }
    }
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    let isActive: Bool
    var direction: Int = 1
    
    @State private var iconScale: CGFloat = 0.5
    @State private var iconRotation: Double = -30
    @State private var contentOffset: CGFloat = 30
    @State private var contentOpacity: Double = 0
    @State private var glowOpacity: Double = 0.15
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(page.gradient.opacity(glowOpacity))
                    .frame(width: 180, height: 180)
                    .blur(radius: 20)
                
                Circle()
                    .fill(page.gradient.opacity(0.08))
                    .frame(width: 140, height: 140)
                
                Image(systemName: page.icon)
                    .font(.system(size: 64))
                    .foregroundStyle(page.gradient)
                    .scaleEffect(iconScale)
                    .rotationEffect(.degrees(iconRotation))
                    .symbolEffect(.pulse, options: .repeating, value: isActive)
            }
            
            VStack(spacing: 16) {
                Text(page.titleKey.localized)
                    .font(PiggyTheme.Typography.title)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text(page.descriptionKey.localized)
                    .font(PiggyTheme.Typography.body)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .offset(y: contentOffset)
            .opacity(contentOpacity)
            .padding(.horizontal, 20)
            
            Spacer()
            Spacer()
        }
        .onChange(of: isActive) { _, active in
            if active {
                animateIn()
            } else {
                resetAnimations()
            }
        }
        .onAppear {
            if isActive { animateIn() }
        }
    }
    
    private func animateIn() {
        iconScale = 0.5
        iconRotation = -30
        contentOffset = 30
        contentOpacity = 0
        glowOpacity = 0.15
        
        withAnimation(.spring(response: 0.7, dampingFraction: 0.6).delay(0.1)) {
            iconScale = 1.0
            iconRotation = 0
        }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2)) {
            contentOffset = 0
            contentOpacity = 1
        }
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(0.5)) {
            glowOpacity = 0.35
        }
    }
    
    private func resetAnimations() {
        iconScale = 0.5
        iconRotation = -30
        contentOffset = 30
        contentOpacity = 0
        glowOpacity = 0.15
    }
}

struct BackgroundOrbs: View {
    @State private var offset1 = CGSize(width: -50, height: -100)
    @State private var offset2 = CGSize(width: 80, height: 150)
    @State private var offset3 = CGSize(width: -30, height: 80)
    
    var body: some View {
        ZStack {
            Circle()
                .fill(PiggyTheme.Colors.primary.opacity(0.08))
                .frame(width: 300, height: 300)
                .blur(radius: 60)
                .offset(offset1)
            
            Circle()
                .fill(PiggyTheme.Colors.accent.opacity(0.06))
                .frame(width: 250, height: 250)
                .blur(radius: 50)
                .offset(offset2)
            
            Circle()
                .fill(PiggyTheme.Colors.piggyPink.opacity(0.05))
                .frame(width: 200, height: 200)
                .blur(radius: 40)
                .offset(offset3)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                offset1 = CGSize(width: 50, height: 100)
            }
            withAnimation(.easeInOut(duration: 10).repeatForever(autoreverses: true)) {
                offset2 = CGSize(width: -80, height: -100)
            }
            withAnimation(.easeInOut(duration: 7).repeatForever(autoreverses: true)) {
                offset3 = CGSize(width: 60, height: -60)
            }
        }
    }
}
