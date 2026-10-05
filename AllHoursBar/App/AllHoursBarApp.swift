import SwiftUI

@main
struct AllHoursBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = AttendanceStore.shared

    var body: some Scene {
        MenuBarExtra {
            PopoverRoot()
                .environment(store)
        } label: {
            MenuBarLabel()
                .environment(store)
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Prefs.registerDefaults()
        AttendanceStore.shared.start()
        #if DEBUG
        DemoMode.presentIfRequested(store: AttendanceStore.shared)
        #endif
    }
}
