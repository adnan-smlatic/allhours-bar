import SwiftUI

/// The status item: a clock that fills in while you're at work, plus today's time.
struct MenuBarLabel: View {
    @Environment(AttendanceStore.self) private var store
    @AppStorage(Prefs.showTimer) private var showTimer = true

    var body: some View {
        if showTimer, let text = store.menuBarText {
            HStack(spacing: 4) {
                Image(systemName: store.menuBarSymbol)
                Text(text).monospacedDigit()
            }
        } else {
            Image(systemName: store.menuBarSymbol)
        }
    }
}
