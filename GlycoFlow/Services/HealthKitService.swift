//
//  HealthKitService.swift
//  GlycoFlow
//

import Foundation
import HealthKit

@MainActor
@Observable
final class HealthKitService {
    static let shared = HealthKitService()

    private let healthStore = HKHealthStore()
    private(set) var isAuthorized = false
    private(set) var isAvailable = HKHealthStore.isHealthDataAvailable()

    // HealthKit types
    private let bloodGlucoseType = HKQuantityType(.bloodGlucose)
    private let carbsType = HKQuantityType(.dietaryCarbohydrates)
    private let insulinType = HKQuantityType(.insulinDelivery)

    private var readTypes: Set<HKObjectType> {
        [bloodGlucoseType, carbsType, insulinType]
    }

    private var writeTypes: Set<HKSampleType> {
        [bloodGlucoseType, carbsType, insulinType]
    }

    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        do {
            try await healthStore.requestAuthorization(toShare: writeTypes, read: readTypes)
            isAuthorized = true
            return true
        } catch {
            print("[HealthKit] Authorization failed: \(error)")
            return false
        }
    }

    func saveBloodGlucose(value: Double, unit: GlucoseUnit, date: Date, mealTime: Int = 0) async -> Bool {
        guard isAvailable else { return false }

        let hkUnit: HKUnit = unit == .mgdL
            ? HKUnit(from: "mg/dL")
            : HKUnit(from: "mmol<180.16>/L")

        let quantity = HKQuantity(unit: hkUnit, doubleValue: value)
        let metadata: [String: Any] = mealTime > 0 ? [HKMetadataKeyBloodGlucoseMealTime: mealTime] : [:]
        let sample = HKQuantitySample(
            type: bloodGlucoseType,
            quantity: quantity,
            start: date,
            end: date,
            metadata: metadata
        )

        do {
            try await healthStore.save(sample)
            return true
        } catch {
            print("[HealthKit] Save glucose failed: \(error)")
            return false
        }
    }

    func saveCarbohydrates(grams: Double, date: Date) async -> Bool {
        guard isAvailable else { return false }

        let quantity = HKQuantity(unit: .gram(), doubleValue: grams)
        let sample = HKQuantitySample(
            type: carbsType,
            quantity: quantity,
            start: date,
            end: date
        )
        do {
            try await healthStore.save(sample)
            return true
        } catch {
            print("[HealthKit] Save carbs failed: \(error)")
            return false
        }
    }

    func saveInsulin(units: Double, insulinType: HKInsulinDeliveryReason, date: Date) async -> Bool {
        guard isAvailable else { return false }

        let quantity = HKQuantity(unit: .internationalUnit(), doubleValue: units)
        let metadata: [String: Any] = [HKMetadataKeyInsulinDeliveryReason: insulinType.rawValue]
        let sample = HKQuantitySample(
            type: self.insulinType,
            quantity: quantity,
            start: date,
            end: date,
            metadata: metadata
        )
        do {
            try await healthStore.save(sample)
            return true
        } catch {
            print("[HealthKit] Save insulin failed: \(error)")
            return false
        }
    }

    func fetchRecentGlucoseReadings(days: Int = 30) async -> [HKQuantitySample] {
        guard isAvailable else { return [] }

        let predicate = HKQuery.predicateForSamples(
            withStart: Calendar.current.date(byAdding: .day, value: -days, to: Date()),
            end: Date()
        )
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: bloodGlucoseType, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)]
        )
        do {
            return try await descriptor.result(for: healthStore)
        } catch {
            print("[HealthKit] Fetch glucose failed: \(error)")
            return []
        }
    }
}
