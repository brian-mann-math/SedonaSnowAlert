import Foundation
import UserNotifications

@MainActor
class NotificationManager: ObservableObject {
    @Published var isAuthorized = false

    private var lastNotificationDates: Set<String> = []

    init() {
        loadLastNotificationDates()
        checkAuthorizationStatus()
    }

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                self.isAuthorized = granted
                if let error = error {
                    print("Notification permission error: \(error)")
                }
            }
        }
    }

    private func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }

    func sendSnowAlert(location: String, date: String, details: String) {
        // Avoid duplicate notifications for the same location/date on the same day
        let notificationKey = "\(location)-\(date)-\(Calendar.current.startOfDay(for: Date()))"

        guard !lastNotificationDates.contains(notificationKey) else {
            print("Already notified about \(location) \(date) today")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Snow Alert for \(location)!"
        content.subtitle = date
        content.body = details
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Deliver immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Notification error: \(error)")
            } else {
                DispatchQueue.main.async {
                    self.lastNotificationDates.insert(notificationKey)
                    self.saveLastNotificationDates()
                    print("Snow alert sent for \(date)")
                }
            }
        }
    }

    private func saveLastNotificationDates() {
        // Clean up old entries (keep only today's)
        let today = Calendar.current.startOfDay(for: Date())
        lastNotificationDates = lastNotificationDates.filter { key in
            key.contains(today.description)
        }
        UserDefaults.standard.set(Array(lastNotificationDates), forKey: "lastNotificationDates")
    }

    private func loadLastNotificationDates() {
        if let dates = UserDefaults.standard.array(forKey: "lastNotificationDates") as? [String] {
            lastNotificationDates = Set(dates)
        }
    }
}
