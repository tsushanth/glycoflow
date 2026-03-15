//
//  FoodViewModel.swift
//  GlycoFlow
//

import Foundation
import SwiftData

@MainActor
@Observable
final class FoodViewModel {
    var entries: [FoodEntry] = []
    var isLoading = false
    var errorMessage: String?

    // Form state
    var foodName: String = ""
    var selectedMealType: MealType = .snack
    var carbGrams: String = ""
    var calories: String = ""
    var proteinGrams: String = ""
    var fatGrams: String = ""
    var fiberGrams: String = ""
    var glycemicIndex: String = ""
    var servingSize: String = "1 serving"
    var entryDate: Date = Date()
    var notes: String = ""

    var todayEntries: [FoodEntry] {
        entries.filter { Calendar.current.isDateInToday($0.timestamp) }
    }

    var todayTotalCarbs: Double {
        todayEntries.reduce(0) { $0 + $1.carbGrams }
    }

    var todayTotalCalories: Double {
        todayEntries.reduce(0) { $0 + $1.calories }
    }

    func saveEntry(context: ModelContext) {
        guard !foodName.isEmpty else {
            errorMessage = "Please enter a food name."
            return
        }

        let entry = FoodEntry(
            name: foodName,
            mealType: selectedMealType,
            carbGrams: Double(carbGrams) ?? 0,
            calories: Double(calories) ?? 0,
            proteinGrams: Double(proteinGrams) ?? 0,
            fatGrams: Double(fatGrams) ?? 0,
            fiberGrams: Double(fiberGrams) ?? 0,
            glycemicIndex: Int(glycemicIndex) ?? 0,
            servingSize: servingSize,
            timestamp: entryDate,
            notes: notes
        )

        context.insert(entry)
        try? context.save()
        entries.insert(entry, at: 0)
        AnalyticsService.shared.track(.foodLogged)
        resetForm()
    }

    func deleteEntry(_ entry: FoodEntry, context: ModelContext) {
        context.delete(entry)
        try? context.save()
        entries.removeAll { $0.id == entry.id }
    }

    func loadEntries(from context: ModelContext) {
        let descriptor = FetchDescriptor<FoodEntry>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        entries = (try? context.fetch(descriptor)) ?? []
    }

    func resetForm() {
        foodName = ""
        selectedMealType = .snack
        carbGrams = ""
        calories = ""
        proteinGrams = ""
        fatGrams = ""
        fiberGrams = ""
        glycemicIndex = ""
        servingSize = "1 serving"
        entryDate = Date()
        notes = ""
    }
}
