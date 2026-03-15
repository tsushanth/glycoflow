//
//  NotificationManager.swift
//  GlycoFlow
//

import Foundation
import UserNotifications

@MainActor
@Observable
final class NotificationManager {
    static let shared = NotificationManager()

    private(set) var isAuthorized = false
    private let center = UNUserNotificationCenter.current()

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            isAuthorized = granted
            return granted
        } catch {
            print("[Notifications] Authorization failed: \(error)")
            return false
        }
    }

    func checkAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
    }

    func scheduleGlucoseReminder(at time: Date, identifier: String = UUID().uuidString) async {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Time to Check Your Blood Sugar"
        content.body = "Log your glucose reading in GlycoFlow to stay on track."
        content.sound = .default
        content.badge = 1

        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await center.add(request)
        } catch {
            print("[Notifications] Schedule failed: \(error)")
        }
    }

    func scheduleMedicationReminder(medicationName: String, at time: Date, identifier: String = UUID().uuidString) async {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Medication Reminder"
        content.body = "Time to take your \(medicationName)."
        content.sound = .default

        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await center.add(request)
        } catch {
            print("[Notifications] Schedule medication reminder failed: \(error)")
        }
    }

    func cancelReminder(identifier: String) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    func cancelAllReminders() {
        center.removeAllPendingNotificationRequests()
    }

    func getPendingReminders() async -> [UNNotificationRequest] {
        return await center.pendingNotificationRequests()
    }
}
