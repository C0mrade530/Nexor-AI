import Foundation
import UserNotifications
import UIKit

/// Push notification registration and local notification scheduling.
@MainActor
class NotificationService: ObservableObject {
    static let shared = NotificationService()

    @Published var isEnabled = false
    @Published var deviceToken: String?

    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            isEnabled = granted
            if granted {
                UIApplication.shared.registerForRemoteNotifications()
            }
            return granted
        } catch {
            print("Notification permission failed: \(error)")
            return false
        }
    }

    func registerToken(_ token: Data) {
        let tokenString = token.map { String(format: "%02.2hhx", $0) }.joined()
        deviceToken = tokenString

        // Send to backend
        Task {
            do {
                let _: EmptyResponse = try await APIClient.shared.post(
                    "/notifications/register",
                    body: ["device_token": tokenString, "platform": "ios"]
                )
            } catch {
                print("Token registration failed: \(error)")
            }
        }
    }

    /// Schedule a local notification (for offline reminders).
    func scheduleLocal(
        title: String,
        body: String,
        at date: Date,
        identifier: String? = nil
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let id = identifier ?? UUID().uuidString
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error)")
            }
        }
    }

    /// Schedule the daily summary reminder.
    func scheduleDailySummaryReminder(hour: Int = 21, minute: Int = 0) {
        let content = UNMutableNotificationContent()
        content.title = "Your day is ready"
        content.body = "Generate your daily summary to capture today's insights, ideas, and commitments"
        content.sound = .default
        content.categoryIdentifier = "daily_summary"

        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: "daily_summary_reminder", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }

    /// Cancel all scheduled notifications.
    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
