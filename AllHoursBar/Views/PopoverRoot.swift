import SwiftUI

struct PopoverRoot: View {
    @Environment(AttendanceStore.self) private var store
    @State private var showSettings: Bool = {
        #if DEBUG
        DemoMode.settings
        #else
        false
        #endif
    }()

    var body: some View {
        Group {
            switch store.phase {
            case .launching:
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, minHeight: 160)
            case .signedOut:
                SignInView()
            case .signedIn:
                if showSettings {
                    SettingsPage(isPresented: $showSettings)
                } else {
                    DashboardView(showSettings: $showSettings)
                }
            }
        }
        .frame(width: 320)
        .onAppear { store.popoverDidOpen() }
        .onChange(of: store.phase) { showSettings = false }
    }
}
