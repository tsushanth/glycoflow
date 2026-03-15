//
//  ContentView.swift
//  GlycoFlow
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(PremiumManager.self) private var premiumManager
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("selectedTab") private var selectedTab = 0

    var body: some View {
        if !hasCompletedOnboarding {
            OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
        } else {
            MainTabView(selectedTab: $selectedTab)
        }
    }
}

struct MainTabView: View {
    @Binding var selectedTab: Int
    @Environment(PremiumManager.self) private var premiumManager

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "drop.fill")
                }
                .tag(0)

            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.fill")
                }
                .tag(1)

            LogReadingView()
                .tabItem {
                    Label("Log", systemImage: "plus.circle.fill")
                }
                .tag(2)

            TrendsView()
                .tabItem {
                    Label("Trends", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(3)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(4)
        }
        .tint(.blue)
    }
}
