import Foundation
import UserNotifications

/// "You're not clocked in" / "Still clocked in" notifications, each at most once a day,
/// with an action button that registers the clocking without opening anything.
@MainActor
final class Reminders: NSObject, UNUserNotificationCenterDelegate {
    private enum Kind: String {
        case clockIn = "CLOCK_IN"
        case clockOut = "CLOCK_OUT"
    }

    private nonisolated static let performAction = "PERFORM"
    private let center = UNUserNotificationCenter.current()

    /// Button titles shown on the notifications; they name the company's real clock buttons.
    private var actionTitles: [Kind: String] = [:]

    func setUp() {
        center.delegate = self
    }

    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func evaluate(_ store: AttendanceStore) {
        let defaults = UserDefaults.standard
        let today = Calendar.current.startOfDay(for: Date()).timeIntervalSinceReferenceDate

        if store.isClockInOverdue {
            if defaults.double(forKey: Prefs.lastClockInReminder) != today {
                defaults.set(today, forKey: Prefs.lastClockInReminder)
                let action = store.quickAction(.arrival)
                let body = action.map { "Good morning! Clock in at the office, or use “\($0.name)” below." }
                    ?? "Good morning! Don't forget to clock in today."
                post(.clockIn, title: "You're not clocked in", body: body, actionTitle: action?.name)
            }
        } else {
            center.removeDeliveredNotifications(withIdentifiers: [Kind.clockIn.rawValue])
        }

        if store.isClockOutDue {
            if defaults.double(forKey: Prefs.lastClockOutReminder) != today {
                defaults.set(today, forKey: Prefs.lastClockOutReminder)
                post(.clockOut, title: "Still clocked in",
                     body: "You've worked \(Fmt.duration(store.day.worked)) today. Don't forget to clock out when you leave.",
                     actionTitle: store.quickAction(.departure)?.name)
            }
        } else if store.status?.isWorking != true {
            center.removeDeliveredNotifications(withIdentifiers: [Kind.clockOut.rawValue])
        }
    }

    private func post(_ kind: Kind, title: String, body: String, actionTitle: String?) {
        actionTitles[kind] = actionTitle
        center.setNotificationCategories(Set([Kind.clockIn, .clockOut].map { kind in
            UNNotificationCategory(
                identifier: kind.rawValue,
                actions: actionTitles[kind].map { [UNNotificationAction(identifier: Self.performAction, title: $0)] } ?? [],
                intentIdentifiers: []
            )
        }))

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = kind.rawValue
        center.add(UNNotificationRequest(identifier: kind.rawValue, content: content, trigger: nil))
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let kind = Kind(rawValue: response.notification.request.content.categoryIdentifier)
        let tappedAction = response.actionIdentifier == Self.performAction
        Task { @MainActor in
            if tappedAction, let kind {
                await AttendanceStore.shared.perform(kind == .clockIn ? ClockingKind.arrival : .departure)
            }
            completionHandler()
        }
    }
}
