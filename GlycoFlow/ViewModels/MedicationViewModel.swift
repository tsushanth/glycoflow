//
//  MedicationViewModel.swift
//  GlycoFlow
//

import Foundation
import SwiftData

@MainActor
@Observable
final class MedicationViewModel {
    var medications: [MedicationLog] = []
    var isLoading = false
    var errorMessage: String?

    // Form state
    var medicationName: String = ""
    var selectedMedicationType: MedicationType = .oral
    var selectedInsulinType: InsulinType = .notApplicable
    var dose: String = ""
    var unit: String = "mg"
    var medicationDate: Date = Date()
    var notes: String = ""
    var isTaken: Bool = false

    var todayMedications: [MedicationLog] {
        medications.filter { Calendar.current.isDateInToday($0.timestamp) }
    }

    func saveMedication(context: ModelContext) {
        guard !medicationName.isEmpty, let doseValue = Double(dose), doseValue > 0 else {
            errorMessage = "Please enter valid medication details."
            return
        }

        let log = MedicationLog(
            name: medicationName,
            medicationType: selectedMedicationType,
            insulinType: selectedInsulinType,
            dose: doseValue,
            unit: unit,
            timestamp: medicationDate,
            notes: notes,
            isTaken: isTaken
        )

        context.insert(log)
        try? context.save()
        medications.insert(log, at: 0)
        AnalyticsService.shared.track(.medicationLogged)
        resetForm()
    }

    func deleteMedication(_ med: MedicationLog, context: ModelContext) {
        context.delete(med)
        try? context.save()
        medications.removeAll { $0.id == med.id }
    }

    func toggleTaken(_ med: MedicationLog, context: ModelContext) {
        med.isTaken.toggle()
        try? context.save()
    }

    func loadMedications(from context: ModelContext) {
        let descriptor = FetchDescriptor<MedicationLog>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        medications = (try? context.fetch(descriptor)) ?? []
    }

    func resetForm() {
        medicationName = ""
        selectedMedicationType = .oral
        selectedInsulinType = .notApplicable
        dose = ""
        unit = "mg"
        medicationDate = Date()
        notes = ""
        isTaken = false
    }
}
