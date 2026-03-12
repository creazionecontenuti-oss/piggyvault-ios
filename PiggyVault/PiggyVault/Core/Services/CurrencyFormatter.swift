import Foundation

final class CurrencyFormatter {
    static let shared = CurrencyFormatter()
    
    private let numberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        f.groupingSeparator = Locale.current.groupingSeparator
        f.decimalSeparator = Locale.current.decimalSeparator
        return f
    }()
    
    private let cryptoFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 6
        f.groupingSeparator = Locale.current.groupingSeparator
        f.decimalSeparator = Locale.current.decimalSeparator
        return f
    }()
    
    private let compactFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 2
        f.groupingSeparator = Locale.current.groupingSeparator
        f.decimalSeparator = Locale.current.decimalSeparator
        return f
    }()
    
    func formatFiat(_ value: Double, currencySymbol: String = "$") -> String {
        let formatted = numberFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
        return "\(currencySymbol)\(formatted)"
    }
    
    func formatCrypto(_ value: Double, symbol: String) -> String {
        let formatted = cryptoFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.6f", value)
        return "\(formatted) \(symbol)"
    }
    
    func formatCompact(_ value: Double) -> String {
        if value >= 1_000_000 {
            let m = value / 1_000_000
            return compactFormatter.string(from: NSNumber(value: m)).map { "\($0)M" } ?? "\(Int(m))M"
        } else if value >= 1_000 {
            let k = value / 1_000
            return compactFormatter.string(from: NSNumber(value: k)).map { "\($0)K" } ?? "\(Int(k))K"
        }
        return numberFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }
    
    func formatPercentage(_ value: Double) -> String {
        return "\(Int(value * 100))%"
    }
}
