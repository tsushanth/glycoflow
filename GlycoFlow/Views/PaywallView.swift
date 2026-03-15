//
//  PaywallView.swift
//  GlycoFlow
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PremiumManager.self) private var premiumManager
    @State private var storeKitManager = StoreKitManager.shared
    @State private var selectedProduct: Product?
    @State private var isPurchasing = false
    @State private var errorMessage: String?
    @State private var showError = false

    private let features: [(icon: String, title: String, description: String)] = [
        ("infinity", "Unlimited History", "Access all your readings with no limits"),
        ("chart.line.uptrend.xyaxis", "Advanced Analytics", "90-day trends and detailed insights"),
        ("doc.fill", "PDF Reports", "Export doctor-ready reports in one tap"),
        ("bell.fill", "Smart Reminders", "Medication and glucose check reminders"),
        ("heart.text.square.fill", "HealthKit Sync", "Seamless Apple Health integration"),
        ("waveform.path.ecg", "A1C Estimator", "Track your long-term glucose control"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Hero
                    heroSection

                    // Features
                    featuresSection

                    // Products
                    if storeKitManager.isLoading {
                        ProgressView("Loading plans...")
                            .padding()
                    } else if storeKitManager.subscriptions.isEmpty {
                        Text("Plans unavailable. Please try again later.")
                            .foregroundStyle(.secondary)
                            .padding()
                    } else {
                        productsSection
                    }

                    // CTA
                    ctaButton

                    // Restore
                    Button {
                        Task { await storeKitManager.restorePurchases() }
                    } label: {
                        Text("Restore Purchases")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // Legal
                    legalText

                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onAppear {
                AnalyticsService.shared.track(.paywallViewed)
                if storeKitManager.subscriptions.isEmpty {
                    Task { await storeKitManager.loadProducts() }
                }
                // Auto-select yearly (best value)
                selectedProduct = storeKitManager.subscriptions.first { $0.isPopular }
                    ?? storeKitManager.subscriptions.last
            }
            .onChange(of: storeKitManager.subscriptions) { _, newValue in
                if selectedProduct == nil {
                    selectedProduct = newValue.first { $0.isPopular } ?? newValue.last
                }
            }
            .onChange(of: storeKitManager.purchaseState) { _, state in
                if state == .purchased {
                    Task { await premiumManager.refreshPremiumStatus() }
                    dismiss()
                }
            }
            .alert("Purchase Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage ?? "An error occurred.")
            }
        }
    }

    // MARK: - Hero
    private var heroSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "drop.fill")
                .font(.system(size: 56))
                .foregroundStyle(.blue)
                .symbolRenderingMode(.multicolor)

            Text("GlycoFlow Premium")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Take control of your blood sugar with advanced tracking, analytics, and doctor reports.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Features
    private var featuresSection: some View {
        VStack(spacing: 12) {
            ForEach(features, id: \.title) { feature in
                HStack(spacing: 14) {
                    Image(systemName: feature.icon)
                        .font(.title3)
                        .foregroundStyle(.blue)
                        .frame(width: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(feature.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text(feature.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Products
    private var productsSection: some View {
        VStack(spacing: 10) {
            ForEach(storeKitManager.subscriptions, id: \.id) { product in
                ProductCard(
                    product: product,
                    isSelected: selectedProduct?.id == product.id
                ) {
                    selectedProduct = product
                }
            }

            // Lifetime
            ForEach(storeKitManager.nonConsumables, id: \.id) { product in
                ProductCard(
                    product: product,
                    isSelected: selectedProduct?.id == product.id
                ) {
                    selectedProduct = product
                }
            }
        }
    }

    // MARK: - CTA Button
    private var ctaButton: some View {
        Button {
            guard let product = selectedProduct else { return }
            isPurchasing = true
            AnalyticsService.shared.track(.purchaseStarted(productID: product.id))
            Task {
                do {
                    _ = try await storeKitManager.purchase(product)
                    AnalyticsService.shared.track(.purchaseCompleted(productID: product.id))
                } catch StoreKitError.userCancelled {
                    // no-op
                } catch {
                    errorMessage = error.localizedDescription
                    showError = true
                    AnalyticsService.shared.track(.purchaseFailed(productID: product.id))
                }
                isPurchasing = false
            }
        } label: {
            HStack {
                if isPurchasing {
                    ProgressView().tint(.white)
                } else {
                    Text("Start Premium")
                        .fontWeight(.bold)
                        .font(.title3)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing)
            )
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .disabled(selectedProduct == nil || isPurchasing)
    }

    // MARK: - Legal
    private var legalText: some View {
        VStack(spacing: 4) {
            Text("Subscriptions auto-renew. Cancel anytime in App Store settings.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            HStack {
                Link("Privacy Policy", destination: URL(string: "https://glycoflow.app/privacy")!)
                Text("•")
                Link("Terms of Service", destination: URL(string: "https://glycoflow.app/terms")!)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
    }
}

// MARK: - Product Card
struct ProductCard: View {
    let product: Product
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(product.displayName)
                            .font(.headline)
                        if product.isPopular {
                            Text("BEST VALUE")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.yellow)
                                .foregroundStyle(.black)
                                .clipShape(Capsule())
                        }
                    }
                    if let savings = product.savingsLabel {
                        Text(savings)
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(product.displayPrice)
                        .font(.headline)
                        .fontWeight(.bold)
                    Text(product.periodLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .blue : .gray.opacity(0.4))
                    .font(.title3)
                    .padding(.leading, 4)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(isSelected ? Color.blue.opacity(0.06) : Color.clear)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
