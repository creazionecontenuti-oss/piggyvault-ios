import SwiftUI

enum FiatCurrency: String, CaseIterable, Identifiable {
    case eur = "EUR"
    case usd = "USD"
    case chf = "CHF"
    case gbp = "GBP"
    
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .eur: return "€"
        case .usd: return "$"
        case .chf: return "CHF"
        case .gbp: return "£"
        }
    }
    var flag: String {
        switch self {
        case .eur: return "🇪🇺"
        case .usd: return "🇺🇸"
        case .chf: return "🇨🇭"
        case .gbp: return "🇬🇧"
        }
    }
}

@MainActor
final class DepositViewModel: ObservableObject {
    // UI State
    @Published var showReceiveAddress = false
    @Published var showWebView = false
    @Published var showBuyFlow = false
    @Published var showSellFlow = false
    @Published var showCopiedFeedback = false
    @Published var webViewURL: URL?
    
    // Buy flow state
    @Published var buyAmount: String = ""
    @Published var selectedFiat: FiatCurrency = .eur
    @Published var selectedCrypto: AssetType = .usdc
    @Published var quote: MtPelerinQuote?
    @Published var isLoadingQuote = false
    @Published var quoteError: String?
    
    // Sell flow state
    @Published var sellAmount: String = ""
    @Published var sellDestFiat: FiatCurrency = .eur
    @Published var sellSourceCrypto: AssetType = .usdc
    @Published var sellQuote: MtPelerinQuote?
    @Published var isLoadingSellQuote = false
    
    let mtPelerinService = MtPelerinService()
    
    private var quoteTask: Task<Void, Never>?
    
    // MARK: - Quote fetching with debounce
    
    func fetchQuote() {
        quoteTask?.cancel()
        guard let amount = Double(buyAmount), amount > 0 else {
            quote = nil
            quoteError = nil
            return
        }
        
        isLoadingQuote = true
        quoteError = nil
        
        quoteTask = Task {
            // Debounce 500ms
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            
            do {
                let q = try await mtPelerinService.getQuote(
                    sourceAmount: amount,
                    sourceCurrency: selectedFiat.rawValue,
                    destCurrency: selectedCrypto.symbol,
                    isCardPayment: false
                )
                if !Task.isCancelled {
                    self.quote = q
                    self.isLoadingQuote = false
                }
            } catch {
                if !Task.isCancelled {
                    self.quoteError = error.localizedDescription
                    self.quote = nil
                    self.isLoadingQuote = false
                }
            }
        }
    }
    
    func fetchSellQuote() {
        quoteTask?.cancel()
        guard let amount = Double(sellAmount), amount > 0 else {
            sellQuote = nil
            return
        }
        
        isLoadingSellQuote = true
        
        quoteTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            
            do {
                let q = try await mtPelerinService.getSellQuote(
                    sourceAmount: amount,
                    sourceCurrency: sellSourceCrypto.symbol,
                    destCurrency: sellDestFiat.rawValue
                )
                if !Task.isCancelled {
                    self.sellQuote = q
                    self.isLoadingSellQuote = false
                }
            } catch {
                if !Task.isCancelled {
                    self.sellQuote = nil
                    self.isLoadingSellQuote = false
                }
            }
        }
    }
    
    // MARK: - Open widget (locked down)
    
    func confirmBuy(walletAddress: String) {
        Task {
            let amount = Double(buyAmount)
            let lang = currentLanguageCode()
            let url = await mtPelerinService.getBuyURL(
                destinationAddress: walletAddress,
                outputCurrency: selectedCrypto.symbol,
                sourceCurrency: selectedFiat.rawValue,
                amount: amount,
                language: lang
            )
            webViewURL = url
            showBuyFlow = false
            showWebView = true
        }
    }
    
    func confirmSell(walletAddress: String) {
        Task {
            let amount = Double(sellAmount)
            let lang = currentLanguageCode()
            let url = await mtPelerinService.getSellURL(
                sourceAddress: walletAddress,
                inputCurrency: sellSourceCrypto.symbol,
                destCurrency: sellDestFiat.rawValue,
                amount: amount,
                language: lang
            )
            webViewURL = url
            showSellFlow = false
            showWebView = true
        }
    }
    
    // Legacy direct open (for card button shortcut)
    func openMtPelerinBuy(walletAddress: String, asset: AssetType = .usdc) {
        showBuyFlow = true
    }
    
    func openMtPelerinSell(walletAddress: String, asset: AssetType = .usdc) {
        showSellFlow = true
    }
    
    func resetBuyFlow() {
        buyAmount = ""
        quote = nil
        quoteError = nil
        isLoadingQuote = false
    }
    
    func resetSellFlow() {
        sellAmount = ""
        sellQuote = nil
        isLoadingSellQuote = false
    }
    
    private func currentLanguageCode() -> String {
        let lang = Locale.current.language.languageCode?.identifier ?? "en"
        let supported = ["en", "fr", "de", "it", "es", "pt"]
        return supported.contains(lang) ? lang : "en"
    }
}
