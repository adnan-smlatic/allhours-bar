import AppKit
import Observation

struct Profile: Codable, Equatable {
    var userId: String
    var firstName: String
    var lastName: String
    var email: String

    var displayName: String {
        let name = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? email : name
    }

    var initials: String {
        let letters = [firstName, lastName].compactMap(\.first)
        return letters.isEmpty ? String(email.prefix(1)).uppercased() : String(letters).uppercased()
    }
}

/// One of the company's clock buttons (Arrival, Departure, Lunch, Business trip, …).
struct ClockAction: Identifiable, Equatable {
    let id: String
    let name: String
    let kind: ClockingKind
    let isEnabled: Bool
    /// Lower = the main button of its kind (e.g. "Departure" before "Private exit").
    var rank = Int.max
}

/// A clocking registered today.
struct DayEvent: Identifiable, Equatable {
    let id: String
    let date: Date
    let name: String
    let kind: ClockingKind
    /// When the clocking was registered; orders clockings that share the same minute.
    var recordedAt: Date?
}

struct DayStats {
    var worked: TimeInterval = 0
    var breaks: TimeInterval = 0
    var firstIn: Date?
    /// Start of the interval that is still running (work or break).
    var openSince: Date?
}

struct Banner: Identifiable, Equatable {
    enum Style { case success, error }
    let id = UUID()
    let style: Style
    let message: String
    var undoClockingId: String?
}

@MainActor
@Observable
final class AttendanceStore {
    static let shared = AttendanceStore()

    enum Phase { case launching, signedOut, signedIn }

    private(set) var phase: Phase = .launching
    private(set) var profile: Profile?
    private(set) var presence: UserPresence?
    private(set) var actions: [ClockAction] = []
    private(set) var clockingEnabled = true
    private(set) var clientIP: String?
    private(set) var events: [DayEvent] = []
    private(set) var balance: CurrentBalance?
    private(set) var lastUpdated: Date?
    private(set) var isRefreshing = false
    private(set) var busyActionId: String?
    private(set) var isSigningIn = false
    private(set) var now = Date()
    private(set) var signInError: String?
    /// Filled after a session expires so the sign-in form isn't empty.
    private(set) var prefill: Credentials?
    var banner: Banner?

    let tokens = TokenProvider()
    let client: AllHoursClient
    let reminders = Reminders()

    @ObservationIgnored private var kinds: [String: ClockingKind] = [:]
    @ObservationIgnored private var ranks: [String: Int] = [:]
    /// Today's required work time, derived from All Hours' "time left today".
    private(set) var requiredToday: TimeInterval?
    @ObservationIgnored private var definitions: [ClockingDefinition] = []
    @ObservationIgnored private var ticker: Task<Void, Never>?
    @ObservationIgnored private var lastWake = Date.distantPast
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var isDemo = false

    private init() {
        client = AllHoursClient(tokens: tokens)
    }

    var credentialsMethod: Credentials.Method? { tokens.credentials?.method }

    // MARK: - Lifecycle

    func start() {
        guard ticker == nil else { return }
        #if DEBUG
        if DemoMode.isOn { return loadDemo() }
        #endif
        reminders.setUp()
        observeSystemEvents()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(20))
                await self?.tick()
            }
        }

        Task {
            await tokens.loadSavedSession()
            if tokens.credentials != nil {
                profile = Prefs.cachedProfile
                phase = .signedIn
                await bootstrap()
            } else {
                phase = .signedOut
            }
        }
    }

    func popoverDidOpen() {
        guard !isDemo else { return }
        now = Date()
        if Date().timeIntervalSince(lastUpdated ?? .distantPast) > 20 {
            Task { await refresh() }
        }
    }

    private func tick() async {
        now = Date()
        reminders.evaluate(self)
        if phase == .signedIn, Date().timeIntervalSince(lastUpdated ?? .distantPast) > 5 * 60 {
            await refresh()
        }
    }

    private func bootstrap() async {
        do {
            try await loadIdentity()
            await loadDefinitions()
            await refresh()
        } catch {
            handle(error)
        }
    }

    // MARK: - Session

    /// "Sign in with All Hours": the official login page in a window.
    func signInWithAllHours() async {
        await signIn {
            let grant = try await WebSignIn.run()
            try await self.tokens.completeWebSignIn(grant)
        }
    }

    /// Email + password or API key, typed into the popover.
    func signIn(_ creds: Credentials) async {
        await signIn {
            try await self.tokens.signIn(with: creds)
            UserDefaults.standard.set(creds.email, forKey: Prefs.lastEmail)
            UserDefaults.standard.set(creds.clientId, forKey: Prefs.lastClientId)
            UserDefaults.standard.set(creds.method.rawValue, forKey: Prefs.lastMethod)
        }
    }

    func cancelSignIn() {
        WebSignIn.cancel()
    }

    private func signIn(using authenticate: () async throws -> Void) async {
        guard !isSigningIn else { return }
        isSigningIn = true
        signInError = nil
        defer { isSigningIn = false }
        do {
            try await authenticate()
            try await loadIdentity()
            prefill = nil
            phase = .signedIn
            await loadDefinitions()
            await refresh()
            reminders.requestAuthorization()
        } catch is CancellationError {
            tokens.signOut()
        } catch {
            tokens.signOut()
            profile = nil
            signInError = error.localizedDescription
        }
    }

    func signOut() {
        if tokens.credentials?.method == .web {
            Task { await WebSignIn.clearSession() }
        }
        tokens.signOut()
        resetState()
        Prefs.cachedProfile = nil
        signInError = nil
        phase = .signedOut
    }

    private func expireSession(_ message: String) {
        prefill = tokens.credentials.map {
            var creds = $0
            creds.password = ""
            creds.refreshToken = nil
            return creds
        }
        signOut()
        signInError = message
    }

    private func resetState() {
        profile = nil
        presence = nil
        actions = []
        events = []
        balance = nil
        banner = nil
        lastUpdated = nil
        kinds = [:]
        ranks = [:]
        definitions = []
        requiredToday = nil
    }

    private func handle(_ error: Error) {
        if case AuthError.rejected(let message) = error {
            expireSession(message)
        } else {
            banner = Banner(style: .error, message: error.localizedDescription)
        }
    }

    // MARK: - Loading

    /// Works out which All Hours user we are.
    private func loadIdentity() async throws {
        guard let creds = tokens.credentials else { throw AuthError.rejected("Please sign in.") }
        switch creds.method {
        case .web, .password:
            if let clock = try await soft({ try await self.client.get(ClockResponse.self, "Clocks/Web") }),
               let presence = clock.status, let userId = presence.userId, !userId.isEmpty {
                profile = Profile(userId: userId, firstName: presence.firstName ?? "", lastName: presence.lastName ?? "", email: await accountEmail(creds))
                apply(clock)
            } else {
                let users = try await client.get(FlexibleList<UserBasic>.self, "Users/Basic").items
                guard let me = users.first else { throw APIError.message("Couldn't find your All Hours user.") }
                let parts = (me.name ?? "").split(separator: " ", maxSplits: 1).map(String.init)
                profile = Profile(userId: me.id, firstName: parts.first ?? "", lastName: parts.dropFirst().first ?? "", email: await accountEmail(creds))
            }
        case .apiKey:
            func match(_ users: [UserRecord]) -> UserRecord? {
                users.first { $0.email?.caseInsensitiveCompare(creds.email) == .orderedSame }
            }
            var me = match(try await client.get(FlexibleList<UserRecord>.self, "Users", query: ["searchTerm": creds.email]).items)
            if me == nil {
                me = match(try await client.get(FlexibleList<UserRecord>.self, "Users").items)
            }
            guard let me else { throw APIError.message("No All Hours user has the email \(creds.email).") }
            profile = Profile(userId: me.id, firstName: me.firstName ?? "", lastName: me.lastName ?? "", email: creds.email)
        }
        Prefs.cachedProfile = profile
    }

    /// The typed email, or for web sign-in whatever the identity server tells us.
    private func accountEmail(_ creds: Credentials) async -> String {
        guard creds.method == .web else { return creds.email }
        let claims = await tokens.userInfo() ?? [:]
        return ["email", "preferred_username", "name"].lazy.compactMap { claims[$0] as? String }.first ?? ""
    }

    /// Clocking definitions tell us which button is Arrival / Departure / Break / Return.
    private func loadDefinitions() async {
        guard let method = credentialsMethod else { return }
        var list: [ClockingDefinition] = []
        if method != .apiKey {
            list = (try? await client.get(FlexibleList<ClockingDefinition>.self, "ClockingDefinitions/Personal").items) ?? []
        }
        if list.isEmpty {
            list = (try? await client.get(FlexibleList<ClockingDefinition>.self, "ClockingDefinitions").items) ?? []
        }
        definitions = list
        kinds = Dictionary(
            list.compactMap { def in def.type.flatMap(ClockingKind.init(rawValue:)).map { (def.id.lowercased(), $0) } },
            uniquingKeysWith: { first, _ in first }
        )
        // The definition code orders the company's buttons; 0 means "custom".
        ranks = Dictionary(
            list.compactMap { def in def.code.map { (def.id.lowercased(), $0 > 0 ? $0 : 1000) } },
            uniquingKeysWith: { first, _ in first }
        )
    }

    func refresh() async {
        guard phase == .signedIn, !isDemo, let method = credentialsMethod, !isRefreshing else { return }
        isRefreshing = true
        defer {
            isRefreshing = false
            now = Date()
        }
        do {
            if profile == nil { try await loadIdentity() }
            if kinds.isEmpty { await loadDefinitions() }
            guard let userId = profile?.userId else { return }

            switch method {
            case .web, .password:
                apply(try await client.get(ClockResponse.self, "Clocks/Web"))
            case .apiKey:
                presence = try await presenceFromList(userId: userId)
                actions = definitions
                    .filter { $0.isActive ?? true }
                    .compactMap { def in
                        guard let kind = def.type.flatMap(ClockingKind.init(rawValue:)), kind != .automatic else { return nil }
                        return ClockAction(id: def.id, name: def.name ?? "Clocking", kind: kind, isEnabled: true, rank: rank(for: def.id))
                    }
            }

            if let list = try await soft({ try await self.todaysEvents(method: method, userId: userId) }) {
                events = list
            }
            if let value = try await soft({ try await self.client.get(CurrentBalance.self, "Presence/\(userId)") }) {
                balance = value
                if value.balanceResponseMode == 2, let minutesVsPlan = value.balance {
                    now = Date()
                    requiredToday = max(0, day.worked - TimeInterval(minutesVsPlan * 60))
                }
            }
            lastUpdated = Date()
            if banner?.style == .error { banner = nil }
        } catch {
            handle(error)
        }
        reminders.evaluate(self)
    }

    private func apply(_ clock: ClockResponse) {
        presence = clock.status
        clockingEnabled = clock.clockingEnabled ?? true
        clientIP = clock.clientIpAddress
        actions = (clock.clockingButtons ?? []).map { button in
            ClockAction(
                id: button.clockingDefinitionId,
                name: button.clockingDefinitionName ?? "Clocking",
                kind: kind(for: button.clockingDefinitionId, name: button.clockingDefinitionName),
                isEnabled: button.isEnabled ?? true,
                rank: rank(for: button.clockingDefinitionId)
            )
        }
    }

    private func presenceFromList(userId: String) async throws -> UserPresence? {
        func find(_ status: PresenceStatus) -> UserPresence? {
            status.userPresences?.first { $0.userId?.lowercased() == userId.lowercased() }
        }
        let term = profile?.lastName.isEmpty == false ? profile!.lastName : (profile?.firstName ?? "")
        if let found = find(try await client.get(PresenceStatus.self, "Presence/Current", query: ["searchTerm": term, "limit": "200"])) {
            return found
        }
        return find(try await client.get(PresenceStatus.self, "Presence/Current", query: ["limit": "2000"]))
    }

    private func todaysEvents(method: Credentials.Method, userId: String) async throws -> [DayEvent] {
        let start = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        let clockings: [Clocking] = switch method {
        case .web, .password:
            try await client.get(FlexibleList<Clocking>.self, "Clockings/Personal", query: ["dateFrom": APIDate.string(start)]).items
        case .apiKey:
            try await client.get(FlexibleList<Clocking>.self, "Clockings", query: ["dateFrom": APIDate.string(start), "dateTo": APIDate.string(end)])
                .items.filter { $0.userId?.lowercased() == userId.lowercased() }
        }
        return clockings
            .compactMap { clocking in
                guard let date = APIDate.parse(clocking.timestamp), date >= start, date < end else { return nil }
                return DayEvent(
                    id: clocking.id,
                    date: date,
                    name: clocking.clockingDefinitionName ?? "Clocking",
                    kind: kind(for: clocking.clockingDefinitionId ?? "", name: clocking.clockingDefinitionName),
                    recordedAt: APIDate.parse(clocking.createdOn)
                )
            }
            .sorted { ($0.date, $0.recordedAt ?? $0.date) < ($1.date, $1.recordedAt ?? $1.date) }
    }

    private func kind(for definitionId: String, name: String?) -> ClockingKind {
        kinds[definitionId.lowercased()] ?? .guess(from: name)
    }

    private func rank(for definitionId: String) -> Int {
        ranks[definitionId.lowercased()] ?? 1000
    }

    /// Runs a secondary request; auth failures still propagate, anything else just yields nil.
    private func soft<T>(_ work: () async throws -> T) async throws -> T? {
        do {
            return try await work()
        } catch let error as AuthError {
            throw error
        } catch {
            return nil
        }
    }

    // MARK: - Clocking

    func perform(_ action: ClockAction) async {
        guard let userId = profile?.userId, busyActionId == nil else { return }
        #if DEBUG
        if isDemo { return performDemo(action) }
        #endif
        busyActionId = action.id
        defer { busyActionId = nil }
        do {
            let data = try await client.post("Clockings/Authentic", json: [
                "UserId": userId,
                "ClockingDefinitionId": action.id,
                "Origin": 2, // web clock
            ])
            let created = try? AllHoursClient.decoder.decode(CreatedClocking.self, from: data)
            showBanner(Banner(style: .success, message: "\(action.name) · \(Fmt.time(Date()))", undoClockingId: created?.id))
            await refresh()
        } catch {
            handle(error)
        }
    }

    /// Used by notification actions ("Clock In" / "Clock Out").
    func perform(_ kind: ClockingKind) async {
        if actions.isEmpty { await refresh() }
        if let action = quickAction(kind) {
            await perform(action)
        }
    }

    /// The main enabled button of a kind.
    func quickAction(_ kind: ClockingKind) -> ClockAction? {
        actions.filter { $0.kind == kind && $0.isEnabled }.min { $0.rank < $1.rank }
    }

    func undo(_ clockingId: String) async {
        banner = nil
        #if DEBUG
        if isDemo { return }
        #endif
        do {
            try await client.delete("Clockings/\(clockingId)/Undo")
            showBanner(Banner(style: .success, message: "Clocking undone"))
            await refresh()
        } catch {
            handle(error)
        }
    }

    private func showBanner(_ banner: Banner) {
        self.banner = banner
        let id = banner.id
        Task {
            try? await Task.sleep(for: .seconds(10))
            if self.banner?.id == id { self.banner = nil }
        }
    }

    // MARK: - Derived state

    var status: UserStatus? { presence?.userStatus.flatMap(UserStatus.init(rawValue:)) }

    var primaryAction: ClockAction? {
        switch status {
        case .clockedIn, .workFromHome: quickAction(.departure)
        case .offsiteWork: quickAction(.returning) ?? quickAction(.arrival)
        case .onBreak, .absenceStarted: quickAction(.arrival) ?? quickAction(.returning)
        default: quickAction(.arrival)
        }
    }

    /// Big-button title: what the click means right now.
    var primaryVerb: String? {
        guard let action = primaryAction else { return nil }
        if status?.isPaused == true || status == .offsiteWork { return "Back to Work" }
        return action.verb
    }

    var secondaryActions: [ClockAction] {
        let primaryId = primaryAction?.id
        return actions.filter { action in
            guard action.isEnabled, action.id != primaryId else { return false }
            guard let status else { return true }
            if status.isWorking { return action.kind != .arrival && action.kind != .returning }
            if !status.isPaused { return action.kind == .arrival }
            return action.kind != .absenceStart
        }
    }

    /// Worked and break time today, derived from today's clockings and the live status.
    var day: DayStats {
        let start = Calendar.current.startOfDay(for: now)
        var stats = DayStats()
        var workingSince: Date?
        var pausedSince: Date?
        let timeline = events.filter { $0.kind != .automatic }

        if timeline.first?.kind == .departure {
            workingSince = start // shift carried over from yesterday
        } else if timeline.isEmpty, status?.isWorking == true {
            workingSince = max(start, APIDate.parse(presence?.eventTimestamp) ?? start)
        }

        for event in timeline {
            switch event.kind {
            case .arrival, .returning:
                if let paused = pausedSince { stats.breaks += event.date.timeIntervalSince(paused) }
                pausedSince = nil
                if workingSince == nil { workingSince = event.date }
                if stats.firstIn == nil { stats.firstIn = event.date }
            case .departure, .absenceStart:
                if let working = workingSince { stats.worked += event.date.timeIntervalSince(working) }
                workingSince = nil
                pausedSince = event.kind == .absenceStart ? event.date : nil
            case .automatic:
                break
            }
        }

        if let working = workingSince, status?.isWorking ?? true {
            stats.worked += now.timeIntervalSince(working)
            stats.openSince = working
        } else if status?.isWorking == true, pausedSince == nil,
                  let since = APIDate.parse(presence?.eventTimestamp) {
            // All Hours says you're in, but the clockings didn't show an open stretch: trust the status.
            let from = max(since, timeline.last?.date ?? start)
            stats.worked += now.timeIntervalSince(from)
            stats.openSince = from
        } else if let paused = pausedSince {
            if status?.isWorking == true {
                stats.worked += now.timeIntervalSince(paused) // e.g. an off-site work trip
            } else if status?.isPaused ?? true {
                stats.breaks += now.timeIntervalSince(paused)
            }
            stats.openSince = paused
        }
        return stats
    }

    /// Required time today according to All Hours, or a standard 8h day until it answers.
    var dailyGoal: TimeInterval {
        requiredToday ?? 8 * 3600
    }

    /// A weekday morning, the clock-in reminder window has started, and there's no arrival yet today.
    var isClockInOverdue: Bool {
        guard phase == .signedIn, let status, status.isOut,
              UserDefaults.standard.bool(forKey: Prefs.remindClockIn) else { return false }
        let calendar = Calendar.current
        guard !calendar.isDateInWeekend(now) else { return false }
        let minutes = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
        let after = UserDefaults.standard.integer(forKey: Prefs.remindClockInAfter)
        guard minutes >= after, minutes < after + 6 * 60 else { return false }
        return !events.contains { $0.kind == .arrival || $0.kind == .returning }
    }

    var isClockOutDue: Bool {
        guard phase == .signedIn, status?.isWorking == true,
              UserDefaults.standard.bool(forKey: Prefs.remindClockOut) else { return false }
        let calendar = Calendar.current
        let minutes = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
        return minutes >= UserDefaults.standard.integer(forKey: Prefs.remindClockOutAt)
    }

    var menuBarSymbol: String {
        switch phase {
        case .launching: return "clock"
        case .signedOut: return "clock.badge.questionmark"
        case .signedIn:
            if isClockInOverdue { return "clock.badge.exclamationmark" }
            switch status {
            case .clockedIn: return "clock.fill"
            case .workFromHome: return "house.fill"
            case .offsiteWork: return "car.fill"
            case .onBreak, .absenceStarted: return "cup.and.saucer.fill"
            case .allDayAbsence: return "beach.umbrella.fill"
            default: return "clock"
            }
        }
    }

    var menuBarText: String? {
        // Wait for the first full refresh: the status arrives before today's clockings.
        guard phase == .signedIn, lastUpdated != nil, let status else { return nil }
        if status.isWorking { return Fmt.clock(day.worked) }
        if status.isPaused, let since = day.openSince { return Fmt.clock(now.timeIntervalSince(since)) }
        return nil
    }

    // MARK: - System events

    private func observeSystemEvents() {
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification, NSWorkspace.screensDidWakeNotification] {
            observers.append(workspace.addObserver(forName: name, object: nil, queue: .main) { _ in
                Task { @MainActor in await AttendanceStore.shared.handleWake() }
            })
        }
        observers.append(DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.screenIsUnlocked"), object: nil, queue: .main
        ) { _ in
            Task { @MainActor in await AttendanceStore.shared.handleWake() }
        })
    }

    /// Back at the Mac: refresh right away so the clock-in reminder can fire while you're sitting down.
    private func handleWake() async {
        guard phase == .signedIn, Date().timeIntervalSince(lastWake) > 30 else { return }
        lastWake = Date()
        try? await Task.sleep(for: .seconds(3)) // give Wi-Fi a moment
        await refresh()
    }
}

#if DEBUG
// MARK: - Demo mode (see DemoMode.swift): sample data, no network.

extension AttendanceStore {
    private func loadDemo() {
        isDemo = true
        guard !DemoMode.signedOut else {
            phase = .signedOut
            return
        }

        // A fixed afternoon so screenshots always tell the same story.
        let today = Calendar.current.startOfDay(for: Date())
        func at(_ hour: Int, _ minute: Int) -> Date { today.addingTimeInterval(TimeInterval(hour * 3600 + minute * 60)) }

        profile = Profile(userId: "demo", firstName: "Alex", lastName: "Morgan", email: "alex@example.com")
        actions = [
            ClockAction(id: "in", name: "Arrival", kind: .arrival, isEnabled: true, rank: 1),
            ClockAction(id: "out", name: "Departure", kind: .departure, isEnabled: true, rank: 3),
            ClockAction(id: "lunch", name: "Lunch break", kind: .absenceStart, isEnabled: true, rank: 5),
            ClockAction(id: "trip", name: "Business trip", kind: .absenceStart, isEnabled: true, rank: 4),
            ClockAction(id: "back", name: "Return", kind: .returning, isEnabled: true, rank: 2),
        ]
        events = [
            DayEvent(id: "1", date: at(8, 4), name: "Arrival", kind: .arrival),
            DayEvent(id: "2", date: at(12, 1), name: "Lunch break", kind: .absenceStart),
            DayEvent(id: "3", date: at(12, 31), name: "Return", kind: .returning),
        ]
        presence = UserPresence(userId: "demo", firstName: "Alex", lastName: "Morgan", userStatus: UserStatus.clockedIn.rawValue,
                                eventTimestamp: APIDate.string(at(12, 31)), clockingDefinitionName: "Return")
        now = at(15, 12)
        if DemoMode.onBreak {
            events.append(DayEvent(id: "4", date: at(15, 2), name: "Lunch break", kind: .absenceStart))
            presence?.userStatus = UserStatus.onBreak.rawValue
            presence?.eventTimestamp = APIDate.string(at(15, 2))
            presence?.clockingDefinitionName = "Lunch break"
        }
        balance = CurrentBalance(balance: -82, balanceText: nil, runningBalance: 754, vacationBalance: 12, balanceResponseMode: 2)
        requiredToday = 8 * 3600
        lastUpdated = Date()
        phase = .signedIn
    }

    private func performDemo(_ action: ClockAction) {
        let status: UserStatus = switch action.kind {
        case .arrival, .returning: .clockedIn
        case .departure: .clockedOut
        case .absenceStart: action.name.contains("trip") ? .offsiteWork : .onBreak
        case .automatic: status ?? .clockedIn
        }
        let date = now.addingTimeInterval(60)
        events.append(DayEvent(id: UUID().uuidString, date: date, name: action.name, kind: action.kind))
        presence?.userStatus = status.rawValue
        presence?.eventTimestamp = APIDate.string(date)
        presence?.clockingDefinitionName = action.name
        now = date
        showBanner(Banner(style: .success, message: "\(action.name) · \(Fmt.time(date))", undoClockingId: "demo"))
    }
}
#endif
