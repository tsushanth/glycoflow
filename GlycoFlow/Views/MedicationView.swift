//
//  MedicationView.swift
//  GlycoFlow
//

import SwiftUI
import SwiftData

struct MedicationView: View {
    @Environment(\.modelContext) private var context
    @State private var viewModel = MedicationViewModel()
    @State private var showingAddSheet = false
    @Query(sort: \MedicationLog.timestamp, order: .reverse) private var medications: [MedicationLog]

    private var todayMedications: [MedicationLog] {
        medications.filter { Calendar.current.isDateInToday($0.timestamp) }
    }

    var body: some View {
        NavigationStack {
            List {
                if !todayMedications.isEmpty {
                    Section("Today") {
                        ForEach(todayMedications) { med in
                            MedicationRow(medication: med) {
                                viewModel.toggleTaken(med, context: context)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    viewModel.deleteMedication(med, context: context)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }

                let older = medications.filter { !Calendar.current.isDateInToday($0.timestamp) }
                if !older.isEmpty {
                    Section("Previous") {
                        ForEach(older) { med in
                            MedicationRow(medication: med, onTap: nil)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        viewModel.deleteMedication(med, context: context)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }

                if medications.isEmpty {
                    ContentUnavailableView(
                        "No Medications",
                        systemImage: "pills.fill",
                        description: Text("Tap + to add your first medication or insulin log.")
                    )
                }
            }
            .navigationTitle("Medications")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddMedicationSheet(viewModel: viewModel)
            }
        }
    }
}

// MARK: - Medication Row
struct MedicationRow: View {
    let medication: MedicationLog
    let onTap: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            Button {
                onTap?()
            } label: {
                Image(systemName: medication.isTaken ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(medication.isTaken ? .green : .gray)
            }
            .buttonStyle(.plain)
            .disabled(onTap == nil)

            Image(systemName: medication.type.icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(medication.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                HStack(spacing: 4) {
                    Text(medication.type.rawValue)
                    if medication.insulin != .notApplicable {
                        Text("•")
                        Text(medication.insulin.rawValue)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(medication.displayDose)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(medication.timestamp, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .opacity(medication.isTaken ? 0.6 : 1.0)
    }
}

// MARK: - Add Medication Sheet
struct AddMedicationSheet: View {
    @Bindable var viewModel: MedicationViewModel
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let doseUnits = ["units", "mg", "mcg", "mL", "IU"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Medication") {
                    TextField("Name (e.g. Metformin, Lantus)", text: $viewModel.medicationName)

                    Picker("Type", selection: $viewModel.selectedMedicationType) {
                        ForEach(MedicationType.allCases, id: \.self) { type in
                            Label(type.rawValue, systemImage: type.icon).tag(type)
                        }
                    }

                    if viewModel.selectedMedicationType == .insulin {
                        Picker("Insulin Type", selection: $viewModel.selectedInsulinType) {
                            ForEach(InsulinType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                    }
                }

                Section("Dose") {
                    HStack {
                        TextField("Amount", text: $viewModel.dose)
                            .keyboardType(.decimalPad)
                        Picker("Unit", selection: $viewModel.unit) {
                            ForEach(doseUnits, id: \.self) { u in
                                Text(u).tag(u)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }

                Section("Time") {
                    DatePicker("When taken", selection: $viewModel.medicationDate)
                    Toggle("Taken", isOn: $viewModel.isTaken)
                }

                Section("Notes") {
                    TextEditor(text: $viewModel.notes)
                        .frame(minHeight: 60)
                }
            }
            .navigationTitle("Add Medication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.saveMedication(context: context)
                        if viewModel.errorMessage == nil {
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
