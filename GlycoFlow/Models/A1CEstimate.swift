//
//  A1CEstimate.swift
//  GlycoFlow
//

import Foundation
import SwiftData

// MARK: - A1C Estimate Model
@Model
final class A1CEstimate {
    var id: UUID
    var estimatedA1C: Double
    var averageGlucose: Double
    var calculatedDate: Date
    var readingCount: Int
    var periodDays: Int
    var notes: String

    init(
        id: UUID = UUID(),
        estimatedA1C: Double,
        averageGlucose: Double,
        calculatedDate: Date = Date(),
        readingCount: Int,
        periodDays: Int = 90,
        notes: String = ""
    ) {
        self.id = id
        self.estimatedA1C = estimatedA1C
        self.averageGlucose = averageGlucose
        self.calculatedDate = calculatedDate
        self.readingCount = readingCount
        self.periodDays = periodDays
        self.notes = notes
    }

    var category: String {
        switch estimatedA1C {
        case ..<5.7: return "Normal"
        case 5.7..<6.5: return "Prediabetes"
        case 6.5..<8.0: return "Diabetes (Managed)"
        default: return "Diabetes (High Risk)"
        }
    }

    var categoryColor: String {
        switch estimatedA1C {
        case ..<5.7: return "green"
        case 5.7..<6.5: return "yellow"
        case 6.5..<8.0: return "orange"
        default: return "red"
        }
    }

    var displayA1C: String {
        String(format: "%.1f%%", estimatedA1C)
    }
}

// MARK: - Glucose Trend Model
@Model
final class GlucoseTrend {
    var id: UUID
    var date: Date
    var averageGlucose: Double
    var minGlucose: Double
    var maxGlucose: Double
    var readingCount: Int
    var timeInRange: Double
    var unit: String

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        averageGlucose: Double,
        minGlucose: Double,
        maxGlucose: Double,
        readingCount: Int,
        timeInRange: Double,
        unit: String = GlucoseUnit.mgdL.rawValue
    ) {
        self.id = id
        self.date = date
        self.averageGlucose = averageGlucose
        self.minGlucose = minGlucose
        self.maxGlucose = maxGlucose
        self.readingCount = readingCount
        self.timeInRange = timeInRange
        self.unit = unit
    }

    var glucoseRange: Double {
        maxGlucose - minGlucose
    }
}
