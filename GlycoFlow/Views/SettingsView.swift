//
//  SettingsView.swift
//  GlycoFlow
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(PremiumManager.self) private var premiumManager
    @Query private var profiles: [UserProfile]
    @State private var showingPaywall = false
    @State private var showingHealthKit = false
    @State private var showingReports = false
    @State private var showingMedications = false
    @State private var showingFoodLog = false
    @State private var healthKitLoading = false
    @State private var targetLow: Double = 70
    @State private var targetHigh: Double = 180
    @State private var preferredUnit: GlucoseUnit = .mgdL
    @State private var remindersEnabled = false
    @State private var showingDeleteConfirm = false

    var profile: UserProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            List {
                // Premium Status
                Section {
                    if premiumManager.isPremium {
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                            Text("Premium Active")
                                .fontWeight(.semibold)
                            Spacer()
                            Text("Thank you!")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Button {
                            showingPaywall = true
                        } label: {
                            HStack {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(.yellow)
                                VStack(alignment: .leading) {
                                    Text("Upgrade to Premium")
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.primary)
                                    Text("Unlock all features")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // Target Range
                Section("Target Range") {
                    HStack {
                        Text("Low Threshold")
                        Spacer()
                        Text("\(Int(targetLow)) mg/dL")
                            .foregroundStyle(.blue)
                    }
                    Slider(value: $targetLow, in: 50...120, step: 5) {
                        Text("Low")
                    }
                    .onChange(of: targetLow) { _, _ in saveProfile() }

                    HStack {
                        Text("High Threshold")
                        Spacer()
                        Text("\(Int(targetHigh)) mg/dL")
                            .foregroundStyle(.orange)
                    }
                    Slider(value: $targetHigh, in: 140...300, step: 5) {
                        Text("High")
                    }
                    .onChange(of: targetHigh) { _, _ in saveProfile() }

                    Picker("Preferred Unit", selection: $preferredUnit) {
                        ForEach(GlucoseUnit.allCases, id: \.self) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                    .onChange(of: preferredUnit) { _, _ in saveProfile() }
                }

                // Integrations
                Section("Integrations") {
                    Button {
                        guard !healthKitLoading else { return }
                        healthKitLoading = true
                        Task {
                            let granted = await HealthKitService.shared.requestAuthorization()
                            healthKitLoading = false
                            if granted {
                                AnalyticsService.shared.track(.healthKitConnected)
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "heart.fill")
                                .foregroundStyle(.red)
                            Text("Connect Apple Health")
                            Spacer()
                            if healthKitLoading {
                                ProgressView()
                            } else if HealthKitService.shared.isAuthorized {
                                Text("Connected")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            } else {
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                    .disabled(healthKitLoading)
                }

                // More Features
                Section("More Features") {
                    NavigationLink {
                        MedicationView()
                    } label: {
                        Label("Medications & Insulin", systemImage: "pills.fill")
                    }

                    NavigationLink {
                        FoodLogView()
                    } label: {
                        Label("Food Log", systemImage: "fork.knife")
                    }

                    NavigationLink {
                        ReportsView()
                    } label: {
                        Label("Doctor Reports", systemImage: "doc.fill")
                    }
                }

                // Reminders
                Section("Reminders") {
                    Toggle("Enable Reminders", isOn: $remindersEnabled)
                        .onChange(of: remindersEnabled) { _, enabled in
                            if enabled {
                                Task {
                                    let granted = await NotificationManager.shared.requestAuthorization()
                                    if !granted { remindersEnabled = false }
                                }
                            }
                        }
                }

                // About
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }

                    Link(destination: URL(string: "https://glycoflow.app/privacy")!) {
                        Label("Privacy Policy", systemImage: "lock.shield.fill")
                    }

                    Link(destination: URL(string: "https://glycoflow.app/terms")!) {
                        Label("Terms of Service", systemImage: "doc.text.fill")
                    }

                    Button {
                        if let url = URL(string: "mailto:support@glycoflow.app") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("Contact Support", systemImage: "envelope.fill")
                    }
                    .foregroundStyle(.primary)

                    if let url = URL(string: "https://apps.apple.com/app/idXXXXXXXXX?action=write-review") {
                        Link(destination: url) {
                            Label("Rate GlycoFlow", systemImage: "star.fill")
                        }
                    }
                }

                // Danger Zone
                Section {
                    Button(role: .destructive) {
                        showingDeleteConfirm = true
                    } label: {
                        Label("Delete All Data", systemImage: "trash.fill")
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                if let p = profile {
                    targetLow = p.targetLow
                    targetHigh = p.targetHigh
                    preferredUnit = p.unit
                    remindersEnabled = p.remindersEnabled
                }
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
            .confirmationDialog("Delete All Data", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
                Button("Delete Everything", role: .destructive) {
                    deleteAllData()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all your glucose readings, medications, and food entries. This cannot be undone.")
            }
        }
    }

    private func saveProfile() {
        if let p = profile {
            p.targetLow = targetLow
            p.targetHigh = targetHigh
            p.preferredUnit = preferredUnit.rawValue
            try? context.save()
            AnalyticsService.shared.track(.settingsChanged(key: "target_range"))
        }
    }

    private func deleteAllData() {
        try? context.delete(model: GlucoseReading.self)
        try? context.delete(model: MedicationLog.self)
        try? context.delete(model: FoodEntry.self)
        try? context.delete(model: A1CEstimate.self)
        try? context.save()
    }
}
