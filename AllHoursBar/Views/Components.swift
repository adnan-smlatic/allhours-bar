import SwiftUI

extension Color {
    static let working = Color(red: 0.16, green: 0.70, blue: 0.47)
    static let paused = Color(red: 0.96, green: 0.60, blue: 0.16)
    static let away = Color(red: 0.42, green: 0.45, blue: 0.95)
    static let clockOut = Color(red: 0.92, green: 0.33, blue: 0.30)
    static let brandTop = Color(red: 0.16, green: 0.78, blue: 0.62)
    static let brandBottom = Color(red: 0.10, green: 0.42, blue: 0.80)
}

// MARK: - Status presentation

extension UserStatus {
    var title: String {
        switch self {
        case .clockedIn: "At work"
        case .clockedOut, .clockedOutAuto: "Clocked out"
        case .notClockedInYet: "Not clocked in"
        case .offsiteWork: "Working off-site"
        case .onBreak: "On a break"
        case .allDayAbsence: "Away today"
        case .absenceStarted: "Stepped out"
        case .missing: "Missing"
        case .absent: "Absent"
        case .workFromHome: "Working from home"
        }
    }

    var tint: Color {
        if isWorking { return .working }
        if isPaused { return .paused }
        if self == .allDayAbsence { return .away }
        if self == .missing { return .clockOut }
        return .secondary
    }
}

extension ClockAction {
    /// Short verb for the big button; the company's own name is shown next to it.
    var verb: String {
        switch kind {
        case .arrival: "Clock In"
        case .departure: "Clock Out"
        case .returning: "I'm Back"
        case .absenceStart, .automatic: name
        }
    }

    var tint: Color {
        switch kind {
        case .arrival: .working
        case .departure: .clockOut
        case .returning: .brandBottom
        case .absenceStart, .automatic: .paused
        }
    }

    var symbol: String { ClockingKind.symbol(kind, name: name) }
}

extension DayEvent {
    var symbol: String { ClockingKind.symbol(kind, name: name) }

    var tint: Color {
        switch kind {
        case .arrival: .working
        case .departure: .clockOut
        case .returning: .brandBottom
        case .absenceStart, .automatic: .paused
        }
    }
}

extension ClockingKind {
    static func symbol(_ kind: ClockingKind, name: String) -> String {
        switch kind {
        case .arrival: return "play.fill"
        case .departure: return "stop.fill"
        case .returning: return "arrow.uturn.backward"
        case .automatic: return "gearshape"
        case .absenceStart:
            let n = name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            func has(_ words: String...) -> Bool { words.contains { n.contains($0) } }
            if has("malic", "lunch", "kosil", "obrok", "meal") { return "fork.knife" }
            if has("odmor", "pavz", "break", "kav", "coffee") { return "cup.and.saucer.fill" }
            if has("sluzb", "business", "teren", "trip", "sestan", "meeting", "stranka", "client") { return "briefcase.fill" }
            if has("doma", "home", "remote") { return "house.fill" }
            if has("zdrav", "doctor", "bolni", "sick", "medical") { return "cross.case.fill" }
            if has("privat", "private", "osebn", "personal") { return "person.fill" }
            return "pause.circle.fill"
        }
    }
}

// MARK: - Building blocks

struct Card<Content: View>: View {
    var tint: Color? = nil
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
                if let tint {
                    shape.fill(LinearGradient(colors: [tint.opacity(0.20), tint.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing))
                } else {
                    shape.fill(Color.primary.opacity(0.045))
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.primary.opacity(0.06)))
    }
}

struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.6)
            .foregroundStyle(.secondary)
    }
}

struct StatusPill: View {
    let title: String
    let tint: Color
    var live = false

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "circle.fill")
                .font(.system(size: 6))
                .symbolEffect(.pulse, isActive: live)
            Text(title)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(tint.opacity(0.14)))
    }
}

struct GoalBar: View {
    let fraction: Double
    let tint: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.08))
                if fraction > 0 {
                    Capsule()
                        .fill(tint.gradient)
                        .frame(width: max(6, geo.size.width * min(1, fraction)))
                }
            }
        }
        .frame(height: 6)
        .animation(.easeOut(duration: 0.4), value: fraction)
    }
}

struct Avatar: View {
    let initials: String
    let tint: Color

    var body: some View {
        Text(initials)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(Circle().fill(LinearGradient(colors: [.brandTop, .brandBottom], startPoint: .topLeading, endPoint: .bottomTrailing)))
            .overlay(alignment: .bottomTrailing) {
                Circle()
                    .fill(tint)
                    .frame(width: 9, height: 9)
                    .overlay(Circle().strokeBorder(.background, lineWidth: 1.5))
                    .offset(x: 1, y: 1)
            }
    }
}

struct IconButton: View {
    let symbol: String
    let help: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 26, height: 26)
                .background(Circle().fill(Color.primary.opacity(hovering ? 0.08 : 0)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { hovering = $0 }
    }
}

struct ProminentButtonStyle: ButtonStyle {
    var tint: Color
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 38)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(tint.gradient))
            .shadow(color: tint.opacity(isEnabled ? 0.3 : 0), radius: 6, y: 2)
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.45)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct ChipButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 30)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.primary.opacity(configuration.isPressed ? 0.12 : 0.06)))
            .opacity(isEnabled ? 1 : 0.45)
            .contentShape(Rectangle())
    }
}

struct BannerView: View {
    let banner: Banner
    let onUndo: (String) -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: banner.style == .success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(banner.style == .success ? Color.working : Color.clockOut)
            Text(banner.message)
                .font(.system(size: 12))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            if let undoId = banner.undoClockingId {
                Button("Undo") { onUndo(undoId) }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            } else {
                Button(action: onDismiss) {
                    Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.06)))
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
