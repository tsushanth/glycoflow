//
//  GlucoseReading.swift
//  GlycoFlow
//

import Foundation
import SwiftData

// MARK: - Glucose Reading Type
enum ReadingType: String, Codable, CaseIterable {
    case fasting = "Fasting"
    case beforeMeal = "Before Meal"
    case afterMeal = "After Meal"
    case bedtime = "Bedtime"
    case random = "Random"
    case exercise = "Exercise"

    var icon: String {
        switch self {
        case .fasting: return "moon.fill"
        case .beforeMeal: return "fork.knife"
        case .afterMeal: return "checkmark.circle.fill"
        case .bedtime: return "bed.double.fill"
        case .random: return "drop.fill"
        case .exercise: return "figure.run"
        }
    }

    var color: String {
        switch self {
        case .fasting: return "indigo"
        case .beforeMeal: return "orange"
        case .afterMeal: return "green"
        case .bedtime: return "purple"
        case .random: return "blue"
        case .exercise: return "red"
        }
    }
}

// MARK: - Glucose Unit
enum GlucoseUnit: String, Codable, CaseIterable {
    case mgdL = "mg/dL"
    case mmolL = "mmol/L"

    func convert(_ value: Double, to unit: GlucoseUnit) -> Double {
        if self == unit { return value }
        if self == .mgdL && unit == .mmolL {
            return value / 18.0
        } else {
            return value * 18.0
        }
    }
}

// MARK: - Glucose Status
enum GlucoseStatus: String, CaseIterable {
    case low = "Low"
    case normal = "Normal"
    case high = "High"
    case veryHigh = "Very High"

    var color: String {
        switch self {
        case .low: return "blue"
        case .normal: return "green"
        case .high: return "orange"
        case .veryHigh: return "red"
        }
    }

    static func status(for value: Double, unit: GlucoseUnit = .mgdL) -> GlucoseStatus {
        let mgdLValue = unit == .mgdL ? value : value * 18.0
        switch mgdLValue {
        case ..<70: return .low
        case 70..<180: return .normal
        case 180..<250: return .high
        default: return .veryHigh
        }
    }
}

// MARK: - Glucose Reading Model
@Model
final class GlucoseReading {
    var id: UUID
    var value: Double
    var unit: String
    var readingType: String
    var timestamp: Date
    var notes: String
    var mealContext: String?
    var tags: [String]
    var syncedToHealthKit: Bool

    init(
        id: UUID = UUID(),
        value: Double,
        unit: GlucoseUnit = .mgdL,
        readingType: ReadingType = .random,
        timestamp: Date = Date(),
        notes: String = "",
        mealContext: String? = nil,
        tags: [String] = [],
        syncedToHealthKit: Bool = false
    ) {
        self.id = id
        self.value = value
        self.unit = unit.rawValue
        self.readingType = readingType.rawValue
        self.timestamp = timestamp
        self.notes = notes
        self.mealContext = mealContext
        self.tags = tags
        self.syncedToHealthKit = syncedToHealthKit
    }

    var glucoseUnit: GlucoseUnit {
        GlucoseUnit(rawValue: unit) ?? .mgdL
    }

    var type: ReadingType {
        ReadingType(rawValue: readingType) ?? .random
    }

    var status: GlucoseStatus {
        GlucoseStatus.status(for: value, unit: glucoseUnit)
    }

    var valueInMgdL: Double {
        glucoseUnit == .mgdL ? value : value * 18.0
    }

    var displayValue: String {
        if glucoseUnit == .mgdL {
            return "\(Int(value))"
        } else {
            return String(format: "%.1f", value)
        }
    }
}
