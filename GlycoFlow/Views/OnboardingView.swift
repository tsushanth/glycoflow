//
//  OnboardingView.swift
//  GlycoFlow
//

import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @Environment(\.modelContext) private var context
    @State private var currentPage = 0
    @State private var name = ""
    @State private var selectedDiabetesType: DiabetesType = .type2
    @State private var targetLow: Double = 70
    @State private var targetHigh: Double = 180
    @State private var preferredUnit: GlucoseUnit = .mgdL
    @State private var requestHealthKit = false

    private let pages = [
        OnboardingPage(
            icon: "drop.fill",
            title: "Welcome to GlycoFlow",
            subtitle: "Your personal blood glucose tracker. Log readings, track trends, and share reports with your doctor.",
            color: .blue
        ),
        OnboardingPage(
            icon: "chart.line.uptrend.xyaxis",
            title: "Smart Analytics",
            subtitle: "View daily, weekly, and monthly trends. Get your estimated A1C and time-in-range stats.",
            color: .green
        ),
        OnboardingPage(
            icon: "heart.text.square.fill",
            title: "HealthKit Integration",
            subtitle: "Sync glucose readings with Apple Health for a complete health picture.",
            color: .red
        ),
        OnboardingPage(
            icon: "doc.fill",
            title: "Doctor Reports",
            subtitle: "Export professional PDF reports to share with your healthcare provider.",
            color: .orange
        ),
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                ForEach(0..<pages.count, id: \.self) { index in
                    OnboardingPageView(page: pages[index])
                        .tag(index)
                }

                // Profile Setup Page
                profileSetupPage
                    .tag(pages.count)

                // Health Kit Page
                healthKitPage
                    .tag(pages.count + 1)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            // Navigation Buttons
            HStack {
                if currentPage > 0 {
                    Button("Back") {
                        withAnimation { currentPage -= 1 }
                    }
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    if currentPage < pages.count + 1 {
                        withAnimation { currentPage += 1 }
                    } else {
                        completeOnboarding()
                    }
                } label: {
                    Text(currentPage == pages.count + 1 ? "Get Started" : "Next")
                        .fontWeight(.semibold)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(.blue)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    private var profileSetupPage: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)
                    .padding(.top, 40)

                Text("Set Up Your Profile")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Help us personalize your experience")
                    .foregroundStyle(.secondary)

                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Your Name")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        TextField("Enter your name", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Diabetes Type")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Picker("Diabetes Type", selection: $selectedDiabetesType) {
                            ForEach(DiabetesType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.navigationLink)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Preferred Unit")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Picker("Unit", selection: $preferredUnit) {
                            ForEach(GlucoseUnit.allCases, id: \.self) { unit in
                                Text(unit.rawValue).tag(unit)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Target Range: \(Int(targetLow)) – \(Int(targetHigh)) mg/dL")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        VStack(spacing: 8) {
                            HStack {
                                Text("Low: \(Int(targetLow))")
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                                Slider(value: $targetLow, in: 50...120, step: 5)
                            }
                            HStack {
                                Text("High: \(Int(targetHigh))")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                                Slider(value: $targetHigh, in: 140...300, step: 5)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)

                Spacer()
            }
        }
    }

    private var healthKitPage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "heart.fill")
                .font(.system(size: 70))
                .foregroundStyle(.red)

            Text("Connect to Apple Health")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Sync your glucose readings with the Health app for a complete picture of your health data.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Toggle("Enable HealthKit Sync", isOn: $requestHealthKit)
                .padding(.horizontal, 32)

            Spacer()
        }
    }

    private func completeOnboarding() {
        // Save profile
        let profile = UserProfile(
            name: name,
            diabetesType: selectedDiabetesType,
            targetLow: targetLow,
            targetHigh: targetHigh,
            preferredUnit: preferredUnit
        )
        context.insert(profile)
        try? context.save()

        // Request HealthKit if enabled
        if requestHealthKit {
            Task {
                await HealthKitService.shared.requestAuthorization()
            }
        }

        AnalyticsService.shared.track(.onboardingCompleted)
        hasCompletedOnboarding = true
    }
}

// MARK: - Onboarding Page Model
struct OnboardingPage {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
}

// MARK: - Onboarding Page View
struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(page.color.opacity(0.15))
                    .frame(width: 130, height: 130)
                Image(systemName: page.icon)
                    .font(.system(size: 60))
                    .foregroundStyle(page.color)
            }

            Text(page.title)
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            Text(page.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
    }
}
