import Foundation

enum MtPelerinError: LocalizedError {
    case invalidResponse
    case apiError(String)
    case limitExceeded
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "error.onramp.invalid_response".localized
        case .apiError(let msg): return String(format: "error.onramp.api_error".localized, msg)
        case .limitExceeded: return "error.onramp.limit_exceeded".localized
        }
    }
}

struct MtPelerinQuote {
    let sourceCurrency: String
    let destCurrency: String
    let sourceAmount: Double
    let destAmount: Double
    let networkFee: Double
    let fixFee: Double
}

actor MtPelerinService {
    private let apiBaseURL = "https://api.mtpelerin.com"
    private let widgetBaseURL = "https://widget.mtpelerin.com"
    
    // Webview integration key (from Anthony @ Mt Pelerin)
    private let activationKey = "954139b2-ef3e-4914-82ea-33192d3f43d3"
    // Referral code for revenue sharing
    private let referralCode = "bb3ca0be-83a5-42a7-8e4f-5cb08892caf2"
    
    // Allowed assets on Base for PiggyVault
    private let allowedCryptos = "USDC,EURC,PAXG"
    private let allowedNetwork = "base_mainnet"
    
    private let session: URLSession
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Price Quote API
    
    func getQuote(
        sourceAmount: Double,
        sourceCurrency: String,
        destCurrency: String,
        isCardPayment: Bool = false
    ) async throws -> MtPelerinQuote {
        let url = URL(string: "\(apiBaseURL)/currency_rates/convert")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let body: [String: Any] = [
            "sourceCurrency": sourceCurrency,
            "destCurrency": destCurrency,
            "sourceAmount": sourceAmount,
            "sourceNetwork": "fiat",
            "destNetwork": allowedNetwork,
            "isCardPayment": isCardPayment ? "true" : "false"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw MtPelerinError.invalidResponse
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw MtPelerinError.invalidResponse
        }
        
        let fees = json["fees"] as? [String: Any] ?? [:]
        let networkFeeStr = fees["networkFee"] as? String ?? "0"
        let fixFee = fees["fixFee"] as? Double ?? 0
        let destAmountStr = json["destAmount"] as? String ?? "0"
        let srcAmount = json["sourceAmount"] as? Double ?? sourceAmount
        
        return MtPelerinQuote(
            sourceCurrency: sourceCurrency,
            destCurrency: destCurrency,
            sourceAmount: srcAmount,
            destAmount: Double(destAmountStr) ?? 0,
            networkFee: Double(networkFeeStr) ?? 0,
            fixFee: fixFee
        )
    }
    
    func getSellQuote(
        sourceAmount: Double,
        sourceCurrency: String,
        destCurrency: String
    ) async throws -> MtPelerinQuote {
        let url = URL(string: "\(apiBaseURL)/currency_rates/convert")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let body: [String: Any] = [
            "sourceCurrency": sourceCurrency,
            "destCurrency": destCurrency,
            "sourceAmount": sourceAmount,
            "sourceNetwork": allowedNetwork,
            "destNetwork": "fiat"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw MtPelerinError.invalidResponse
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw MtPelerinError.invalidResponse
        }
        
        let fees = json["fees"] as? [String: Any] ?? [:]
        let networkFeeStr = fees["networkFee"] as? String ?? "0"
        let fixFee = fees["fixFee"] as? Double ?? 0
        let destAmountStr = json["destAmount"] as? String ?? "0"
        
        return MtPelerinQuote(
            sourceCurrency: sourceCurrency,
            destCurrency: destCurrency,
            sourceAmount: sourceAmount,
            destAmount: Double(destAmountStr) ?? 0,
            networkFee: Double(networkFeeStr) ?? 0,
            fixFee: fixFee
        )
    }
    
    func getMinSellAmount(currency: String) async throws -> Double {
        let url = URL(string: "\(apiBaseURL)/currency_rates/sellLimits/\(currency)")!
        let (data, response) = try await session.data(for: URLRequest(url: url))
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw MtPelerinError.invalidResponse
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let limitStr = json["limit"] as? String else {
            return 50.0 // default minimum
        }
        return Double(limitStr) ?? 50.0
    }
    
    // MARK: - Widget URLs (locked down for anti-error UX)
    
    func getBuyURL(
        destinationAddress: String,
        outputCurrency: String = "USDC",
        sourceCurrency: String? = nil,
        amount: Double? = nil,
        paymentMethod: PaymentMethod? = nil,
        language: String = "en"
    ) -> URL {
        var components = URLComponents(string: widgetBaseURL)!
        var items: [URLQueryItem] = [
            // Mandatory activation key for webview
            URLQueryItem(name: "_ctkn", value: activationKey),
            URLQueryItem(name: "type", value: "direct-link"),
            URLQueryItem(name: "lang", value: language),
            // Lock to buy tab only
            URLQueryItem(name: "tab", value: "buy"),
            URLQueryItem(name: "tabs", value: "buy"),
            // Lock network to Base
            URLQueryItem(name: "net", value: allowedNetwork),
            URLQueryItem(name: "nets", value: allowedNetwork),
            // Lock allowed cryptos
            URLQueryItem(name: "crys", value: allowedCryptos),
            // Pre-fill destination
            URLQueryItem(name: "addr", value: destinationAddress),
            URLQueryItem(name: "bdc", value: outputCurrency),
            // Referral
            URLQueryItem(name: "rfr", value: referralCode),
            // Dark mode
            URLQueryItem(name: "mode", value: "dark")
        ]
        
        if let amount = amount, amount > 0 {
            items.append(URLQueryItem(name: "bsa", value: String(Int(amount))))
        }
        if let fiat = sourceCurrency {
            items.append(URLQueryItem(name: "bsc", value: fiat))
        }
        if let pm = paymentMethod {
            items.append(URLQueryItem(name: "pm", value: pm.rawValue))
        }
        
        components.queryItems = items
        return components.url!
    }
    
    /// Build a buy URL specifically for ETH on Base (for gas bootstrap).
    /// Destination is the OWNER address (not Safe), since the owner needs ETH for gas.
    func getBuyETHURL(
        ownerAddress: String,
        sourceCurrency: String? = nil,
        amount: Double? = nil,
        language: String = "en"
    ) -> URL {
        var components = URLComponents(string: widgetBaseURL)!
        var items: [URLQueryItem] = [
            URLQueryItem(name: "_ctkn", value: activationKey),
            URLQueryItem(name: "type", value: "direct-link"),
            URLQueryItem(name: "lang", value: language),
            URLQueryItem(name: "tab", value: "buy"),
            URLQueryItem(name: "tabs", value: "buy"),
            URLQueryItem(name: "net", value: allowedNetwork),
            URLQueryItem(name: "nets", value: allowedNetwork),
            // Lock to ETH only for gas purchase
            URLQueryItem(name: "crys", value: "ETH"),
            URLQueryItem(name: "addr", value: ownerAddress),
            URLQueryItem(name: "bdc", value: "ETH"),
            URLQueryItem(name: "rfr", value: referralCode),
            URLQueryItem(name: "mode", value: "dark")
        ]
        
        if let amount = amount, amount > 0 {
            items.append(URLQueryItem(name: "bsa", value: String(Int(amount))))
        }
        if let fiat = sourceCurrency {
            items.append(URLQueryItem(name: "bsc", value: fiat))
        }
        
        components.queryItems = items
        return components.url!
    }
    
    func getSellURL(
        sourceAddress: String,
        inputCurrency: String = "USDC",
        destCurrency: String? = nil,
        amount: Double? = nil,
        language: String = "en"
    ) -> URL {
        var components = URLComponents(string: widgetBaseURL)!
        var items: [URLQueryItem] = [
            URLQueryItem(name: "_ctkn", value: activationKey),
            URLQueryItem(name: "type", value: "direct-link"),
            URLQueryItem(name: "lang", value: language),
            // Lock to sell tab only
            URLQueryItem(name: "tab", value: "sell"),
            URLQueryItem(name: "tabs", value: "sell"),
            // Lock network to Base
            URLQueryItem(name: "net", value: allowedNetwork),
            URLQueryItem(name: "nets", value: allowedNetwork),
            URLQueryItem(name: "snet", value: allowedNetwork),
            // Lock allowed cryptos
            URLQueryItem(name: "crys", value: allowedCryptos),
            // Pre-fill source
            URLQueryItem(name: "addr", value: sourceAddress),
            URLQueryItem(name: "ssc", value: inputCurrency),
            // Referral
            URLQueryItem(name: "rfr", value: referralCode),
            // Dark mode
            URLQueryItem(name: "mode", value: "dark")
        ]
        
        if let amount = amount, amount > 0 {
            items.append(URLQueryItem(name: "ssa", value: String(Int(amount))))
        }
        if let fiat = destCurrency {
            items.append(URLQueryItem(name: "sdc", value: fiat))
        }
        
        components.queryItems = items
        return components.url!
    }
    
    enum PaymentMethod: String {
        case card = "card"
        case bankTransfer = "bank"
    }
}
