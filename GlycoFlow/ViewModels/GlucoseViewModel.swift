//
//  GlucoseViewModel.swift
//  GlycoFlow
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class GlucoseViewModel {
    var readings: [GlucoseReading] = []
    var isLoading = false
    var errorMessage: String?
    var showingPaywall = false

    // Form state
    var glucoseValue: String = ""
    var selectedReadingType: ReadingType = .random
    var selectedUnit: GlucoseUnit = .mgdL
    var readingDate: Date = Date()
    var notes: String = ""
    var selectedTags: [String] = []

    private let healthKitService = HealthKitService.shared

    // MARK: - Target Range
    var targetLow: Double = 70
    var targetHigh: Double = 180

    // MARK: - Computed
    var latestReading: GlucoseReading? { readings.first }

    var todayReadings: [GlucoseReading] {
        readings.filter { Calendar.current.isDateInToday($0.timestamp) }
    }

    var todayAverage: Double? {
        guard !todayReadings.isEmpty else { return nil }
        return todayReadings.map { $0.valueInMgdL }.reduce(0, +) / Double(todayReadings.count)
    }

    var analytics: GlucoseAnalyticsSummary {
        GlucoseAnalytics.shared.computeSummary(readings: readings, targetLow: targetLow, targetHigh: targetHigh)
    }

    var a1cEstimate: A1CEstimate? {
        A1CCalculator.shared.calculate(readings: readings)
    }

    // MARK: - Save Reading
    func saveReading(context: ModelContext) async {
        guard let value = Double(glucoseValue), value > 0 else {
            errorMessage = "Please enter a valid glucose value."
            return
        }

        isLoading = true
        errorMessage = nil

        let reading = GlucoseReading(
            value: value,
            unit: selectedUnit,
            readingType: selectedReadingType,
            timestamp: readingDate,
            notes: notes,
            tags: selectedTags
        )

        context.insert(reading)
        try? context.save()
        readings.insert(reading, at: 0)

        // Sync to HealthKit if authorized
        if healthKitService.isAuthorized {
            let mealTime = healthKitMealTime(for: selectedReadingType)
            let synced = await healthKitService.saveBloodGlucose(
                value: value,
                unit: selectedUnit,
                date: readingDate,
                mealTime: mealTime
            )
            if synced {
                reading.syncedToHealthKit = true
                try? context.save()
            }
        }

        AnalyticsService.shared.track(.glucoseLogged(type: selectedReadingType.rawValue, value: value))
        resetForm()
        isLoading = false
    }

    func deleteReading(_ reading: GlucoseReading, context: ModelContext) {
        context.delete(reading)
        try? context.save()
        readings.removeAll { $0.id == reading.id }
    }

    func loadReadings(from context: ModelContext) {
        let descriptor = FetchDescriptor<GlucoseReading>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        readings = (try? context.fetch(descriptor)) ?? []
    }

    func resetForm() {
        glucoseValue = ""
        selectedReadingType = .random
        readingDate = Date()
        notes = ""
        selectedTags = []
    }

    // Returns HealthKit meal time integer value: 1=preprandial, 2=postprandial, 0=unspecified
    private func healthKitMealTime(for type: ReadingType) -> Int {
        switch type {
        case .beforeMeal: return 1
        case .afterMeal: return 2
        default: return 0
        }
    }
}
