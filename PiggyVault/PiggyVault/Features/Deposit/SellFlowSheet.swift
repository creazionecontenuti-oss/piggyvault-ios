import SwiftUI

struct SellFlowSheet: View {
    @ObservedObject var viewModel: DepositViewModel
    let walletAddress: String
    @Environment(\.dismiss) private var dismiss
    @State private var showContent = false
    @FocusState private var amountFocused: Bool
    
    var body: some View {
        NavigationStack {
            ZStack {
                PiggyTheme.Colors.background.ignoresSafeArea()
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Amount Input
                        amountSection
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : 20)
                        
                        // Currency selectors
                        currencySection
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : 30)
                        
                        // Quote result
                        if viewModel.isLoadingSellQuote {
                            quoteLoadingView
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        } else if let quote = viewModel.sellQuote {
                            quoteResultView(quote)
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        }
                        
                        // Confirm button
                        if viewModel.sellQuote != nil && !viewModel.isLoadingSellQuote {
                            GlassButton(
                                title: "deposit.sell.confirm".localized,
                                icon: "arrow.up.circle.fill",
                                gradient: LinearGradient(
                                    colors: [Color(hex: "FF6B6B"), Color(hex: "EE5A24")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            ) {
                                viewModel.confirmSell(walletAddress: walletAddress)
                            }
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        
                        // Info
                        infoSection
                            .opacity(showContent ? 1 : 0)
                        
                        Color.clear.frame(height: 20)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            }
            .navigationTitle("deposit.sell.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        HapticManager.lightTap()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(PiggyTheme.Colors.textSecondary)
                    }
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(PiggyTheme.Colors.surface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) {
                showContent = true
            }
            amountFocused = true
        }
        .onDisappear {
            viewModel.resetSellFlow()
        }
    }
    
    // MARK: - Amount Section
    
    private var amountSection: some View {
        GlassCard(padding: 24) {
            VStack(spacing: 16) {
                Text("deposit.sell.enter_amount".localized)
                    .font(PiggyTheme.Typography.subheadline)
                    .foregroundColor(.white.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: viewModel.sellSourceCrypto.icon)
                        .font(.system(size: 30))
                        .foregroundColor(viewModel.sellSourceCrypto.color)
                    
                    TextField("0", text: $viewModel.sellAmount)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .keyboardType(.decimalPad)
                        .focused($amountFocused)
                        .onChange(of: viewModel.sellAmount) {
                            viewModel.fetchSellQuote()
                        }
                        .multilineTextAlignment(.leading)
                        .tint(PiggyTheme.Colors.primary)
                    
                    Text(viewModel.sellSourceCrypto.symbol)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
        }
    }
    
    // MARK: - Currency Section
    
    private var currencySection: some View {
        HStack(spacing: 12) {
            // Crypto source picker
            GlassCard(padding: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("deposit.sell.from".localized)
                        .font(PiggyTheme.Typography.caption)
                        .foregroundColor(.white.opacity(0.5))
                    
                    Menu {
                        ForEach(AssetType.allCases) { asset in
                            Button {
                                withAnimation(.spring(response: 0.3)) {
                                    viewModel.sellSourceCrypto = asset
                                }
                                viewModel.fetchSellQuote()
                            } label: {
                                Label(asset.symbol, systemImage: viewModel.sellSourceCrypto == asset ? "checkmark" : "")
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: viewModel.sellSourceCrypto.icon)
                                .font(.system(size: 22))
                                .foregroundColor(viewModel.sellSourceCrypto.color)
                            Text(viewModel.sellSourceCrypto.symbol)
                                .font(PiggyTheme.Typography.headline)
                                .foregroundColor(.white)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white.opacity(0.4))
                        }
                    }
                }
            }
            
            // Arrow
            Image(systemName: "arrow.right")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white.opacity(0.3))
            
            // Fiat destination picker
            GlassCard(padding: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("deposit.sell.to_bank".localized)
                        .font(PiggyTheme.Typography.caption)
                        .foregroundColor(.white.opacity(0.5))
                    
                    Menu {
                        ForEach(FiatCurrency.allCases) { fiat in
                            Button {
                                withAnimation(.spring(response: 0.3)) {
                                    viewModel.sellDestFiat = fiat
                                }
                                viewModel.fetchSellQuote()
                            } label: {
                                Label("\(fiat.flag) \(fiat.rawValue)", systemImage: viewModel.sellDestFiat == fiat ? "checkmark" : "")
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text(viewModel.sellDestFiat.flag)
                                .font(.system(size: 22))
                            Text(viewModel.sellDestFiat.rawValue)
                                .font(PiggyTheme.Typography.headline)
                                .foregroundColor(.white)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white.opacity(0.4))
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Quote Views
    
    private var quoteLoadingView: some View {
        GlassCard(padding: 20) {
            HStack(spacing: 12) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: PiggyTheme.Colors.primary))
                Text("deposit.buy.loading_quote".localized)
                    .font(PiggyTheme.Typography.body)
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
            }
        }
    }
    
    private func quoteResultView(_ quote: MtPelerinQuote) -> some View {
        GlassCard(padding: 20) {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(PiggyTheme.Colors.accentGreen)
                    Text("deposit.buy.quote_ready".localized)
                        .font(PiggyTheme.Typography.headline)
                        .foregroundColor(.white)
                    Spacer()
                }
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                // You send
                quoteRow(
                    label: "deposit.sell.you_send".localized,
                    value: String(format: "%.6f %@", quote.sourceAmount, viewModel.sellSourceCrypto.symbol)
                )
                
                // You receive
                quoteRow(
                    label: "deposit.sell.you_receive_bank".localized,
                    value: String(format: "%@ %.2f", viewModel.sellDestFiat.symbol, quote.destAmount),
                    highlight: true
                )
                
                // Fees
                let totalFees = quote.networkFee + quote.fixFee
                if totalFees > 0 {
                    quoteRow(
                        label: "deposit.buy.fees".localized,
                        value: String(format: "%@ %.2f", viewModel.sellDestFiat.symbol, totalFees)
                    )
                }
            }
        }
    }
    
    private func quoteRow(label: String, value: String, highlight: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(PiggyTheme.Typography.body)
                .foregroundColor(.white.opacity(0.5))
            Spacer()
            Text(value)
                .font(highlight ? PiggyTheme.Typography.headline : PiggyTheme.Typography.body)
                .foregroundColor(highlight ? PiggyTheme.Colors.accentGreen : .white)
        }
    }
    
    // MARK: - Info Section
    
    private var infoSection: some View {
        GlassCard(padding: 16) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "banknote")
                        .foregroundColor(PiggyTheme.Colors.accent)
                    Text("deposit.sell.info_title".localized)
                        .font(PiggyTheme.Typography.captionBold)
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    infoBullet("deposit.sell.info_1".localized)
                    infoBullet("deposit.sell.info_2".localized)
                }
            }
        }
    }
    
    private func infoBullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Circle()
                .fill(PiggyTheme.Colors.accent.opacity(0.5))
                .frame(width: 4, height: 4)
                .padding(.top, 6)
            Text(text)
                .font(PiggyTheme.Typography.caption)
                .foregroundColor(.white.opacity(0.5))
        }
    }
}
