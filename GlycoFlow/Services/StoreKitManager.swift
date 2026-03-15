//
//  StoreKitManager.swift
//  GlycoFlow
//
//  StoreKit 2 implementation for in-app purchases and subscriptions
//

import Foundation
import StoreKit

// MARK: - Product Identifiers
enum StoreKitProductID: String, CaseIterable {
    case weekly = "com.appfactory.glycoflow.subscription.weekly"
    case monthly = "com.appfactory.glycoflow.subscription.monthly"
    case yearly = "com.appfactory.glycoflow.subscription.yearly"
    case lifetime = "com.appfactory.glycoflow.lifetime"

    var displayName: String {
        switch self {
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        case .lifetime: return "Lifetime"
        }
    }

    static var subscriptionIDs: [String] {
        [weekly.rawValue, monthly.rawValue, yearly.rawValue]
    }

    static var allIDs: [String] {
        allCases.map { $0.rawValue }
    }
}

// MARK: - Purchase State
enum PurchaseState: Equatable {
    case idle
    case loading
    case purchasing
    case purchased
    case failed(String)
    case pending
    case cancelled
}

// MARK: - StoreKit Error
enum StoreKitError: LocalizedError {
    case productNotFound
    case purchaseFailed(Error)
    case verificationFailed
    case userCancelled
    case pending
    case unknown

    var errorDescription: String? {
        switch self {
        case .productNotFound: return "Product not found."
        case .purchaseFailed(let error): return "Purchase failed: \(error.localizedDescription)"
        case .verificationFailed: return "Purchase verification failed."
        case .userCancelled: return "Purchase was cancelled."
        case .pending: return "Purchase is pending approval."
        case .unknown: return "An unknown error occurred."
        }
    }
}

// MARK: - StoreKit Manager
@MainActor
@Observable
final class StoreKitManager {
    static let shared = StoreKitManager()

    private(set) var subscriptions: [Product] = []
    private(set) var nonConsumables: [Product] = []
    private(set) var allProducts: [Product] = []
    private(set) var purchaseState: PurchaseState = .idle
    private(set) var isLoading: Bool = false
    private(set) var errorMessage: String?
    private(set) var purchasedSubscriptions: Set<String> = []
    private(set) var purchasedNonConsumables: Set<String> = []
    private var updateListenerTask: Task<Void, Error>?

    var hasActiveSubscription: Bool { !purchasedSubscriptions.isEmpty }
    var isPremium: Bool { hasActiveSubscription || !purchasedNonConsumables.isEmpty }

    var currentSubscriptionProductID: String? { purchasedSubscriptions.first }

    init() {
        updateListenerTask = listenForTransactions()
        Task {
            await loadProducts()
            await updatePurchasedProducts()
        }
    }

    func loadProducts() async {
        isLoading = true
        errorMessage = nil
        do {
            let storeProducts = try await Product.products(for: StoreKitProductID.allIDs)
            var subs: [Product] = []
            var nonCons: [Product] = []
            for product in storeProducts {
                switch product.type {
                case .autoRenewable, .nonRenewable: subs.append(product)
                case .nonConsumable: nonCons.append(product)
                default: break
                }
            }
            subscriptions = subs.sorted { $0.price < $1.price }
            nonConsumables = nonCons
            allProducts = subscriptions + nonConsumables
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = "Failed to load products: \(error.localizedDescription)"
        }
    }

    func purchase(_ product: Product) async throws -> Transaction? {
        purchaseState = .purchasing
        errorMessage = nil
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await updatePurchasedProducts()
                await transaction.finish()
                purchaseState = .purchased
                return transaction
            case .userCancelled:
                purchaseState = .cancelled
                throw StoreKitError.userCancelled
            case .pending:
                purchaseState = .pending
                throw StoreKitError.pending
            @unknown default:
                purchaseState = .failed("Unknown result")
                throw StoreKitError.unknown
            }
        } catch StoreKitError.userCancelled {
            purchaseState = .cancelled
            throw StoreKitError.userCancelled
        } catch {
            let msg = error.localizedDescription
            purchaseState = .failed(msg)
            errorMessage = msg
            throw StoreKitError.purchaseFailed(error)
        }
    }

    func restorePurchases() async {
        purchaseState = .loading
        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
            purchaseState = isPremium ? .purchased : .idle
        } catch {
            errorMessage = "Failed to restore: \(error.localizedDescription)"
            purchaseState = .failed(errorMessage ?? "Unknown error")
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified: throw StoreKitError.verificationFailed
        case .verified(let safe): return safe
        }
    }

    func updatePurchasedProducts() async {
        var subs: Set<String> = []
        var nonCons: Set<String> = []
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }
            switch transaction.productType {
            case .autoRenewable, .nonRenewable:
                if transaction.revocationDate == nil { subs.insert(transaction.productID) }
            case .nonConsumable:
                if transaction.revocationDate == nil { nonCons.insert(transaction.productID) }
            default: break
            }
        }
        purchasedSubscriptions = subs
        purchasedNonConsumables = nonCons
    }

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let transaction = try? StoreKitManager.verifyResult(result) else { continue }
                await self?.updatePurchasedProducts()
                await transaction.finish()
            }
        }
    }

    nonisolated static func verifyResult<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified: throw StoreKitError.verificationFailed
        case .verified(let safe): return safe
        }
    }

    func product(for id: StoreKitProductID) -> Product? {
        allProducts.first { $0.id == id.rawValue }
    }

    func resetState() {
        purchaseState = .idle
        errorMessage = nil
    }
}

// MARK: - Product Extension
extension Product {
    var periodLabel: String {
        guard let subscription = subscription else { return "One-time purchase" }
        let unit = subscription.subscriptionPeriod.unit
        let value = subscription.subscriptionPeriod.value
        switch unit {
        case .day: return value == 7 ? "per week" : "per \(value) days"
        case .week: return value == 1 ? "per week" : "per \(value) weeks"
        case .month: return value == 1 ? "per month" : "per \(value) months"
        case .year: return value == 1 ? "per year" : "per \(value) years"
        @unknown default: return ""
        }
    }

    var savingsLabel: String? {
        guard let subscription = subscription else { return nil }
        return subscription.subscriptionPeriod.unit == .year ? "Best Value - Save 60%" : nil
    }

    var isPopular: Bool {
        guard let subscription = subscription else { return false }
        return subscription.subscriptionPeriod.unit == .year
    }
}
