//
//  ReportsView.swift
//  GlycoFlow
//

import SwiftUI
import SwiftData

struct ReportsView: View {
    @Environment(\.modelContext) private var context
    @Environment(PremiumManager.self) private var premiumManager
    @Query(sort: \GlucoseReading.timestamp, order: .reverse) private var readings: [GlucoseReading]
    @Query(sort: \MedicationLog.timestamp, order: .reverse) private var medications: [MedicationLog]
    @Query private var profiles: [UserProfile]
    @State private var reportsVM = ReportsViewModel()
    @State private var showingPaywall = false

    var profile: UserProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Period Selector
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Report Period")
                            .font(.headline)
                        Picker("Period", selection: $reportsVM.selectedPeriod) {
                            ForEach(ReportPeriod.allCases, id: \.self) { period in
                                Text(period.displayName).tag(period)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))

                    // Summary Preview
                    reportSummaryCard

                    // Generate Button
                    if premiumManager.isPremium {
                        Button {
                            Task {
                                await reportsVM.generateReport(
                                    readings: readings,
                                    medications: medications,
                                    profile: profile
                                )
                            }
                        } label: {
                            HStack {
                                if reportsVM.isGenerating {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "doc.fill")
                                }
                                Text(reportsVM.isGenerating ? "Generating..." : "Generate PDF Report")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(reportsVM.isGenerating)
                    } else {
                        Button {
                            showingPaywall = true
                        } label: {
                            HStack {
                                Image(systemName: "lock.fill")
                                    .foregroundStyle(.yellow)
                                Text("Unlock PDF Reports — Go Premium")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.blue.opacity(0.15))
                            .foregroundStyle(.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }

                    // Doctor sharing tip
                    HStack(spacing: 8) {
                        Image(systemName: "stethoscope")
                            .foregroundStyle(.blue)
                        Text("Share your report directly with your doctor via email or AirDrop.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.blue.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))

                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("Reports")
            .sheet(isPresented: $reportsVM.showShareSheet) {
                if let url = reportsVM.generatedPDFURL {
                    ShareSheet(activityItems: [url])
                }
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
            .alert("Error", isPresented: .init(
                get: { reportsVM.errorMessage != nil },
                set: { if !$0 { reportsVM.errorMessage = nil } }
            )) {
                Button("OK") { reportsVM.errorMessage = nil }
            } message: {
                Text(reportsVM.errorMessage ?? "")
            }
        }
    }

    private var reportSummaryCard: some View {
        let cutoff = Calendar.current.date(byAdding: .day, value: -reportsVM.selectedPeriod.days, to: Date()) ?? Date()
        let filteredReadings = readings.filter { $0.timestamp >= cutoff }
        let analytics = GlucoseAnalytics.shared.computeSummary(readings: filteredReadings)

        return VStack(alignment: .leading, spacing: 12) {
            Text("Report Preview")
                .font(.headline)

            HStack {
                ReportStatItem(label: "Readings", value: "\(analytics.readingCount)")
                Divider()
                ReportStatItem(label: "Average", value: analytics.readingCount > 0 ? "\(Int(analytics.average))" : "—")
                Divider()
                ReportStatItem(label: "In Range", value: "\(analytics.timeInRange.inRangePercent)%")
                Divider()
                if let a1c = A1CCalculator.shared.estimateForPeriod(readings: filteredReadings, days: reportsVM.selectedPeriod.days) {
                    ReportStatItem(label: "Est. A1C", value: a1c.displayA1C)
                } else {
                    ReportStatItem(label: "Est. A1C", value: "—")
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct ReportStatItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
