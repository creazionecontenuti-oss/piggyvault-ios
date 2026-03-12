import SwiftUI

struct CreatePiggyBankView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = CreatePiggyBankViewModel()
    @State private var showConfetti = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                PiggyTheme.Colors.background
                    .ignoresSafeArea()
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 28) {
                        // Step indicator
                        StepIndicator(currentStep: viewModel.currentStep, totalSteps: 4)
                            .padding(.top, 8)
                        
                        switch viewModel.currentStep {
                        case 1:
                            stepOneName
                        case 2:
                            stepTwoAsset
                        case 3:
                            stepThreeLockType
                        case 4:
                            stepFourConfirm
                        default:
                            EmptyView()
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
                
                // Loading overlay
                if viewModel.isCreating {
                    Color.black.opacity(0.6)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 24) {
                        ProgressRing(
                            progress: viewModel.creationProgress,
                            size: 100,
                            lineWidth: 8
                        )
                        
                        Text(viewModel.creationMessage)
                            .font(PiggyTheme.Typography.body)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
                
                // Confetti overlay
                ConfettiView(isActive: showConfetti)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
            .navigationTitle("piggy.create.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel".localized) { dismiss() }
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .alert("error.title".localized, isPresented: $viewModel.showError) {
                Button("ok".localized, role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage)
            }
        }
    }
    
    // MARK: - Step 1: Name & Color
    private var stepOneName: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("piggy.create.step1.title".localized)
                    .font(PiggyTheme.Typography.title2)
                    .foregroundColor(.white)
                
                Text("piggy.create.step1.subtitle".localized)
                    .font(PiggyTheme.Typography.body)
                    .foregroundColor(.white.opacity(0.5))
            }
            
            // Name input
            VStack(alignment: .leading, spacing: 8) {
                Text("piggy.create.name".localized)
                    .font(PiggyTheme.Typography.captionBold)
                    .foregroundColor(.white.opacity(0.6))
                
                TextField("piggy.create.name_placeholder".localized, text: $viewModel.name)
                    .font(PiggyTheme.Typography.body)
                    .foregroundColor(.white)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: PiggyTheme.CornerRadius.medium)
                            .fill(PiggyTheme.Colors.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: PiggyTheme.CornerRadius.medium)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    )
                    .tint(PiggyTheme.Colors.primary)
            }
            
            // Color picker
            VStack(alignment: .leading, spacing: 12) {
                Text("piggy.create.color".localized)
                    .font(PiggyTheme.Typography.captionBold)
                    .foregroundColor(.white.opacity(0.6))
                
                HStack(spacing: 16) {
                    ForEach(PiggyBankColor.allCases, id: \.rawValue) { color in
                        Button {
                            HapticManager.selection()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                viewModel.selectedColor = color
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(color.gradient)
                                    .frame(width: 44, height: 44)
                                
                                if viewModel.selectedColor == color {
                                    Circle()
                                        .stroke(Color.white, lineWidth: 3)
                                        .frame(width: 50, height: 50)
                                    
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                    }
                }
            }
            
            Spacer().frame(height: 20)
            
            GlassButton(title: "piggy.create.next".localized, icon: "arrow.right") {
                HapticManager.mediumTap()
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    viewModel.currentStep = 2
                }
            }
            .opacity(viewModel.name.isEmpty ? 0.5 : 1.0)
            .disabled(viewModel.name.isEmpty)
        }
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    }
    
    // MARK: - Step 2: Asset
    private var stepTwoAsset: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("piggy.create.step2.title".localized)
                    .font(PiggyTheme.Typography.title2)
                    .foregroundColor(.white)
                
                Text("piggy.create.step2.subtitle".localized)
                    .font(PiggyTheme.Typography.body)
                    .foregroundColor(.white.opacity(0.5))
            }
            
            VStack(spacing: 12) {
                ForEach(AssetType.allCases) { asset in
                    Button {
                        HapticManager.selection()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            viewModel.selectedAsset = asset
                        }
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(asset.color.opacity(0.15))
                                    .frame(width: 48, height: 48)
                                
                                Image(systemName: asset.icon)
                                    .font(.system(size: 22))
                                    .foregroundColor(asset.color)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(asset.symbol)
                                    .font(PiggyTheme.Typography.bodyBold)
                                    .foregroundColor(.white)
                                Text(asset.name)
                                    .font(PiggyTheme.Typography.caption)
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            
                            Spacer()
                            
                            if viewModel.selectedAsset == asset {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(PiggyTheme.Colors.accentGreen)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: PiggyTheme.CornerRadius.medium)
                                .fill(PiggyTheme.Colors.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: PiggyTheme.CornerRadius.medium)
                                        .stroke(
                                            viewModel.selectedAsset == asset ? asset.color.opacity(0.5) : Color.white.opacity(0.06),
                                            lineWidth: 1
                                        )
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            
            HStack(spacing: 12) {
                Button {
                    HapticManager.lightTap()
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        viewModel.currentStep = 1
                    }
                } label: {
                    Text("piggy.create.back".localized)
                        .font(PiggyTheme.Typography.bodyBold)
                        .foregroundColor(.white.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: PiggyTheme.CornerRadius.medium)
                                .fill(PiggyTheme.Colors.surface)
                        )
                }
                
                GlassButton(title: "piggy.create.next".localized, icon: "arrow.right") {
                    HapticManager.mediumTap()
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        viewModel.currentStep = 3
                    }
                }
            }
        }
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    }
    
    // MARK: - Step 3: Lock Type
    private var stepThreeLockType: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("piggy.create.step3.title".localized)
                    .font(PiggyTheme.Typography.title2)
                    .foregroundColor(.white)
                
                Text("piggy.create.step3.subtitle".localized)
                    .font(PiggyTheme.Typography.body)
                    .foregroundColor(.white.opacity(0.5))
            }
            
            VStack(spacing: 12) {
                ForEach(LockType.allCases) { lockType in
                    Button {
                        HapticManager.selection()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            viewModel.selectedLockType = lockType
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: lockType.icon)
                                    .font(.system(size: 24))
                                    .foregroundColor(PiggyTheme.Colors.primary)
                                
                                Text(lockType.displayName)
                                    .font(PiggyTheme.Typography.headline)
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                if viewModel.selectedLockType == lockType {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(PiggyTheme.Colors.accentGreen)
                                }
                            }
                            
                            Text(lockType.description)
                                .font(PiggyTheme.Typography.caption)
                                .foregroundColor(.white.opacity(0.5))
                                .lineSpacing(2)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: PiggyTheme.CornerRadius.medium)
                                .fill(PiggyTheme.Colors.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: PiggyTheme.CornerRadius.medium)
                                        .stroke(
                                            viewModel.selectedLockType == lockType ? PiggyTheme.Colors.primary.opacity(0.5) : Color.white.opacity(0.06),
                                            lineWidth: 1
                                        )
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Lock parameters
            if viewModel.selectedLockType == .timeLock {
                VStack(alignment: .leading, spacing: 8) {
                    Text("piggy.create.unlock_date".localized)
                        .font(PiggyTheme.Typography.captionBold)
                        .foregroundColor(.white.opacity(0.6))
                    
                    DatePicker(
                        "",
                        selection: $viewModel.unlockDate,
                        in: Date()...,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .tint(PiggyTheme.Colors.primary)
                    .colorScheme(.dark)
                }
            } else if viewModel.selectedLockType == .targetLock {
                VStack(alignment: .leading, spacing: 8) {
                    Text("piggy.create.target_amount".localized)
                        .font(PiggyTheme.Typography.captionBold)
                        .foregroundColor(.white.opacity(0.6))
                    
                    HStack {
                        TextField("0.00", text: $viewModel.targetAmountText)
                            .font(PiggyTheme.Typography.balanceMedium)
                            .foregroundColor(.white)
                            .keyboardType(.decimalPad)
                        
                        Text(viewModel.selectedAsset.symbol)
                            .font(PiggyTheme.Typography.headline)
                            .foregroundColor(viewModel.selectedAsset.color)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: PiggyTheme.CornerRadius.medium)
                            .fill(PiggyTheme.Colors.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: PiggyTheme.CornerRadius.medium)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    )
                }
            }
            
            HStack(spacing: 12) {
                Button {
                    HapticManager.lightTap()
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        viewModel.currentStep = 2
                    }
                } label: {
                    Text("piggy.create.back".localized)
                        .font(PiggyTheme.Typography.bodyBold)
                        .foregroundColor(.white.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: PiggyTheme.CornerRadius.medium)
                                .fill(PiggyTheme.Colors.surface)
                        )
                }
                
                GlassButton(title: "piggy.create.next".localized, icon: "arrow.right") {
                    HapticManager.mediumTap()
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        viewModel.currentStep = 4
                    }
                }
            }
        }
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    }
    
    // MARK: - Step 4: Confirm
    private var stepFourConfirm: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("piggy.create.step4.title".localized)
                    .font(PiggyTheme.Typography.title2)
                    .foregroundColor(.white)
                
                Text("piggy.create.step4.subtitle".localized)
                    .font(PiggyTheme.Typography.body)
                    .foregroundColor(.white.opacity(0.5))
            }
            
            // Summary card
            GlassCard(padding: 20) {
                VStack(spacing: 16) {
                    HStack {
                        Circle()
                            .fill(viewModel.selectedColor.gradient)
                            .frame(width: 48, height: 48)
                            .overlay(
                                Image(systemName: "lock.shield.fill")
                                    .foregroundColor(.white)
                            )
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(viewModel.name)
                                .font(PiggyTheme.Typography.headline)
                                .foregroundColor(.white)
                            Text(viewModel.selectedAsset.symbol)
                                .font(PiggyTheme.Typography.caption)
                                .foregroundColor(viewModel.selectedAsset.color)
                        }
                        
                        Spacer()
                    }
                    
                    Divider().background(Color.white.opacity(0.1))
                    
                    VStack(spacing: 12) {
                        SummaryRow(label: "piggy.create.summary.lock_type".localized, value: viewModel.selectedLockType.displayName)
                        
                        if viewModel.selectedLockType == .timeLock {
                            SummaryRow(
                                label: "piggy.create.summary.unlock_date".localized,
                                value: viewModel.unlockDate.formatted(date: .long, time: .omitted)
                            )
                        } else {
                            SummaryRow(
                                label: "piggy.create.summary.target".localized,
                                value: "\(viewModel.targetAmountText) \(viewModel.selectedAsset.symbol)"
                            )
                        }
                        
                        SummaryRow(label: "piggy.create.summary.network".localized, value: "Base (L2)")
                    }
                }
            }
            
            // Warning
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(PiggyTheme.Colors.warning)
                
                Text("piggy.create.warning".localized)
                    .font(PiggyTheme.Typography.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .lineSpacing(2)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: PiggyTheme.CornerRadius.medium)
                    .fill(PiggyTheme.Colors.warning.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: PiggyTheme.CornerRadius.medium)
                            .stroke(PiggyTheme.Colors.warning.opacity(0.2), lineWidth: 1)
                    )
            )
            
            HStack(spacing: 12) {
                Button {
                    HapticManager.lightTap()
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        viewModel.currentStep = 3
                    }
                } label: {
                    Text("piggy.create.back".localized)
                        .font(PiggyTheme.Typography.bodyBold)
                        .foregroundColor(.white.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: PiggyTheme.CornerRadius.medium)
                                .fill(PiggyTheme.Colors.surface)
                        )
                }
                
                GlassButton(
                    title: "piggy.create.confirm".localized,
                    icon: "lock.shield.fill"
                ) {
                    HapticManager.heavyTap()
                    viewModel.createPiggyBank(appState: appState) {
                        showConfetti = true
                        HapticManager.success()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            dismiss()
                        }
                    }
                }
            }
        }
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    }
}

struct StepIndicator: View {
    let currentStep: Int
    let totalSteps: Int
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...totalSteps, id: \.self) { step in
                ZStack {
                    if step < currentStep {
                        Circle()
                            .fill(PiggyTheme.Colors.accentGreen)
                            .frame(width: 28, height: 28)
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .transition(.scale.combined(with: .opacity))
                    } else if step == currentStep {
                        Circle()
                            .fill(PiggyTheme.Colors.primary.opacity(0.15))
                            .frame(width: 36, height: 36)
                            .scaleEffect(pulseScale)
                        Circle()
                            .fill(PiggyTheme.Colors.primaryGradient)
                            .frame(width: 28, height: 28)
                        Text("\(step)")
                            .font(PiggyTheme.Typography.captionBold)
                            .foregroundColor(.white)
                    } else {
                        Circle()
                            .fill(PiggyTheme.Colors.surface)
                            .frame(width: 28, height: 28)
                            .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                        Text("\(step)")
                            .font(PiggyTheme.Typography.captionBold)
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
                
                if step < totalSteps {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.white.opacity(0.1))
                                .frame(height: 2)
                            Rectangle()
                                .fill(PiggyTheme.Colors.accentGreen)
                                .frame(width: step < currentStep ? geo.size.width : 0, height: 2)
                                .animation(.spring(response: 0.5, dampingFraction: 0.85), value: currentStep)
                        }
                    }
                    .frame(height: 2)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 20)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentStep)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseScale = 1.2
            }
        }
        .onChange(of: currentStep) { _, _ in
            pulseScale = 1.0
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseScale = 1.2
            }
        }
    }
}

struct SummaryRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(PiggyTheme.Typography.caption)
                .foregroundColor(.white.opacity(0.5))
            Spacer()
            Text(value)
                .font(PiggyTheme.Typography.captionBold)
                .foregroundColor(.white)
        }
    }
}
