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
    @State private var isVisible = false

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
        // Updates that land while the menu is closed (the minute ticking over, a background refresh)
        // apply without animating, so a hidden window never renders animation frames.
        .transaction { transaction in
            if !isVisible {
                transaction.animation = nil
                transaction.disablesAnimations = true
            }
        }
        .background(WindowVisibility { isVisible = $0 })
        .onChange(of: isVisible) {
            if isVisible { store.popoverDidOpen() }
        }
        .onChange(of: store.phase) { showSettings = false }
    }
}

/// Reports whether the menu's window is on screen. MenuBarExtra keeps the window, and every view in it,
/// alive while the menu is closed, so `onAppear` / `onDisappear` don't track opening and closing.
private struct WindowVisibility: NSViewRepresentable {
    let onChange: (Bool) -> Void

    func makeNSView(context: Context) -> ObserverView { ObserverView() }

    func updateNSView(_ view: ObserverView, context: Context) {
        view.onChange = onChange
    }

    final class ObserverView: NSView {
        var onChange: (Bool) -> Void = { _ in }
        private var observer: NSObjectProtocol?
        private var reported: Bool?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            observer.map(NotificationCenter.default.removeObserver)
            observer = window.map { window in
                NotificationCenter.default.addObserver(
                    forName: NSWindow.didChangeOcclusionStateNotification, object: window, queue: .main
                ) { [weak self] _ in
                    MainActor.assumeIsolated { self?.report() }
                }
            }
            report()
        }

        private func report() {
            let visible = window?.occlusionState.contains(.visible) == true
            guard visible != reported else { return }
            reported = visible
            // Not while SwiftUI may be mid-update (this also runs from viewDidMoveToWindow).
            Task { @MainActor [onChange] in onChange(visible) }
        }
    }
}
