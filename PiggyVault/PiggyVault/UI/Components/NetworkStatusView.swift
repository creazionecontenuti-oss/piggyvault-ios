import SwiftUI

struct NetworkStatusView: View {
    @ObservedObject var networkMonitor = NetworkMonitor.shared
    @State private var isPulsing = false
    @State private var isExpanded = false
    
    var body: some View {
        HStack(spacing: 8) {
            // Base logo + animated status dot
            ZStack(alignment: .bottomTrailing) {
                Image("BaseLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                
                Circle()
                    .fill(statusColor)
                    .frame(width: 7, height: 7)
                    .overlay(Circle().stroke(Color.black.opacity(0.4), lineWidth: 1))
                    .shadow(color: statusColor.opacity(0.6), radius: isPulsing ? 4 : 1)
                    .scaleEffect(isPulsing ? 1.2 : 1.0)
                    .offset(x: 2, y: 2)
            }
            .animation(
                networkMonitor.status.isOnline
                ? .easeInOut(duration: 1.5).repeatForever(autoreverses: true)
                : .easeInOut(duration: 0.5).repeatForever(autoreverses: true),
                value: isPulsing
            )
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 2) {
                    Text(statusText)
                        .font(PiggyTheme.Typography.caption)
                        .foregroundColor(.white.opacity(0.8))
                    
                    if networkMonitor.status.isOnline {
                        Text(latencyText)
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .leading)),
                    removal: .opacity
                ))
            }
        }
        .padding(.horizontal, isExpanded ? 12 : 8)
        .padding(.vertical, isExpanded ? 8 : 6)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(statusColor.opacity(0.3), lineWidth: 1)
                )
        )
        .onTapGesture {
            HapticManager.lightTap()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isExpanded.toggle()
            }
        }
        .onAppear {
            isPulsing = true
        }
    }
    
    private var statusColor: Color {
        switch networkMonitor.status {
        case .connected:
            return PiggyTheme.Colors.accentGreen
        case .disconnected:
            return .red
        case .checking:
            return .orange
        case .blockchainError:
            return .yellow
        }
    }
    
    private var statusText: String {
        switch networkMonitor.status {
        case .connected:
            return "network.connected".localized
        case .disconnected:
            return "network.disconnected".localized
        case .checking:
            return "network.checking".localized
        case .blockchainError:
            return "network.error".localized
        }
    }
    
    private var latencyText: String {
        let ms = Int(networkMonitor.latency * 1000)
        return "Base L2 · \(ms)ms · #\(networkMonitor.lastBlockNumber)"
    }
}

// Compact inline version for dashboard header
struct NetworkDot: View {
    @ObservedObject var networkMonitor = NetworkMonitor.shared
    @State private var isPulsing = false
    
    var body: some View {
        Circle()
            .fill(dotColor)
            .frame(width: 6, height: 6)
            .shadow(color: dotColor.opacity(0.5), radius: isPulsing ? 4 : 1)
            .scaleEffect(isPulsing ? 1.2 : 1.0)
            .animation(
                .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear { isPulsing = true }
    }
    
    private var dotColor: Color {
        switch networkMonitor.status {
        case .connected: return PiggyTheme.Colors.accentGreen
        case .disconnected: return .red
        case .checking: return .orange
        case .blockchainError: return .yellow
        }
    }
}

// Banner that slides down when disconnected
struct NetworkBanner: View {
    @ObservedObject var networkMonitor = NetworkMonitor.shared
    @State private var showBanner = false
    
    var body: some View {
        VStack {
            if showBanner {
                HStack(spacing: 10) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text("network.offline_banner".localized)
                        .font(PiggyTheme.Typography.captionBold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button {
                        HapticManager.lightTap()
                        Task {
                            await networkMonitor.checkBlockchainHealth()
                        }
                    } label: {
                        Text("network.retry".localized)
                            .font(PiggyTheme.Typography.captionBold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(.white.opacity(0.2)))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.red.opacity(0.85))
                )
                .padding(.horizontal, 16)
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            }
            
            Spacer()
        }
        .onChange(of: networkMonitor.status) { _, newStatus in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                showBanner = !newStatus.isOnline
            }
        }
    }
}
