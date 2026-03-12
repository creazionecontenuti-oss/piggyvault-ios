import SwiftUI

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    let speed: Double
    
    init(speed: Double = 1.5) {
        self.speed = speed
    }
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        colors: [
                            .clear,
                            Color.white.opacity(0.12),
                            Color.white.opacity(0.2),
                            Color.white.opacity(0.12),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: -geometry.size.width + (phase * geometry.size.width * 3))
                }
            )
            .clipped()
            .onAppear {
                withAnimation(
                    .linear(duration: speed)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmer(speed: Double = 1.5) -> some View {
        modifier(ShimmerModifier(speed: speed))
    }
}

struct ShimmerPlaceholder: View {
    let width: CGFloat?
    let height: CGFloat
    let cornerRadius: CGFloat
    
    init(width: CGFloat? = nil, height: CGFloat = 16, cornerRadius: CGFloat = 8) {
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(PiggyTheme.Colors.surfaceLight)
            .frame(width: width, height: height)
            .shimmer()
    }
}

struct PiggyListShimmer: View {
    var body: some View {
        VStack(spacing: 16) {
            // Stats row shimmer
            HStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { _ in
                    ShimmerPlaceholder(height: 80, cornerRadius: 12)
                }
            }
            
            // Piggy card shimmers
            ForEach(0..<3, id: \.self) { index in
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        ShimmerPlaceholder(width: 40, height: 40, cornerRadius: 20)
                        VStack(alignment: .leading, spacing: 6) {
                            ShimmerPlaceholder(width: 140, height: 14)
                            ShimmerPlaceholder(width: 90, height: 10)
                        }
                        Spacer()
                        ShimmerPlaceholder(width: 60, height: 14)
                    }
                    ShimmerPlaceholder(height: 6, cornerRadius: 3)
                    HStack {
                        ShimmerPlaceholder(width: 80, height: 10)
                        Spacer()
                        ShimmerPlaceholder(width: 50, height: 10)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(PiggyTheme.Colors.surface.opacity(0.4))
                )
            }
        }
    }
}

struct DashboardShimmer: View {
    var body: some View {
        VStack(spacing: PiggyTheme.Spacing.lg) {
            // Balance shimmer
            VStack(spacing: PiggyTheme.Spacing.sm) {
                ShimmerPlaceholder(width: 120, height: 14)
                ShimmerPlaceholder(width: 200, height: 42)
                ShimmerPlaceholder(width: 100, height: 12)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, PiggyTheme.Spacing.xl)
            
            // Quick actions shimmer
            HStack(spacing: PiggyTheme.Spacing.md) {
                ForEach(0..<3, id: \.self) { _ in
                    ShimmerPlaceholder(height: 72, cornerRadius: 16)
                }
            }
            
            // Assets shimmer
            VStack(spacing: PiggyTheme.Spacing.sm) {
                ForEach(0..<3, id: \.self) { _ in
                    ShimmerPlaceholder(height: 64, cornerRadius: 12)
                }
            }
            
            // Piggy banks shimmer
            VStack(spacing: PiggyTheme.Spacing.sm) {
                ForEach(0..<2, id: \.self) { _ in
                    ShimmerPlaceholder(height: 120, cornerRadius: 16)
                }
            }
        }
        .padding(.horizontal, PiggyTheme.Spacing.md)
    }
}
