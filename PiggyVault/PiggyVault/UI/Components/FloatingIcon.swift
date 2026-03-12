import SwiftUI

struct FloatingIcon: View {
    let systemName: String
    let gradient: LinearGradient
    let bgColor: Color
    var size: CGFloat = 72
    
    @State private var floatOffset: CGFloat = 0
    @State private var glowOpacity: Double = 0.1
    
    var body: some View {
        ZStack {
            Circle()
                .fill(bgColor.opacity(glowOpacity))
                .frame(width: size + 20, height: size + 20)
                .blur(radius: 12)
            
            Circle()
                .fill(bgColor.opacity(0.1))
                .frame(width: size, height: size)
            
            Image(systemName: systemName)
                .font(.system(size: size * 0.44))
                .foregroundStyle(gradient)
        }
        .offset(y: floatOffset)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                floatOffset = -8
            }
            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                glowOpacity = 0.2
            }
        }
    }
}
