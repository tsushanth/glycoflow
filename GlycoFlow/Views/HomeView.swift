//
//  HomeView.swift
//  GlycoFlow
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Environment(PremiumManager.self) private var premiumManager
    @Query(sort: \GlucoseReading.timestamp, order: .reverse) private var readings: [GlucoseReading]
    @State private var viewModel = GlucoseViewModel()
    @State private var showingLogSheet = false
    @State private var showingPaywall = false

    private var latestReading: GlucoseReading? { readings.first }

    private var todayReadings: [GlucoseReading] {
        readings.filter { Calendar.current.isDateInToday($0.timestamp) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Current Reading Card
                    currentReadingCard

                    // Quick Stats
                    quickStatsRow

                    // Time In Range
                    if !readings.isEmpty {
                        timeInRangeCard
                    }

                    // Today's Readings
                    if !todayReadings.isEmpty {
                        todayReadingsSection
                    }

                    // Premium Banner
                    if !premiumManager.isPremium {
                        premiumBannerCard
                    }

                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("GlycoFlow")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingLogSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.blue)
                    }
                }
            }
            .sheet(isPresented: $showingLogSheet) {
                LogReadingView()
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
        }
    }

    // MARK: - Current Reading Card
    private var currentReadingCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Latest Reading")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
                if let reading = latestReading {
                    Text(reading.timestamp, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let reading = latestReading {
                HStack(alignment: .bottom, spacing: 8) {
                    Text(reading.displayValue)
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundStyle(statusColor(reading.status))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(reading.unit)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        Text(reading.status.rawValue)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(statusColor(reading.status))
                    }
                    .padding(.bottom, 10)

                    Spacer()

                    VStack(alignment: .trailing) {
                        Image(systemName: reading.type.icon)
                            .font(.title2)
                            .foregroundStyle(.blue)
                        Text(reading.type.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if !reading.notes.isEmpty {
                    Text(reading.notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "drop.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.blue.opacity(0.4))
                    Text("No readings yet")
                        .foregroundStyle(.secondary)
                    Button("Log Your First Reading") {
                        showingLogSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Quick Stats
    private var quickStatsRow: some View {
        HStack(spacing: 12) {
            StatCard(
                title: "Today",
                value: "\(todayReadings.count)",
                subtitle: "readings",
                icon: "drop.fill",
                color: .blue
            )

            StatCard(
                title: "Avg Today",
                value: todayReadings.isEmpty ? "—" : "\(Int(todayReadings.map { $0.valueInMgdL }.reduce(0, +) / Double(todayReadings.count)))",
                subtitle: "mg/dL",
                icon: "chart.bar.fill",
                color: .green
            )

            StatCard(
                title: "7-Day Avg",
                value: sevenDayAverage,
                subtitle: "mg/dL",
                icon: "chart.line.uptrend.xyaxis",
                color: .orange
            )
        }
    }

    private var sevenDayAverage: String {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let recent = readings.filter { $0.timestamp >= cutoff }
        guard !recent.isEmpty else { return "—" }
        let avg = recent.map { $0.valueInMgdL }.reduce(0, +) / Double(recent.count)
        return "\(Int(avg))"
    }

    // MARK: - Time In Range Card
    private var timeInRangeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Time In Range (30 Days)")
                .font(.headline)

            let analytics = GlucoseAnalytics.shared.computeSummary(readings: Array(readings.prefix(200)))
            let tir = analytics.timeInRange

            VStack(spacing: 8) {
                TIRBar(label: "In Range (70-180)", percent: tir.inRangePercent, color: .green)
                TIRBar(label: "Above Range (>180)", percent: tir.aboveRangePercent, color: .orange)
                TIRBar(label: "Very High (>250)", percent: tir.veryHighPercent, color: .red)
                TIRBar(label: "Below Range (<70)", percent: tir.belowRangePercent, color: .blue)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Today's Readings Section
    private var todayReadingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Readings")
                .font(.headline)

            ForEach(todayReadings.prefix(5)) { reading in
                ReadingRow(reading: reading)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Premium Banner
    private var premiumBannerCard: some View {
        Button {
            showingPaywall = true
        } label: {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Upgrade to Premium")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Unlimited history, PDF reports & advanced analytics")
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

    private func statusColor(_ status: GlucoseStatus) -> Color {
        switch status {
        case .low: return .blue
        case .normal: return .green
        case .high: return .orange
        case .veryHigh: return .red
        }
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - TIR Bar
struct TIRBar: View {
    let label: String
    let percent: Int
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(percent)%")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.gray.opacity(0.2))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(percent) / 100, height: 8)
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - Reading Row
struct ReadingRow: View {
    let reading: GlucoseReading

    var body: some View {
        HStack {
            Image(systemName: reading.type.icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(reading.type.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(reading.timestamp, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(reading.displayValue) \(reading.unit)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(reading.status.rawValue)
                    .font(.caption)
                    .foregroundStyle(statusColor(reading.status))
            }
        }
    }

    private func statusColor(_ status: GlucoseStatus) -> Color {
        switch status {
        case .low: return .blue
        case .normal: return .green
        case .high: return .orange
        case .veryHigh: return .red
        }
    }
}
