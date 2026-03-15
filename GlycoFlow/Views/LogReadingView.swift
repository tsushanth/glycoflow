//
//  LogReadingView.swift
//  GlycoFlow
//

import SwiftUI
import SwiftData

struct LogReadingView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = GlucoseViewModel()

    var body: some View {
        NavigationStack {
            Form {
                // Glucose Value Section
                Section("Glucose Value") {
                    HStack {
                        TextField("Enter value", text: $viewModel.glucoseValue)
                            .keyboardType(.decimalPad)
                            .font(.title2)
                            .fontWeight(.semibold)

                        Picker("Unit", selection: $viewModel.selectedUnit) {
                            ForEach(GlucoseUnit.allCases, id: \.self) { unit in
                                Text(unit.rawValue).tag(unit)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 140)
                    }

                    // Visual indicator
                    if let value = Double(viewModel.glucoseValue), value > 0 {
                        let status = GlucoseStatus.status(for: value, unit: viewModel.selectedUnit)
                        HStack {
                            Circle()
                                .fill(statusColor(status))
                                .frame(width: 10, height: 10)
                            Text(status.rawValue)
                                .font(.caption)
                                .foregroundStyle(statusColor(status))
                            Spacer()
                        }
                    }
                }

                // Reading Type
                Section("Reading Type") {
                    Picker("Type", selection: $viewModel.selectedReadingType) {
                        ForEach(ReadingType.allCases, id: \.self) { type in
                            Label(type.rawValue, systemImage: type.icon).tag(type)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                // Date & Time
                Section("Date & Time") {
                    DatePicker("When", selection: $viewModel.readingDate)
                }

                // Notes
                Section("Notes (Optional)") {
                    TextEditor(text: $viewModel.notes)
                        .frame(minHeight: 80)
                }

                // Common Tags
                Section("Tags") {
                    TagSelector(selectedTags: $viewModel.selectedTags)
                }
            }
            .navigationTitle("Log Reading")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await viewModel.saveReading(context: context)
                            if viewModel.errorMessage == nil {
                                dismiss()
                            }
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(viewModel.glucoseValue.isEmpty || viewModel.isLoading)
                }
            }
            .alert("Error", isPresented: .init(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
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

// MARK: - Tag Selector
struct TagSelector: View {
    @Binding var selectedTags: [String]

    let availableTags = ["Stressed", "Exercise", "Sick", "Fasting", "After Meal", "Medication", "Travel", "Poor Sleep"]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(availableTags, id: \.self) { tag in
                    Button {
                        if selectedTags.contains(tag) {
                            selectedTags.removeAll { $0 == tag }
                        } else {
                            selectedTags.append(tag)
                        }
                    } label: {
                        Text(tag)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(selectedTags.contains(tag) ? Color.blue : Color.gray.opacity(0.2))
                            .foregroundStyle(selectedTags.contains(tag) ? .white : .primary)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}
