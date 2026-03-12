import SwiftUI

struct GlassCard<Content: View>: View {
    let content: Content
    var padding: CGFloat = PiggyTheme.Spacing.md
    var cornerRadius: CGFloat = PiggyTheme.CornerRadius.large
    
    init(
        padding: CGFloat = PiggyTheme.Spacing.md,
        cornerRadius: CGFloat = PiggyTheme.CornerRadius.large,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.padding = padding
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        content
            .padding(padding)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(PiggyTheme.Colors.surface.opacity(0.6))
                    
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.08),
                                    Color.white.opacity(0.02)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.15),
                                    Color.white.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            )
    }
}

struct GlassButton: View {
    let title: String
    let icon: String?
    let gradient: LinearGradient
    let action: () -> Void
    
    @State private var isPressed = false
    
    init(
        title: String,
        icon: String? = nil,
        gradient: LinearGradient = PiggyTheme.Colors.primaryGradient,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.gradient = gradient
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            HapticManager.mediumTap()
            withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) {
                    isPressed = false
                }
                action()
            }
        }) {
            HStack(spacing: 10) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .symbolEffect(.bounce, value: isPressed)
                }
                Text(title)
                    .font(PiggyTheme.Typography.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: PiggyTheme.CornerRadius.medium)
                        .fill(gradient)
                    
                    RoundedRectangle(cornerRadius: PiggyTheme.CornerRadius.medium)
                        .fill(Color.white.opacity(isPressed ? 0.2 : 0))
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: PiggyTheme.CornerRadius.medium)
                    .stroke(Color.white.opacity(isPressed ? 0.35 : 0.2), lineWidth: 1)
            )
            .shadow(color: PiggyTheme.Colors.primary.opacity(isPressed ? 0.15 : 0.4), radius: isPressed ? 4 : 12, y: isPressed ? 2 : 6)
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .rotation3DEffect(.degrees(isPressed ? 2 : 0), axis: (x: 1, y: 0, z: 0))
        }
        .buttonStyle(.plain)
    }
}
