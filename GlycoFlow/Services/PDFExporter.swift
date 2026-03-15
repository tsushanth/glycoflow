//
//  PDFExporter.swift
//  GlycoFlow
//

import Foundation
import UIKit
import PDFKit

@MainActor
final class PDFExporter {
    static let shared = PDFExporter()

    func generateReport(
        readings: [GlucoseReading],
        medications: [MedicationLog],
        profile: UserProfile?,
        period: ReportPeriod = .month
    ) -> Data? {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let data = renderer.pdfData { context in
            context.beginPage()
            drawHeader(in: pageRect, profile: profile, period: period)
            drawSummary(readings: readings, in: pageRect, startY: 140)
            drawReadingsTable(readings: Array(readings.prefix(50)), in: pageRect, startY: 320)
        }
        return data
    }

    private func drawString(_ string: String, at point: CGPoint, withAttributes attrs: [NSAttributedString.Key: Any]) {
        (string as NSString).draw(at: point, withAttributes: attrs)
    }

    private func drawHeader(in rect: CGRect, profile: UserProfile?, period: ReportPeriod) {
        let titleAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 22),
            .foregroundColor: UIColor.systemBlue
        ]
        drawString("GlycoFlow — Blood Sugar Report", at: CGPoint(x: 40, y: 40), withAttributes: titleAttr)

        let subtitleAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13),
            .foregroundColor: UIColor.gray
        ]
        let dateStr = DateFormatter.localizedString(from: Date(), dateStyle: .long, timeStyle: .none)
        drawString("Generated: \(dateStr) | Period: \(period.displayName)", at: CGPoint(x: 40, y: 68), withAttributes: subtitleAttr)

        if let name = profile?.name, !name.isEmpty {
            drawString("Patient: \(name)", at: CGPoint(x: 40, y: 88), withAttributes: subtitleAttr)
        }

        let line = UIBezierPath()
        line.move(to: CGPoint(x: 40, y: 115))
        line.addLine(to: CGPoint(x: 572, y: 115))
        UIColor.lightGray.setStroke()
        line.stroke()
    }

    private func drawSummary(readings: [GlucoseReading], in rect: CGRect, startY: CGFloat) {
        guard !readings.isEmpty else { return }
        let analytics = GlucoseAnalytics.shared.computeSummary(readings: readings)
        let a1cEstimate = A1CCalculator.shared.estimateA1C(from: analytics.average)

        let headerAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 14),
            .foregroundColor: UIColor.black
        ]
        drawString("Summary Statistics", at: CGPoint(x: 40, y: startY), withAttributes: headerAttr)

        let valueAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.darkGray
        ]
        let items = [
            "Total Readings: \(analytics.readingCount)",
            "Average Glucose: \(Int(analytics.average)) mg/dL",
            "Min / Max: \(Int(analytics.min)) / \(Int(analytics.max)) mg/dL",
            "Std Deviation: \(String(format: "%.1f", analytics.standardDeviation)) mg/dL",
            "Estimated A1C: \(String(format: "%.1f", a1cEstimate))%",
            "Time In Range: \(analytics.timeInRange.inRangePercent)%"
        ]
        for (i, item) in items.enumerated() {
            let col = i < 3 ? 0 : 1
            let row = i < 3 ? i : i - 3
            let x = col == 0 ? 40.0 : 320.0
            let y = startY + 22 + Double(row) * 22
            drawString(item, at: CGPoint(x: x, y: y), withAttributes: valueAttr)
        }
    }

    private func drawReadingsTable(readings: [GlucoseReading], in rect: CGRect, startY: CGFloat) {
        let headerAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 13),
            .foregroundColor: UIColor.black
        ]
        drawString("Recent Readings", at: CGPoint(x: 40, y: startY), withAttributes: headerAttr)

        let colHeaderAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 11),
            .foregroundColor: UIColor.gray
        ]
        drawString("Date/Time", at: CGPoint(x: 40, y: startY + 22), withAttributes: colHeaderAttr)
        drawString("Value", at: CGPoint(x: 230, y: startY + 22), withAttributes: colHeaderAttr)
        drawString("Type", at: CGPoint(x: 310, y: startY + 22), withAttributes: colHeaderAttr)
        drawString("Status", at: CGPoint(x: 440, y: startY + 22), withAttributes: colHeaderAttr)

        let rowAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11),
            .foregroundColor: UIColor.darkGray
        ]
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"

        for (i, reading) in readings.enumerated() {
            let y = startY + 42 + CGFloat(i) * 18
            if y > 750 { break }
            drawString(formatter.string(from: reading.timestamp), at: CGPoint(x: 40, y: y), withAttributes: rowAttr)
            drawString("\(reading.displayValue) \(reading.unit)", at: CGPoint(x: 230, y: y), withAttributes: rowAttr)
            drawString(reading.type.rawValue, at: CGPoint(x: 310, y: y), withAttributes: rowAttr)
            drawString(reading.status.rawValue, at: CGPoint(x: 440, y: y), withAttributes: rowAttr)
        }
    }

    func saveToDocuments(data: Data, filename: String = "GlycoFlow_Report.pdf") -> URL? {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let url = docs?.appendingPathComponent(filename)
        guard let url else { return nil }
        try? data.write(to: url)
        return url
    }
}

// MARK: - Report Period
enum ReportPeriod: String, CaseIterable {
    case week = "week"
    case month = "month"
    case threeMonths = "3months"
    case sixMonths = "6months"
    case year = "year"

    var displayName: String {
        switch self {
        case .week: return "Last 7 Days"
        case .month: return "Last 30 Days"
        case .threeMonths: return "Last 90 Days"
        case .sixMonths: return "Last 6 Months"
        case .year: return "Last Year"
        }
    }

    var days: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .threeMonths: return 90
        case .sixMonths: return 180
        case .year: return 365
        }
    }
}
