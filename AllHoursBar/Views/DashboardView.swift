import SwiftUI

struct DashboardView: View {
    @Environment(AttendanceStore.self) private var store
    @Binding var showSettings: Bool

    var body: some View {
        VStack(spacing: 12) {
            header
            hero
            if !store.clockingEnabled { clockingDisabledNotice }
            actionButtons
            if let banner = store.banner {
                BannerView(
                    banner: banner,
                    onUndo: { id in Task { await store.undo(id) } },
                    onDismiss: { store.banner = nil }
                )
            }
            if !store.events.isEmpty { timeline }
            stats
            Divider().padding(.horizontal, -14)
            footer
        }
        .padding(14)
        .animation(.snappy(duration: 0.25), value: store.banner)
        .animation(.snappy(duration: 0.25), value: store.actions)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            Avatar(initials: store.profile?.initials ?? "–", tint: store.status?.tint ?? .secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(store.profile?.displayName ?? "All Hours")
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text(Fmt.today(store.now))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if store.isRefreshing {
                ProgressView().controlSize(.small).frame(width: 26, height: 26)
            } else {
                IconButton(symbol: "arrow.clockwise", help: "Refresh") { Task { await store.refresh() } }
            }
            IconButton(symbol: "gearshape", help: "Settings") { showSettings = true }
        }
    }

    // MARK: Hero

    private var hero: some View {
        let day = store.day
        let status = store.status
        let tint = status?.tint ?? .secondary
        let goal = store.dailyGoal
        return Card(tint: status.map { $0.isOut ? Color.secondary : $0.tint }) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    StatusPill(title: status?.title ?? "Loading…", tint: tint, live: status?.isWorking == true)
                    Spacer()
                    if let detail = statusDetail {
                        Text(detail)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(Fmt.duration(day.worked))
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("worked today")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .animation(.snappy, value: Int(day.worked / 60))

                if goal > 0 {
                    VStack(spacing: 5) {
                        GoalBar(fraction: day.worked / goal, tint: day.worked >= goal ? .working : tint == .secondary ? .brandBottom : tint)
                        HStack {
                            Text("Goal \(Fmt.duration(goal))")
                            Spacer()
                            Text(day.worked >= goal
                                 ? "\(Fmt.duration(day.worked - goal)) over"
                                 : "\(Fmt.duration(goal - day.worked)) to go")
                        }
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var statusDetail: String? {
        guard let presence = store.presence else { return nil }
        let name = presence.absenceDefinitionName ?? presence.clockingDefinitionName
        let date = APIDate.parse(presence.eventTimestamp)
        switch (name, date) {
        case let (name?, date?): return "\(name) · \(Fmt.moment(date))"
        case let (nil, date?): return Fmt.moment(date)
        case let (name?, nil): return name
        default: return nil
        }
    }

    // MARK: Actions

    @ViewBuilder
    private var actionButtons: some View {
        if let primary = store.primaryAction {
            Button {
                Task { await store.perform(primary) }
            } label: {
                HStack(spacing: 8) {
                    if store.busyActionId == primary.id {
                        ProgressView().controlSize(.small).tint(.white)
                    } else {
                        Image(systemName: primary.symbol)
                    }
                    let verb = store.primaryVerb ?? primary.verb
                    Text(verb)
                    if verb != primary.name {
                        Text(primary.name)
                            .font(.system(size: 11, weight: .medium))
                            .opacity(0.75)
                    }
                }
            }
            .buttonStyle(ProminentButtonStyle(tint: primary.tint))
            .disabled(store.busyActionId != nil || !store.clockingEnabled)
        }

        let secondary = store.secondaryActions
        if !secondary.isEmpty {
            VStack(spacing: 8) {
                ForEach(Array(stride(from: 0, to: secondary.count, by: 2)), id: \.self) { start in
                    HStack(spacing: 8) {
                        ForEach(secondary[start..<min(start + 2, secondary.count)]) { action in
                            chip(action)
                        }
                    }
                }
            }
        }

        if store.actions.isEmpty && store.lastUpdated != nil {
            Text("No clock buttons are available for your account.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    private func chip(_ action: ClockAction) -> some View {
        Button {
            Task { await store.perform(action) }
        } label: {
            HStack(spacing: 6) {
                if store.busyActionId == action.id {
                    ProgressView().controlSize(.mini)
                } else {
                    Image(systemName: action.symbol).foregroundStyle(action.tint)
                }
                Text(action.name)
            }
        }
        .buttonStyle(ChipButtonStyle())
        .disabled(store.busyActionId != nil || !store.clockingEnabled)
        .help(action.name)
    }

    private var clockingDisabledNotice: some View {
        Label {
            Text("Clocking from the web is turned off for your account\(store.clientIP.map { " (from \($0))" } ?? "").")
        } icon: {
            Image(systemName: "lock.fill")
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Timeline

    private var timeline: some View {
        let events = store.events
        let visible = events.suffix(6)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionLabel("Today")
                Spacer()
                if events.count > visible.count {
                    Text("+\(events.count - visible.count) earlier")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
            VStack(spacing: 0) {
                ForEach(Array(visible.enumerated()), id: \.element.id) { index, event in
                    HStack(spacing: 10) {
                        ZStack {
                            if index < visible.count - 1 {
                                Rectangle()
                                    .fill(Color.primary.opacity(0.1))
                                    .frame(width: 1.5)
                                    .offset(y: 12)
                            }
                            Image(systemName: event.symbol)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 20, height: 20)
                                .background(Circle().fill(event.tint.gradient))
                        }
                        .frame(width: 20, height: 26)
                        Text(event.name)
                            .font(.system(size: 12))
                            .lineLimit(1)
                        Spacer()
                        Text(Fmt.time(event.date))
                            .font(.system(size: 12, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Stats

    private var stats: some View {
        let day = store.day
        let balance = store.balance
        return HStack(spacing: 8) {
            StatTile(title: "Balance", value: balance?.runningBalance.map(Fmt.signedMinutes) ?? "–",
                     help: "Your overall time balance in All Hours")
            StatTile(title: "Breaks", value: day.breaks > 0 ? Fmt.duration(day.breaks) : "–")
            StatTile(title: "Vacation", value: balance?.vacationBalance.map(vacationText) ?? "–",
                     help: "Vacation days left")
        }
    }

    private func vacationText(_ days: Double) -> String {
        let value = days.rounded() == days ? String(Int(days)) : String(format: "%.1f", days)
        return "\(value) \(days == 1 ? "day" : "days")"
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 4) {
            Button {
                NSWorkspace.shared.open(URL(string: "https://pro.allhours.com")!)
            } label: {
                Label("Open All Hours", systemImage: "arrow.up.right.square")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)

            Spacer()

            if let updated = store.lastUpdated {
                Text(updatedText(updated))
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            IconButton(symbol: "power", help: "Quit All Hours Bar") { NSApp.terminate(nil) }
        }
    }
}

private func updatedText(_ date: Date) -> String {
    let age = Date().timeIntervalSince(date)
    if age < 60 { return "Updated just now" }
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return "Updated \(formatter.localizedString(fromTimeInterval: -age))"
}

private struct StatTile: View {
    let title: String
    let value: String
    var help: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.045)))
        .help(help ?? "")
    }
}
