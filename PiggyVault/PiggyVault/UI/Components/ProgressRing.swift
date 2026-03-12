import SwiftUI

struct ProgressRing: View {
    let progress: Double
    var size: CGFloat = 80
    var lineWidth: CGFloat = 8
    var gradient: LinearGradient = PiggyTheme.Colors.primaryGradient
    var showPercentage: Bool = true
    
    @State private var animatedProgress: Double = 0
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: lineWidth)
                .frame(width: size, height: size)
            
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    gradient,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 1.0, dampingFraction: 0.8), value: animatedProgress)
            
            if showPercentage {
                Text("\(Int(animatedProgress * 100))%")
                    .font(size > 60 ? PiggyTheme.Typography.headline : PiggyTheme.Typography.caption)
                    .foregroundColor(.white)
                    .contentTransition(.numericText())
            }
        }
        .onAppear {
            withAnimation(.spring(response: 1.2, dampingFraction: 0.8).delay(0.2)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                animatedProgress = newValue
            }
        }
    }
}

struct AnimatedCounter: View {
    let value: Double
    let prefix: String
    let suffix: String
    let font: Font
    let color: Color
    var decimals: Int
    var duration: Double
    
    @State private var displayValue: Double = 0
    @State private var hasAppeared = false
    
    init(
        value: Double,
        prefix: String = "",
        suffix: String = "",
        font: Font = PiggyTheme.Typography.balanceLarge,
        color: Color = .white,
        decimals: Int = 2,
        duration: Double = 0.8
    ) {
        self.value = value
        self.prefix = prefix
        self.suffix = suffix
        self.font = font
        self.color = color
        self.decimals = decimals
        self.duration = duration
    }
    
    var body: some View {
        Text("\(prefix)\(String(format: "%.\(decimals)f", displayValue))\(suffix)")
            .font(font)
            .foregroundColor(color)
            .contentTransition(.numericText(value: displayValue))
            .onAppear {
                guard !hasAppeared else { return }
                hasAppeared = true
                withAnimation(.spring(response: duration, dampingFraction: 0.85).delay(0.3)) {
                    displayValue = value
                }
            }
            .onChange(of: value) { _, newValue in
                withAnimation(.spring(response: duration, dampingFraction: 0.85)) {
                    displayValue = newValue
                }
            }
    }
}
