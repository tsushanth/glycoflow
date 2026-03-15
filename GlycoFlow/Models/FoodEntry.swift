//
//  FoodEntry.swift
//  GlycoFlow
//

import Foundation
import SwiftData

// MARK: - Meal Type
enum MealType: String, Codable, CaseIterable {
    case breakfast = "Breakfast"
    case lunch = "Lunch"
    case dinner = "Dinner"
    case snack = "Snack"
    case drink = "Drink"

    var icon: String {
        switch self {
        case .breakfast: return "sunrise.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "moon.stars.fill"
        case .snack: return "apple.logo"
        case .drink: return "cup.and.saucer.fill"
        }
    }
}

// MARK: - Food Entry Model
@Model
final class FoodEntry {
    var id: UUID
    var name: String
    var mealType: String
    var carbGrams: Double
    var calories: Double
    var proteinGrams: Double
    var fatGrams: Double
    var fiberGrams: Double
    var glycemicIndex: Int
    var servingSize: String
    var timestamp: Date
    var notes: String
    var glucoseImpact: Double

    init(
        id: UUID = UUID(),
        name: String,
        mealType: MealType = .snack,
        carbGrams: Double = 0,
        calories: Double = 0,
        proteinGrams: Double = 0,
        fatGrams: Double = 0,
        fiberGrams: Double = 0,
        glycemicIndex: Int = 0,
        servingSize: String = "1 serving",
        timestamp: Date = Date(),
        notes: String = "",
        glucoseImpact: Double = 0
    ) {
        self.id = id
        self.name = name
        self.mealType = mealType.rawValue
        self.carbGrams = carbGrams
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.fatGrams = fatGrams
        self.fiberGrams = fiberGrams
        self.glycemicIndex = glycemicIndex
        self.servingSize = servingSize
        self.timestamp = timestamp
        self.notes = notes
        self.glucoseImpact = glucoseImpact
    }

    var meal: MealType {
        MealType(rawValue: mealType) ?? .snack
    }

    var netCarbs: Double {
        max(0, carbGrams - fiberGrams)
    }

    var glycemicLoad: Double {
        guard glycemicIndex > 0 else { return 0 }
        return (Double(glycemicIndex) * netCarbs) / 100.0
    }

    var glycemicCategory: String {
        switch glycemicIndex {
        case 0: return "Unknown"
        case 1..<55: return "Low GI"
        case 55..<70: return "Medium GI"
        default: return "High GI"
        }
    }
}
