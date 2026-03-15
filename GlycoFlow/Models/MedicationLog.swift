//
//  MedicationLog.swift
//  GlycoFlow
//

import Foundation
import SwiftData

// MARK: - Medication Type
enum MedicationType: String, Codable, CaseIterable {
    case insulin = "Insulin"
    case oral = "Oral Medication"
    case injection = "Injection"
    case supplement = "Supplement"
    case other = "Other"

    var icon: String {
        switch self {
        case .insulin: return "syringe.fill"
        case .oral: return "pills.fill"
        case .injection: return "syringe"
        case .supplement: return "leaf.fill"
        case .other: return "cross.case.fill"
        }
    }
}

// MARK: - Insulin Type
enum InsulinType: String, Codable, CaseIterable {
    case rapidActing = "Rapid-Acting"
    case shortActing = "Short-Acting"
    case intermediate = "Intermediate"
    case longActing = "Long-Acting"
    case premixed = "Premixed"
    case notApplicable = "N/A"
}

// MARK: - Medication Log Model
@Model
final class MedicationLog {
    var id: UUID
    var name: String
    var medicationType: String
    var insulinType: String
    var dose: Double
    var unit: String
    var timestamp: Date
    var notes: String
    var isTaken: Bool
    var scheduledTime: Date?

    init(
        id: UUID = UUID(),
        name: String,
        medicationType: MedicationType = .oral,
        insulinType: InsulinType = .notApplicable,
        dose: Double,
        unit: String = "units",
        timestamp: Date = Date(),
        notes: String = "",
        isTaken: Bool = false,
        scheduledTime: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.medicationType = medicationType.rawValue
        self.insulinType = insulinType.rawValue
        self.dose = dose
        self.unit = unit
        self.timestamp = timestamp
        self.notes = notes
        self.isTaken = isTaken
        self.scheduledTime = scheduledTime
    }

    var type: MedicationType {
        MedicationType(rawValue: medicationType) ?? .other
    }

    var insulin: InsulinType {
        InsulinType(rawValue: insulinType) ?? .notApplicable
    }

    var displayDose: String {
        if dose == floor(dose) {
            return "\(Int(dose)) \(unit)"
        }
        return String(format: "%.1f \(unit)", dose)
    }
}
