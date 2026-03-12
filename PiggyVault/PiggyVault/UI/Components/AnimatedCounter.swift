import SwiftUI

struct AnimatedCounterInt: View {
    let value: Int
    let font: Font
    let color: Color
    var duration: Double = 0.6
    
    @State private var displayedValue: Int = 0
    @State private var hasAppeared = false
    
    var body: some View {
        Text("\(displayedValue)")
            .font(font)
            .foregroundColor(color)
            .contentTransition(.numericText(value: Double(displayedValue)))
            .onAppear {
                guard !hasAppeared else { return }
                hasAppeared = true
                withAnimation(.spring(response: duration, dampingFraction: 0.85)) {
                    displayedValue = value
                }
            }
            .onChange(of: value) { _, newValue in
                withAnimation(.spring(response: duration, dampingFraction: 0.85)) {
                    displayedValue = newValue
                }
            }
    }
}
