import ServiceManagement
import SwiftUI
import UserNotifications

struct SettingsPage: View {
    @Environment(AttendanceStore.self) private var store
    @Binding var isPresented: Bool

    @AppStorage(Prefs.showTimer) private var showTimer = true
    @AppStorage(Prefs.remindClockIn) private var remindClockIn = true
    @AppStorage(Prefs.remindClockInAfter) private var clockInAfter = Prefs.defaultClockInAfter
    @AppStorage(Prefs.remindClockOut) private var remindClockOut = true
    @AppStorage(Prefs.remindClockOutAt) private var clockOutAt = Prefs.defaultClockOutAt

    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var launchError: String?
    @State private var notificationsDenied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                IconButton(symbol: "chevron.left", help: "Back") { isPresented = false }
                Text("Settings")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
            }
            .padding(.leading, -6)

            section("Account") {
                HStack(spacing: 10) {
                    Avatar(initials: store.profile?.initials ?? "–", tint: store.status?.tint ?? .secondary)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(store.profile?.displayName ?? "–")
                            .font(.system(size: 12, weight: .medium))
                        Text(accountSubtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Button("Sign Out") { store.signOut() }
                        .controlSize(.small)
                }
            }

            section("Menu Bar") {
                row("Show time worked next to the icon") {
                    Toggle("", isOn: $showTimer).labelsHidden()
                }
            }

            section("Reminders") {
                row("Clock-in reminder after") {
                    timePicker($clockInAfter).disabled(!remindClockIn)
                    Toggle("", isOn: $remindClockIn).labelsHidden()
                }
                Text("Weekdays, when your Mac wakes or unlocks and you haven't clocked in yet.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Divider()
                row("Clock-out reminder at") {
                    timePicker($clockOutAt).disabled(!remindClockOut)
                    Toggle("", isOn: $remindClockOut).labelsHidden()
                }
                if notificationsDenied {
                    Divider()
                    row("Notifications are off", symbol: "bell.slash.fill", tint: .paused) {
                        Button("Turn On…") {
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")!)
                        }
                        .controlSize(.small)
                    }
                }
            }

            section("General") {
                row("Open at login") {
                    Toggle("", isOn: Binding(
                        get: { launchAtLogin },
                        set: { setLaunchAtLogin($0) }
                    ))
                    .labelsHidden()
                }
                if let launchError {
                    Text(launchError)
                        .font(.system(size: 10.5))
                        .foregroundStyle(Color.clockOut)
                }
            }

            HStack {
                Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                    .controlSize(.small)
            }
        }
        .font(.system(size: 12))
        .toggleStyle(.switch)
        .controlSize(.small)
        .padding(14)
        .task {
            #if DEBUG
            if DemoMode.isOn { return }
            #endif
            store.reminders.requestAuthorization()
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            notificationsDenied = settings.authorizationStatus == .denied
        }
    }

    private var accountSubtitle: String {
        if let email = store.profile?.email, !email.isEmpty { return email }
        return store.credentialsMethod == .apiKey ? "Signed in with an API key" : "Signed in with All Hours"
    }

    private func row<Trailing: View>(
        _ title: String, symbol: String? = nil, tint: Color? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: 8) {
            if let symbol { Image(systemName: symbol).foregroundStyle(tint ?? .secondary) }
            Text(title)
                .foregroundStyle(tint ?? .primary)
                .lineLimit(1)
            Spacer(minLength: 8)
            trailing()
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(title)
            Card {
                VStack(alignment: .leading, spacing: 8) { content() }
            }
        }
    }

    private func timePicker(_ minutes: Binding<Int>) -> some View {
        DatePicker(
            "",
            selection: Binding(
                get: {
                    Calendar.current.date(bySettingHour: minutes.wrappedValue / 60, minute: minutes.wrappedValue % 60, second: 0, of: Date()) ?? Date()
                },
                set: { date in
                    let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                    minutes.wrappedValue = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
                }
            ),
            displayedComponents: .hourAndMinute
        )
        .labelsHidden()
        .datePickerStyle(.field)
        .fixedSize()
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchError = nil
        } catch {
            launchError = error.localizedDescription
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}
