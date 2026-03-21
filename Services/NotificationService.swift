import Foundation
import UserNotifications

struct NotificationService {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()

    enum ScheduleOutcome {
        case scheduled(String)
        case disabled
        case triggerDatePassed
        case permissionDenied

        var identifier: String? {
            if case .scheduled(let identifier) = self {
                return identifier
            }
            return nil
        }
    }

    func requestPermissionIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    func schedule(for reminder: ReminderItem, vehicleName: String) async -> ScheduleOutcome {
        guard reminder.isEnabled, let dateDue = reminder.dateDue else { return .disabled }

        let triggerDate = Calendar.current.date(byAdding: .day, value: -reminder.notificationTiming.dayOffset, to: dateDue) ?? dateDue
        guard triggerDate > .now else { return .triggerDatePassed }

        let granted = await requestPermissionIfNeeded()
        guard granted else { return .permissionDenied }

        let identifier = reminder.notificationIdentifier ?? UUID().uuidString
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = "\(vehicleName) is due on \(AppFormatters.mediumDate.string(from: dateDue))."
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        try? await center.add(request)
        return .scheduled(identifier)
    }

    func cancel(identifier: String?) {
        guard let identifier else { return }
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
