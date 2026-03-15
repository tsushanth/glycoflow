//
//  AnalyticsService.swift
//  GlycoFlow
//

import Foundation

// MARK: - Analytics Event
enum AnalyticsEvent {
    case appOpen
    case onboardingCompleted
    case glucoseLogged(type: String, value: Double)
    case medicationLogged
    case foodLogged
    case a1cCalculated(value: Double)
    case reportExported
    case paywallViewed
    case purchaseStarted(productID: String)
    case purchaseCompleted(productID: String)
    case purchaseFailed(productID: String)
    case purchaseRestored
    case settingsChanged(key: String)
    case healthKitConnected
    case signUp(method: String)

    var name: String {
        switch self {
        case .appOpen: return "app_open"
        case .onboardingCompleted: return "onboarding_completed"
        case .glucoseLogged: return "glucose_logged"
        case .medicationLogged: return "medication_logged"
        case .foodLogged: return "food_logged"
        case .a1cCalculated: return "a1c_calculated"
        case .reportExported: return "report_exported"
        case .paywallViewed: return "paywall_viewed"
        case .purchaseStarted: return "purchase_started"
        case .purchaseCompleted: return "purchase_completed"
        case .purchaseFailed: return "purchase_failed"
        case .purchaseRestored: return "purchase_restored"
        case .settingsChanged: return "settings_changed"
        case .healthKitConnected: return "healthkit_connected"
        case .signUp: return "sign_up"
        }
    }

    var parameters: [String: Any] {
        switch self {
        case .glucoseLogged(let type, let value):
            return ["type": type, "value": value]
        case .a1cCalculated(let value):
            return ["a1c_value": value]
        case .purchaseStarted(let id), .purchaseCompleted(let id), .purchaseFailed(let id):
            return ["product_id": id]
        case .settingsChanged(let key):
            return ["key": key]
        case .signUp(let method):
            return ["method": method]
        default:
            return [:]
        }
    }
}

// MARK: - Analytics Service
@MainActor
final class AnalyticsService {
    static let shared = AnalyticsService()

    private var isInitialized = false

    func initialize() {
        guard !isInitialized else { return }
        isInitialized = true
        // Firebase Analytics would be initialized here
        // FirebaseApp.configure()
        #if DEBUG
        print("[Analytics] Initialized")
        #endif
    }

    func track(_ event: AnalyticsEvent) {
        guard isInitialized else { return }
        // Analytics.logEvent(event.name, parameters: event.parameters)
        #if DEBUG
        print("[Analytics] Event: \(event.name), params: \(event.parameters)")
        #endif
    }

    func setUserProperty(_ value: String?, forName name: String) {
        // Analytics.setUserProperty(value, forName: name)
        #if DEBUG
        print("[Analytics] User property: \(name) = \(value ?? "nil")")
        #endif
    }
}

// MARK: - ATT Service
@MainActor
final class ATTService {
    static let shared = ATTService()

    func requestIfNeeded() async -> Bool {
        // In production, use AppTrackingTransparency:
        // let status = ATTrackingManager.trackingAuthorizationStatus
        // if status == .notDetermined {
        //     let result = await ATTrackingManager.requestTrackingAuthorization()
        //     return result == .authorized
        // }
        // return status == .authorized
        return false
    }
}

// MARK: - Attribution Manager
@MainActor
final class AttributionManager {
    static let shared = AttributionManager()

    func requestAttributionIfNeeded() async {
        // AdServices attribution token fetch would go here
        // let token = try? AAAttribution.attributionToken()
        #if DEBUG
        print("[Attribution] Attribution check")
        #endif
    }
}
