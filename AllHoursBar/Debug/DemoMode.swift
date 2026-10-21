#if DEBUG
import SwiftUI

/// Debug-only launch arguments for trying the UI without an account and for README/website screenshots:
///
///     open AllHoursBar.app --args --demo [--demo-window [--demo-snapshot=/path.png]]
///         [--demo-settings | --demo-signed-out | --demo-break] [--demo-light | --demo-dark]
enum DemoMode {
    private static let args = Set(CommandLine.arguments)

    static var isOn: Bool { args.contains("--demo") }
    static var signedOut: Bool { args.contains("--demo-signed-out") }
    static var settings: Bool { args.contains("--demo-settings") }
    static var onBreak: Bool { args.contains("--demo-break") }

    /// Shows the popover content in a regular window, so it can be captured with `screencapture -l`.
    @MainActor
    static func presentIfRequested(store: AttendanceStore) {
        guard isOn else { return }
        if args.contains("--demo-dark") { NSApp.appearance = NSAppearance(named: .darkAqua) }
        if args.contains("--demo-light") { NSApp.appearance = NSAppearance(named: .aqua) }
        guard args.contains("--demo-window") else { return }

        let content = PopoverRoot()
            .environment(store)
            .environment(Updates.shared)
            .background(Color(nsColor: .windowBackgroundColor))
        let hosting = NSHostingView(rootView: content)
        hosting.sizingOptions = [.preferredContentSize]

        // Borderless and floating: square corners and nothing on top, so a plain region capture is clean.
        let window = KeyableWindow(contentRect: NSRect(origin: .zero, size: hosting.fittingSize),
                                   styleMask: [.borderless], backing: .buffered, defer: false)
        window.level = .floating
        window.hasShadow = false
        window.title = "All Hours Bar Demo"
        window.contentView = hosting
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
        demoWindow = window

        if let path = args.first(where: { $0.hasPrefix("--demo-snapshot=") })?.split(separator: "=", maxSplits: 1).last {
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                snapshot(hosting, to: URL(fileURLWithPath: String(path)))
                NSApp.terminate(nil)
            }
        }
    }

    /// Renders the view at 2× into a PNG; works even when the screen is asleep.
    @MainActor
    private static func snapshot(_ view: NSView, to url: URL) {
        let bounds = view.bounds
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(bounds.width * 2), pixelsHigh: Int(bounds.height * 2),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else { return }
        rep.size = bounds.size
        view.cacheDisplay(in: bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
    }

    @MainActor private static var demoWindow: NSWindow?
}

/// Borderless windows can't become key by default, which renders controls in their inactive (grey) style.
private final class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}
#endif
