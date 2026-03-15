//
//  GlycoFlowApp.swift
//  GlycoFlow
//
//  Main app entry point with SwiftData, StoreKit 2, and SDK integrations
//

import SwiftUI
import SwiftData
import UserNotifications

@main
struct GlycoFlowApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    let modelContainer: ModelContainer
    @State private var premiumManager = PremiumManager()

    init() {
        do {
            let schema = Schema([
                GlucoseReading.self,
                MedicationLog.self,
                FoodEntry.self,
                A1CEstimate.self,
                UserProfile.self,
            ])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(premiumManager)
                .onAppear {
                    Task {
                        await premiumManager.refreshPremiumStatus()
                    }
                }
        }
        .modelContainer(modelContainer)
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        Task { @MainActor in
            AnalyticsService.shared.initialize()
        }
        Task { @MainActor in
            _ = await ATTService.shared.requestIfNeeded()
            await AttributionManager.shared.requestAttributionIfNeeded()
        }
        return true
    }
}

// MARK: - Premium Manager
@MainActor
@Observable
final class PremiumManager {
    private(set) var isPremium: Bool = false
    private let storeKitManager = StoreKitManager.shared

    func refreshPremiumStatus() async {
        await storeKitManager.updatePurchasedProducts()
        isPremium = storeKitManager.isPremium
    }
}
