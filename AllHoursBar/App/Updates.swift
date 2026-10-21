import Observation
import Sparkle

/// Sparkle, set up to stay out of the way. It checks the appcast attached to the latest GitHub release once a
/// week (one small download; see Config/Info.plist), and an update a scheduled check finds waits in the menu
/// instead of opening a window over whatever you're doing.
@MainActor
@Observable
final class Updates: NSObject {
    static let shared = Updates()

    /// An update a scheduled check found, until the user looks at it.
    private(set) var pending: Pending?
    private(set) var canCheck = false

    struct Pending: Equatable {
        let version: String
        /// Already downloaded (automatic updates), so installing is just a relaunch.
        let isReady: Bool
    }

    @ObservationIgnored private var controller: SPUStandardUpdaterController?
    @ObservationIgnored private var canCheckObservation: NSKeyValueObservation?

    var checksAutomatically: Bool {
        get {
            access(keyPath: \.checksAutomatically)
            return controller?.updater.automaticallyChecksForUpdates ?? false
        }
        set {
            withMutation(keyPath: \.checksAutomatically) { controller?.updater.automaticallyChecksForUpdates = newValue }
        }
    }

    var installsAutomatically: Bool {
        get {
            access(keyPath: \.installsAutomatically)
            return controller?.updater.automaticallyDownloadsUpdates ?? false
        }
        set {
            withMutation(keyPath: \.installsAutomatically) { controller?.updater.automaticallyDownloadsUpdates = newValue }
        }
    }

    var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–"
    }

    func start() {
        guard controller == nil else { return }
        let controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: self)
        self.controller = controller
        canCheckObservation = controller.updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] updater, _ in
            MainActor.assumeIsolated { self?.canCheck = updater.canCheckForUpdates }
        }
    }

    /// Opens Sparkle's window: the pending update if there is one, otherwise a fresh check.
    func checkNow() {
        controller?.checkForUpdates(nil)
    }
}

extension Updates: @preconcurrency SPUStandardUserDriverDelegate {
    var supportsGentleScheduledUpdateReminders: Bool { true }

    /// A menu bar app has no window to bring forward, so scheduled finds never pop up; they show in the menu.
    func standardUserDriverShouldHandleShowingScheduledUpdate(_ update: SUAppcastItem, andInImmediateFocus immediateFocus: Bool) -> Bool {
        false
    }

    func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState) {
        guard !handleShowingUpdate else { return }
        pending = Pending(version: update.displayVersionString, isReady: state.stage != .notDownloaded)
    }

    func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        pending = nil
    }

    func standardUserDriverWillFinishUpdateSession() {
        pending = nil
    }
}
