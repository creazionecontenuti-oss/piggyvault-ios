import SwiftUI

struct BuyFlowSheet: View {
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
                        if viewModel.isLoadingQuote {
                            quoteLoadingView
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        } else if let quote = viewModel.quote {
                            quoteResultView(quote)
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        } else if let error = viewModel.quoteError {
                            quoteErrorView(error)
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        }
                        
                        // Confirm button
                        if viewModel.quote != nil && !viewModel.isLoadingQuote {
                            GlassButton(
                                title: "deposit.buy.confirm".localized,
                                icon: "checkmark.shield.fill"
                            ) {
                                viewModel.confirmBuy(walletAddress: walletAddress)
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
            .navigationTitle("deposit.buy.title".localized)
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
            viewModel.resetBuyFlow()
        }
    }
    
    // MARK: - Amount Section
    
    private var amountSection: some View {
        GlassCard(padding: 24) {
            VStack(spacing: 16) {
                Text("deposit.buy.enter_amount".localized)
                    .font(PiggyTheme.Typography.subheadline)
                    .foregroundColor(.white.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack(alignment: .center, spacing: 8) {
                    Text(viewModel.selectedFiat.symbol)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.4))
                    
                    TextField("0", text: $viewModel.buyAmount)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .keyboardType(.decimalPad)
                        .focused($amountFocused)
                        .onChange(of: viewModel.buyAmount) {
                            viewModel.fetchQuote()
                        }
                        .multilineTextAlignment(.leading)
                        .tint(PiggyTheme.Colors.primary)
                }
                
                // Quick amount buttons
                HStack(spacing: 12) {
                    ForEach([50, 100, 250, 500], id: \.self) { amount in
                        quickAmountButton(amount)
                    }
                }
            }
        }
    }
    
    private func quickAmountButton(_ amount: Int) -> some View {
        Button {
            HapticManager.lightTap()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                viewModel.buyAmount = String(amount)
            }
            viewModel.fetchQuote()
        } label: {
            Text("\(viewModel.selectedFiat.symbol)\(amount)")
                .font(PiggyTheme.Typography.captionBold)
                .foregroundColor(viewModel.buyAmount == String(amount) ? .white : .white.opacity(0.6))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(viewModel.buyAmount == String(amount)
                              ? PiggyTheme.Colors.primary.opacity(0.3)
                              : PiggyTheme.Colors.surface)
                )
                .overlay(
                    Capsule()
                        .stroke(viewModel.buyAmount == String(amount)
                                ? PiggyTheme.Colors.primary.opacity(0.5)
                                : Color.white.opacity(0.08), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Currency Section
    
    private var currencySection: some View {
        HStack(spacing: 12) {
            // Fiat picker
            GlassCard(padding: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("deposit.buy.pay_with".localized)
                        .font(PiggyTheme.Typography.caption)
                        .foregroundColor(.white.opacity(0.5))
                    
                    Menu {
                        ForEach(FiatCurrency.allCases) { fiat in
                            Button {
                                withAnimation(.spring(response: 0.3)) {
                                    viewModel.selectedFiat = fiat
                                }
                                viewModel.fetchQuote()
                            } label: {
                                Label("\(fiat.flag) \(fiat.rawValue)", systemImage: viewModel.selectedFiat == fiat ? "checkmark" : "")
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text(viewModel.selectedFiat.flag)
                                .font(.system(size: 22))
                            Text(viewModel.selectedFiat.rawValue)
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
            
            // Crypto picker
            GlassCard(padding: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("deposit.buy.receive".localized)
                        .font(PiggyTheme.Typography.caption)
                        .foregroundColor(.white.opacity(0.5))
                    
                    Menu {
                        ForEach(AssetType.allCases) { asset in
                            Button {
                                withAnimation(.spring(response: 0.3)) {
                                    viewModel.selectedCrypto = asset
                                }
                                viewModel.fetchQuote()
                            } label: {
                                Label(asset.symbol, systemImage: viewModel.selectedCrypto == asset ? "checkmark" : "")
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: viewModel.selectedCrypto.icon)
                                .font(.system(size: 22))
                                .foregroundColor(viewModel.selectedCrypto.color)
                            Text(viewModel.selectedCrypto.symbol)
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
                
                // You pay
                quoteRow(
                    label: "deposit.buy.you_pay".localized,
                    value: String(format: "%@ %.2f", viewModel.selectedFiat.symbol, quote.sourceAmount)
                )
                
                // You receive
                quoteRow(
                    label: "deposit.buy.you_receive".localized,
                    value: String(format: "%.6f %@", quote.destAmount, viewModel.selectedCrypto.symbol),
                    highlight: true
                )
                
                // Fees
                let totalFees = quote.networkFee + quote.fixFee
                if totalFees > 0 {
                    quoteRow(
                        label: "deposit.buy.fees".localized,
                        value: String(format: "%@ %.2f", viewModel.selectedFiat.symbol, totalFees)
                    )
                }
                
                // Rate
                if quote.sourceAmount > 0 && quote.destAmount > 0 {
                    let rate = quote.sourceAmount / quote.destAmount
                    quoteRow(
                        label: "deposit.buy.rate".localized,
                        value: String(format: "1 %@ = %@ %.2f", viewModel.selectedCrypto.symbol, viewModel.selectedFiat.symbol, rate)
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
    
    private func quoteErrorView(_ error: String) -> some View {
        GlassCard(padding: 16) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(PiggyTheme.Colors.warning)
                Text(error)
                    .font(PiggyTheme.Typography.caption)
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
            }
        }
    }
    
    // MARK: - Info Section
    
    private var infoSection: some View {
        GlassCard(padding: 16) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "shield.checkered")
                        .foregroundColor(PiggyTheme.Colors.accent)
                    Text("deposit.buy.info_title".localized)
                        .font(PiggyTheme.Typography.captionBold)
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    infoBullet("deposit.buy.info_1".localized)
                    infoBullet("deposit.buy.info_2".localized)
                    infoBullet("deposit.buy.info_3".localized)
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
