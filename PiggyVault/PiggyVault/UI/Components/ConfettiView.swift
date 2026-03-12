import SwiftUI

struct ConfettiPiece: Identifiable {
    let id = UUID()
    var position: CGPoint
    var color: Color
    var rotation: Double
    var scale: CGFloat
    var opacity: Double
    var velocity: CGSize
    var angularVelocity: Double
}

struct ConfettiView: View {
    @State private var pieces: [ConfettiPiece] = []
    @State private var timer: Timer?
    let isActive: Bool
    let particleCount: Int
    
    init(isActive: Bool, particleCount: Int = 60) {
        self.isActive = isActive
        self.particleCount = particleCount
    }
    
    private let colors: [Color] = [
        PiggyTheme.Colors.primary,
        PiggyTheme.Colors.accent,
        PiggyTheme.Colors.accentGreen,
        PiggyTheme.Colors.accentGold,
        PiggyTheme.Colors.piggyPink,
        PiggyTheme.Colors.piggyBlue,
        PiggyTheme.Colors.piggyOrange,
        .white
    ]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(pieces) { piece in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(piece.color)
                        .frame(width: 8 * piece.scale, height: 12 * piece.scale)
                        .rotationEffect(.degrees(piece.rotation))
                        .position(piece.position)
                        .opacity(piece.opacity)
                }
            }
            .onChange(of: isActive) { _, active in
                if active {
                    spawnConfetti(in: geometry.size)
                }
            }
        }
        .allowsHitTesting(false)
    }
    
    private func spawnConfetti(in size: CGSize) {
        pieces = (0..<particleCount).map { _ in
            ConfettiPiece(
                position: CGPoint(
                    x: CGFloat.random(in: size.width * 0.2...size.width * 0.8),
                    y: -20
                ),
                color: colors.randomElement()!,
                rotation: Double.random(in: 0...360),
                scale: CGFloat.random(in: 0.5...1.5),
                opacity: 1.0,
                velocity: CGSize(
                    width: CGFloat.random(in: -3...3),
                    height: CGFloat.random(in: 2...8)
                ),
                angularVelocity: Double.random(in: -10...10)
            )
        }
        
        HapticManager.success()
        
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            DispatchQueue.main.async {
                updatePieces(in: size)
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            timer?.invalidate()
            timer = nil
            withAnimation(.easeOut(duration: 0.5)) {
                pieces = []
            }
        }
    }
    
    private func updatePieces(in size: CGSize) {
        for i in pieces.indices {
            pieces[i].position.x += pieces[i].velocity.width
            pieces[i].position.y += pieces[i].velocity.height
            pieces[i].velocity.height += 0.15 // gravity
            pieces[i].velocity.width *= 0.99 // drag
            pieces[i].rotation += pieces[i].angularVelocity
            
            if pieces[i].position.y > size.height * 0.8 {
                pieces[i].opacity = max(0, pieces[i].opacity - 0.02)
            }
        }
    }
}
