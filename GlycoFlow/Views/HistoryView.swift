//
//  HistoryView.swift
//  GlycoFlow
//

import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var context
    @Environment(PremiumManager.self) private var premiumManager
    @Query(sort: \GlucoseReading.timestamp, order: .reverse) private var readings: [GlucoseReading]
    @State private var searchText = ""
    @State private var selectedFilter: ReadingType? = nil
    @State private var showingPaywall = false

    private var filteredReadings: [GlucoseReading] {
        var result = readings
        if let filter = selectedFilter {
            result = result.filter { $0.type == filter }
        }
        if !searchText.isEmpty {
            result = result.filter { reading in
                reading.type.rawValue.localizedCaseInsensitiveContains(searchText) ||
                reading.notes.localizedCaseInsensitiveContains(searchText) ||
                reading.status.rawValue.localizedCaseInsensitiveContains(searchText)
            }
        }
        // Premium gate: limit to 50 readings for free users
        if !premiumManager.isPremium {
            return Array(result.prefix(50))
        }
        return result
    }

    private var groupedReadings: [(key: String, readings: [GlucoseReading])] {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        var groups: [String: [GlucoseReading]] = [:]
        for reading in filteredReadings {
            let key = Calendar.current.isDateInToday(reading.timestamp) ? "Today" :
                      Calendar.current.isDateInYesterday(reading.timestamp) ? "Yesterday" :
                      formatter.string(from: reading.timestamp)
            groups[key, default: []].append(reading)
        }
        return groups.sorted { lhs, rhs in
            if lhs.key == "Today" { return true }
            if rhs.key == "Today" { return false }
            if lhs.key == "Yesterday" { return true }
            if rhs.key == "Yesterday" { return false }
            return lhs.key > rhs.key
        }.map { (key: $0.key, readings: $0.value) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter Chips
                filterChips

                if filteredReadings.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(groupedReadings, id: \.key) { group in
                            Section(group.key) {
                                ForEach(group.readings) { reading in
                                    HistoryReadingRow(reading: reading)
                                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                            Button(role: .destructive) {
                                                deleteReading(reading)
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                }
                            }
                        }

                        if !premiumManager.isPremium && readings.count > 50 {
                            Section {
                                premiumUpgradeRow
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("History")
            .searchable(text: $searchText, prompt: "Search readings")
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
        }
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "All", isSelected: selectedFilter == nil) {
                    selectedFilter = nil
                }
                ForEach(ReadingType.allCases, id: \.self) { type in
                    FilterChip(title: type.rawValue, isSelected: selectedFilter == type) {
                        selectedFilter = selectedFilter == type ? nil : type
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.largeTitle)
                .foregroundStyle(.gray)
            Text("No Readings Found")
                .font(.headline)
            Text("Your glucose history will appear here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var premiumUpgradeRow: some View {
        Button {
            showingPaywall = true
        } label: {
            HStack {
                Image(systemName: "lock.fill")
                    .foregroundStyle(.yellow)
                Text("Unlock Full History — Upgrade to Premium")
                    .font(.subheadline)
            }
        }
    }

    private func deleteReading(_ reading: GlucoseReading) {
        context.delete(reading)
        try? context.save()
    }
}

// MARK: - History Reading Row
struct HistoryReadingRow: View {
    let reading: GlucoseReading

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(statusColor(reading.status).opacity(0.15))
                    .frame(width: 44, height: 44)
                Text(reading.displayValue)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(statusColor(reading.status))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(reading.type.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
                if !reading.notes.isEmpty {
                    Text(reading.notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(reading.unit)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(reading.timestamp, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

// MARK: - Filter Chip
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color.gray.opacity(0.15))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}
