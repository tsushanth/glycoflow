//
//  FoodLogView.swift
//  GlycoFlow
//

import SwiftUI
import SwiftData

struct FoodLogView: View {
    @Environment(\.modelContext) private var context
    @State private var viewModel = FoodViewModel()
    @State private var showingAddSheet = false
    @Query(sort: \FoodEntry.timestamp, order: .reverse) private var entries: [FoodEntry]

    private var todayEntries: [FoodEntry] {
        entries.filter { Calendar.current.isDateInToday($0.timestamp) }
    }

    private var todayCarbs: Double {
        todayEntries.reduce(0) { $0 + $1.carbGrams }
    }

    private var todayCalories: Double {
        todayEntries.reduce(0) { $0 + $1.calories }
    }

    var body: some View {
        NavigationStack {
            List {
                // Daily Summary
                if !todayEntries.isEmpty {
                    Section {
                        HStack {
                            DailySummaryBadge(title: "Carbs", value: "\(Int(todayCarbs))g", color: .orange)
                            DailySummaryBadge(title: "Calories", value: "\(Int(todayCalories))", color: .red)
                            DailySummaryBadge(title: "Meals", value: "\(todayEntries.count)", color: .blue)
                        }
                    }
                }

                // Today's Entries
                if !todayEntries.isEmpty {
                    Section("Today") {
                        ForEach(todayEntries) { entry in
                            FoodEntryRow(entry: entry)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        viewModel.deleteEntry(entry, context: context)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }

                // Previous Entries
                let older = entries.filter { !Calendar.current.isDateInToday($0.timestamp) }
                if !older.isEmpty {
                    Section("Previous") {
                        ForEach(older.prefix(20)) { entry in
                            FoodEntryRow(entry: entry)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        viewModel.deleteEntry(entry, context: context)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }

                if entries.isEmpty {
                    ContentUnavailableView(
                        "No Food Entries",
                        systemImage: "fork.knife.circle.fill",
                        description: Text("Track your meals and carbs to understand glucose patterns.")
                    )
                }
            }
            .navigationTitle("Food Log")
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
                AddFoodSheet(viewModel: viewModel)
            }
        }
    }
}

// MARK: - Daily Summary Badge
struct DailySummaryBadge: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Food Entry Row
struct FoodEntryRow: View {
    let entry: FoodEntry

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: entry.meal.icon)
                .font(.title3)
                .foregroundStyle(.orange)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                HStack(spacing: 8) {
                    Text(entry.meal.rawValue)
                    if entry.carbGrams > 0 {
                        Text("•")
                        Text("\(Int(entry.carbGrams))g carbs")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if entry.calories > 0 {
                    Text("\(Int(entry.calories)) cal")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                Text(entry.timestamp, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Add Food Sheet
struct AddFoodSheet: View {
    @Bindable var viewModel: FoodViewModel
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var showingNutritionFields = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Food Item") {
                    TextField("Food name", text: $viewModel.foodName)
                    TextField("Serving size", text: $viewModel.servingSize)

                    Picker("Meal", selection: $viewModel.selectedMealType) {
                        ForEach(MealType.allCases, id: \.self) { type in
                            Label(type.rawValue, systemImage: type.icon).tag(type)
                        }
                    }
                }

                Section("Carbohydrates") {
                    HStack {
                        Text("Carbs")
                        Spacer()
                        TextField("0", text: $viewModel.carbGrams)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("g")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Fiber")
                        Spacer()
                        TextField("0", text: $viewModel.fiberGrams)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("g")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Glycemic Index")
                        Spacer()
                        TextField("0-100", text: $viewModel.glycemicIndex)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                }

                Section {
                    DisclosureGroup("More Nutrition Info", isExpanded: $showingNutritionFields) {
                        NutritionField(label: "Calories", binding: $viewModel.calories, unit: "kcal")
                        NutritionField(label: "Protein", binding: $viewModel.proteinGrams, unit: "g")
                        NutritionField(label: "Fat", binding: $viewModel.fatGrams, unit: "g")
                    }
                }

                Section("Time") {
                    DatePicker("When", selection: $viewModel.entryDate)
                }

                Section("Notes") {
                    TextEditor(text: $viewModel.notes)
                        .frame(minHeight: 60)
                }
            }
            .navigationTitle("Add Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.saveEntry(context: context)
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

struct NutritionField: View {
    let label: String
    @Binding var binding: String
    let unit: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", text: $binding)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
            Text(unit)
                .foregroundStyle(.secondary)
        }
    }
}
