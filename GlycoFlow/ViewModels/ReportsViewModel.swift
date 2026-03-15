//
//  ReportsViewModel.swift
//  GlycoFlow
//

import Foundation
import SwiftData

@MainActor
@Observable
final class ReportsViewModel {
    var isGenerating = false
    var generatedPDFURL: URL?
    var errorMessage: String?
    var selectedPeriod: ReportPeriod = .month
    var showShareSheet = false

    func generateReport(readings: [GlucoseReading], medications: [MedicationLog], profile: UserProfile?) async {
        isGenerating = true
        errorMessage = nil

        let cutoff = Calendar.current.date(byAdding: .day, value: -selectedPeriod.days, to: Date()) ?? Date()
        let filteredReadings = readings.filter { $0.timestamp >= cutoff }
        let filteredMeds = medications.filter { $0.timestamp >= cutoff }

        let data = PDFExporter.shared.generateReport(
            readings: filteredReadings,
            medications: filteredMeds,
            profile: profile,
            period: selectedPeriod
        )

        if let data {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let filename = "GlycoFlow_Report_\(formatter.string(from: Date())).pdf"
            generatedPDFURL = PDFExporter.shared.saveToDocuments(data: data, filename: filename)
            showShareSheet = generatedPDFURL != nil
            AnalyticsService.shared.track(.reportExported)
        } else {
            errorMessage = "Failed to generate report. Please try again."
        }

        isGenerating = false
    }
}
