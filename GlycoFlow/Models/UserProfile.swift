//
//  UserProfile.swift
//  GlycoFlow
//

import Foundation
import SwiftData

// MARK: - Diabetes Type
enum DiabetesType: String, Codable, CaseIterable {
    case type1 = "Type 1"
    case type2 = "Type 2"
    case gestational = "Gestational"
    case prediabetes = "Prediabetes"
    case other = "Other"
    case notDiagnosed = "Not Diagnosed"
}

// MARK: - User Profile Model
@Model
final class UserProfile {
    var id: UUID
    var name: String
    var diabetesType: String
    var targetLow: Double
    var targetHigh: Double
    var preferredUnit: String
    var doctorName: String
    var doctorEmail: String
    var remindersEnabled: Bool
    var reminderTimes: [Date]
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String = "",
        diabetesType: DiabetesType = .type2,
        targetLow: Double = 80,
        targetHigh: Double = 180,
        preferredUnit: GlucoseUnit = .mgdL,
        doctorName: String = "",
        doctorEmail: String = "",
        remindersEnabled: Bool = false,
        reminderTimes: [Date] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.diabetesType = diabetesType.rawValue
        self.targetLow = targetLow
        self.targetHigh = targetHigh
        self.preferredUnit = preferredUnit.rawValue
        self.doctorName = doctorName
        self.doctorEmail = doctorEmail
        self.remindersEnabled = remindersEnabled
        self.reminderTimes = reminderTimes
        self.createdAt = createdAt
    }

    var diabetes: DiabetesType {
        DiabetesType(rawValue: diabetesType) ?? .notDiagnosed
    }

    var unit: GlucoseUnit {
        GlucoseUnit(rawValue: preferredUnit) ?? .mgdL
    }
}
