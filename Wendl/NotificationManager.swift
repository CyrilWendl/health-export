import Foundation
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()

    private init() {}

    func requestPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Permission request failed: \(error)")
            }

            if granted {
                print("Notification permission granted")
                self.scheduleDailyReminder()
            } else {
                print("Notification permission denied")
            }
        }
    }

    func scheduleDailyReminder() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["dailyReminder"])

        let content = UNMutableNotificationContent()
        content.title = "Export Your Weight"
        content.body = "Don’t forget to export your weight data to GitHub today."
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = 20  // 8 PM daily

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(identifier: "dailyReminder", content: content, trigger: trigger)

        center.add(request) { error in
            if let error = error {
                print("Failed to schedule reminder: \(error)")
            } else {
                print("Daily reminder scheduled")
            }
        }
    }
}
