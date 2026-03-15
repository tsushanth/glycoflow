//
//  A1CCalculator.swift
//  GlycoFlow
//

import Foundation

// MARK: - A1C Calculator
final class A1CCalculator {
    static let shared = A1CCalculator()

    /// Estimates A1C from average blood glucose (mg/dL)
    /// Formula: A1C = (Average BG + 46.7) / 28.7  (ADA formula)
    func estimateA1C(from averageGlucose: Double, unit: GlucoseUnit = .mgdL) -> Double {
        let mgdL = unit == .mgdL ? averageGlucose : averageGlucose * 18.0
        let a1c = (mgdL + 46.7) / 28.7
        return round(a1c * 10) / 10
    }

    /// Converts A1C to estimated Average Glucose (mg/dL)
    func averageGlucose(fromA1C a1c: Double) -> Double {
        return (28.7 * a1c) - 46.7
    }

    func calculate(readings: [GlucoseReading]) -> A1CEstimate? {
        guard !readings.isEmpty else { return nil }

        let values = readings.map { $0.valueInMgdL }
        let average = values.reduce(0, +) / Double(values.count)
        let estimated = estimateA1C(from: average)

        let earliest = readings.min(by: { $0.timestamp < $1.timestamp })?.timestamp ?? Date()
        let periodDays = Calendar.current.dateComponents([.day], from: earliest, to: Date()).day ?? 0

        return A1CEstimate(
            estimatedA1C: estimated,
            averageGlucose: average,
            readingCount: readings.count,
            periodDays: max(1, periodDays)
        )
    }

    func estimateForPeriod(readings: [GlucoseReading], days: Int) -> A1CEstimate? {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let filtered = readings.filter { $0.timestamp >= cutoff }
        return calculate(readings: filtered)
    }

    /// A1C interpretation text
    func interpretation(a1c: Double) -> (title: String, detail: String, recommendation: String) {
        switch a1c {
        case ..<5.7:
            return (
                "Normal",
                "Your estimated A1C indicates normal glucose levels.",
                "Continue healthy lifestyle habits and regular monitoring."
            )
        case 5.7..<6.5:
            return (
                "Prediabetes",
                "Your estimated A1C is in the prediabetes range.",
                "Consider dietary changes, exercise, and consulting your doctor."
            )
        case 6.5..<7.0:
            return (
                "Diabetes - Well Managed",
                "Your estimated A1C indicates diabetes but is near target.",
                "Continue current management plan with your healthcare provider."
            )
        case 7.0..<8.0:
            return (
                "Diabetes - Moderate",
                "Your estimated A1C suggests glucose control can be improved.",
                "Review your diet, medication, and exercise plan with your doctor."
            )
        case 8.0..<9.0:
            return (
                "Diabetes - High",
                "Your estimated A1C indicates elevated glucose levels.",
                "Schedule an appointment with your doctor soon."
            )
        default:
            return (
                "Diabetes - Very High",
                "Your estimated A1C is significantly elevated.",
                "Please contact your healthcare provider immediately."
            )
        }
    }
}
