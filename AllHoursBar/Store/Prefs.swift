import Foundation

/// UserDefaults keys. Views read them through @AppStorage with the same defaults.
enum Prefs {
    static let showTimer = "showTimerInMenuBar"
    static let showDayDetails = "showDayDetails"
    static let remindClockIn = "remindClockIn"
    static let remindClockInAfter = "remindClockInAfter"
    static let remindClockOut = "remindClockOut"
    static let remindClockOutAt = "remindClockOutAt"
    static let lastClockInReminder = "lastClockInReminder"
    static let lastClockOutReminder = "lastClockOutReminder"
    static let lastEmail = "lastEmail"
    static let lastClientId = "lastClientId"
    static let lastMethod = "lastMethod"
    static let profile = "profile"

    static let defaultClockInAfter = 8 * 60
    static let defaultClockOutAt = 17 * 60

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            showTimer: true,
            remindClockIn: true,
            remindClockInAfter: defaultClockInAfter,
            remindClockOut: true,
            remindClockOutAt: defaultClockOutAt,
        ])
    }

    static var cachedProfile: Profile? {
        get { UserDefaults.standard.data(forKey: profile).flatMap { try? JSONDecoder().decode(Profile.self, from: $0) } }
        set { UserDefaults.standard.set(newValue.flatMap { try? JSONEncoder().encode($0) }, forKey: profile) }
    }
}
