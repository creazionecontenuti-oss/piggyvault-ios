import SwiftUI

enum ToastType {
    case success
    case error
    case warning
    case info
    
    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .success: return PiggyTheme.Colors.accentGreen
        case .error: return PiggyTheme.Colors.error
        case .warning: return PiggyTheme.Colors.warning
        case .info: return PiggyTheme.Colors.accent
        }
    }
}

struct ToastData: Equatable {
    let type: ToastType
    let message: String
    let id: UUID
    
    init(type: ToastType, message: String) {
        self.type = type
        self.message = message
        self.id = UUID()
    }
    
    static func == (lhs: ToastData, rhs: ToastData) -> Bool {
        lhs.id == rhs.id
    }
}

struct ToastView: View {
    let toast: ToastData
    @State private var isVisible = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: toast.type.icon)
                .font(.system(size: 20))
                .foregroundColor(toast.type.color)
                .symbolEffect(.bounce, value: isVisible)
            
            Text(toast.message)
                .font(PiggyTheme.Typography.body)
                .foregroundColor(.white)
                .lineLimit(2)
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(PiggyTheme.Colors.surface.opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(toast.type.color.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: toast.type.color.opacity(0.15), radius: 12, y: 4)
                .shadow(color: Color.black.opacity(0.3), radius: 8, y: 2)
        )
        .padding(.horizontal, 16)
        .offset(y: isVisible ? 0 : -100)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            switch toast.type {
            case .success: HapticManager.success()
            case .error: HapticManager.error()
            case .warning: HapticManager.warning()
            case .info: HapticManager.lightTap()
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                isVisible = true
            }
        }
    }
    
    func hide() {
        withAnimation(.easeIn(duration: 0.25)) {
            isVisible = false
        }
    }
}

struct ToastModifier: ViewModifier {
    @Binding var toast: ToastData?
    let duration: Double
    
    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let toast = toast {
                    ToastView(toast: toast)
                        .padding(.top, 50)
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        ))
                        .zIndex(999)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                                withAnimation(.easeIn(duration: 0.25)) {
                                    self.toast = nil
                                }
                            }
                        }
                        .onTapGesture {
                            withAnimation(.easeIn(duration: 0.25)) {
                                self.toast = nil
                            }
                        }
                }
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: toast)
    }
}

extension View {
    func toast(_ toast: Binding<ToastData?>, duration: Double = 3.0) -> some View {
        modifier(ToastModifier(toast: toast, duration: duration))
    }
}
