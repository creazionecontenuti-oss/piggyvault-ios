import SwiftUI

enum PiggyTheme {
    
    enum Colors {
        static let background = Color(hex: "0A0E1A")
        static let surface = Color(hex: "141928")
        static let surfaceLight = Color(hex: "1E2438")
        static let primary = Color(hex: "6C5CE7")
        static let primaryLight = Color(hex: "A29BFE")
        static let accent = Color(hex: "00D2FF")
        static let accentGreen = Color(hex: "00E676")
        static let accentGold = Color(hex: "FFD700")
        static let warning = Color(hex: "FFA726")
        static let error = Color(hex: "EF5350")
        static let textPrimary = Color.white
        static let textSecondary = Color.white.opacity(0.7)
        static let textTertiary = Color.white.opacity(0.4)
        static let cardGradientStart = Color(hex: "1A1F35")
        static let cardGradientEnd = Color(hex: "0D1120")
        
        static let piggyPink = Color(hex: "FF6B9D")
        static let piggyBlue = Color(hex: "4ECDC4")
        static let piggyPurple = Color(hex: "9B59B6")
        static let piggyOrange = Color(hex: "F39C12")
        
        static var primaryGradient: LinearGradient {
            LinearGradient(
                colors: [primary, accent],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        
        static var goldGradient: LinearGradient {
            LinearGradient(
                colors: [Color(hex: "F7DC6F"), accentGold, Color(hex: "D4A017")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        
        static var cardGradient: LinearGradient {
            LinearGradient(
                colors: [cardGradientStart, cardGradientEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    enum Typography {
        static let largeTitle = Font.system(size: 34, weight: .bold, design: .rounded)
        static let title = Font.system(size: 28, weight: .bold, design: .rounded)
        static let title2 = Font.system(size: 22, weight: .semibold, design: .rounded)
        static let title3 = Font.system(size: 20, weight: .semibold, design: .rounded)
        static let headline = Font.system(size: 17, weight: .semibold, design: .rounded)
        static let body = Font.system(size: 17, weight: .regular, design: .rounded)
        static let bodyBold = Font.system(size: 17, weight: .semibold, design: .rounded)
        static let callout = Font.system(size: 16, weight: .regular, design: .rounded)
        static let subheadline = Font.system(size: 15, weight: .regular, design: .rounded)
        static let footnote = Font.system(size: 13, weight: .regular, design: .rounded)
        static let caption = Font.system(size: 12, weight: .regular, design: .rounded)
        static let captionBold = Font.system(size: 12, weight: .semibold, design: .rounded)
        static let balanceLarge = Font.system(size: 42, weight: .bold, design: .monospaced)
        static let balanceMedium = Font.system(size: 28, weight: .bold, design: .monospaced)
        static let balanceSmall = Font.system(size: 20, weight: .semibold, design: .monospaced)
    }
    
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }
    
    enum CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xl: CGFloat = 24
        static let full: CGFloat = 100
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
