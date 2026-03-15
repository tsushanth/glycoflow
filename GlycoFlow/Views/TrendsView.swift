//
//  TrendsView.swift
//  GlycoFlow
//

import SwiftUI
import SwiftData
import Charts

struct TrendsView: View {
    @Environment(PremiumManager.self) private var premiumManager
    @Query(sort: \GlucoseReading.timestamp, order: .reverse) private var readings: [GlucoseReading]
    @State private var selectedPeriod: TrendPeriod = .week
    @State private var showingPaywall = false

    enum TrendPeriod: String, CaseIterable {
        case week = "7D"
        case month = "30D"
        case threeMonths = "90D"

        var days: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            case .threeMonths: return 90
            }
        }
    }

    private var periodReadings: [GlucoseReading] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -selectedPeriod.days, to: Date()) ?? Date()
        return readings.filter { $0.timestamp >= cutoff }
    }

    private var analytics: GlucoseAnalyticsSummary {
        GlucoseAnalytics.shared.computeSummary(readings: periodReadings)
    }

    private var dailyData: [(date: Date, average: Double)] {
        GlucoseAnalytics.shared.dailyAverages(readings: periodReadings, days: selectedPeriod.days)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Period Selector
                    periodSelector

                    // Glucose Chart
                    glucoseChartCard

                    // Analytics Summary
                    analyticsSummaryCard

                    // A1C Estimator
                    a1cCard

                    // Premium gate for 90D
                    if selectedPeriod == .threeMonths && !premiumManager.isPremium {
                        premiumGateCard
                    }

                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("Trends")
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
        }
    }

    // MARK: - Period Selector
    private var periodSelector: some View {
        Picker("Period", selection: $selectedPeriod) {
            ForEach(TrendPeriod.allCases, id: \.self) { period in
                Text(period.rawValue).tag(period)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Glucose Chart
    private var glucoseChartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Glucose Trend")
                .font(.headline)

            if dailyData.isEmpty {
                Text("Not enough data to display chart.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else {
                Chart {
                    // Target range area
                    RectangleMark(
                        xStart: .value("Start", dailyData.first?.date ?? Date()),
                        xEnd: .value("End", dailyData.last?.date ?? Date()),
                        yStart: .value("Low", 70.0),
                        yEnd: .value("High", 180.0)
                    )
                    .foregroundStyle(.green.opacity(0.1))

                    ForEach(dailyData, id: \.date) { item in
                        LineMark(
                            x: .value("Date", item.date),
                            y: .value("Glucose", item.average)
                        )
                        .foregroundStyle(.blue)
                        .lineStyle(StrokeStyle(lineWidth: 2))

                        AreaMark(
                            x: .value("Date", item.date),
                            y: .value("Glucose", item.average)
                        )
                        .foregroundStyle(.blue.opacity(0.1))

                        PointMark(
                            x: .value("Date", item.date),
                            y: .value("Glucose", item.average)
                        )
                        .foregroundStyle(.blue)
                        .symbolSize(30)
                    }

                    // Target lines
                    RuleMark(y: .value("Target Low", 70.0))
                        .foregroundStyle(.blue.opacity(0.5))
                        .lineStyle(StrokeStyle(dash: [4]))
                    RuleMark(y: .value("Target High", 180.0))
                        .foregroundStyle(.orange.opacity(0.5))
                        .lineStyle(StrokeStyle(dash: [4]))
                }
                .frame(height: 200)
                .chartYScale(domain: 40...350)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: selectedPeriod.days > 14 ? 7 : 1)) {
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Analytics Summary
    private var analyticsSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Summary (\(selectedPeriod.rawValue))")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                AnalyticsTile(title: "Average", value: analytics.readingCount > 0 ? "\(Int(analytics.average)) mg/dL" : "—", icon: "chart.bar.fill", color: .blue)
                AnalyticsTile(title: "Readings", value: "\(analytics.readingCount)", icon: "drop.fill", color: .green)
                AnalyticsTile(title: "Min / Max", value: analytics.readingCount > 0 ? "\(Int(analytics.min)) / \(Int(analytics.max))" : "—", icon: "arrow.up.arrow.down", color: .orange)
                AnalyticsTile(title: "Std Dev", value: analytics.readingCount > 0 ? "\(String(format: "%.1f", analytics.standardDeviation))" : "—", icon: "waveform", color: .purple)
                AnalyticsTile(title: "Time in Range", value: "\(analytics.timeInRange.inRangePercent)%", icon: "target", color: .green)
                AnalyticsTile(title: "Trend", value: analytics.trend.description, icon: analytics.trend.icon, color: .indigo)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - A1C Card
    private var a1cCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Estimated A1C")
                .font(.headline)

            if let estimate = A1CCalculator.shared.estimateForPeriod(readings: periodReadings, days: selectedPeriod.days) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(estimate.displayA1C)
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(estimate.categoryColor))
                        Text(estimate.category)
                            .font(.subheadline)
                            .foregroundStyle(Color(estimate.categoryColor))
                        Text("Based on \(estimate.readingCount) readings")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Avg Glucose")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(Int(estimate.averageGlucose)) mg/dL")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                }
                Text("This is an estimate. Lab A1C tests are the gold standard.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } else {
                Text("Log at least 14 days of readings to estimate A1C.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Premium Gate
    private var premiumGateCard: some View {
        Button {
            showingPaywall = true
        } label: {
            HStack {
                Image(systemName: "lock.fill")
                    .foregroundStyle(.yellow)
                VStack(alignment: .leading) {
                    Text("Unlock 90-Day Trends")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Upgrade to Premium for full history and advanced analytics")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

// MARK: - Analytics Tile
struct AnalyticsTile: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }
}
