import Foundation

// Response shapes of the All Hours REST API (https://api4.allhours.com).
// Keys arrive in PascalCase and are mapped to camelCase by `AllHoursClient.decoder`.
// Nearly everything is optional because the Swagger spec documents no response bodies.

/// `GET /api/v1/Clocks/Web` — the same payload the pro.allhours.com clock widget uses.
struct ClockResponse: Decodable {
    var status: UserPresence?
    var clockingEnabled: Bool?
    var clientIpAddress: String?
    var clockingButtons: [ClockButton]?
}

struct UserPresence: Decodable {
    var userId: String?
    var firstName: String?
    var lastName: String?
    var userStatus: Int?
    var eventTimestamp: String?
    var clockingDefinitionName: String?
    var clockingDefinitionId: String?
    var absenceDefinitionName: String?
    var userStatusAdditionalInfo: String?
}

struct ClockButton: Decodable {
    var clockingDefinitionId: String
    var clockingDefinitionName: String?
    var isEnabled: Bool?
}

/// `GET /api/v1/ClockingDefinitions[/Personal]`
struct ClockingDefinition: Decodable {
    var id: String
    var name: String?
    var type: Int?
    var code: Int?
    var isActive: Bool?
}

/// `GET /api/v1/Clockings[/Personal]`
struct Clocking: Decodable {
    var id: String
    var timestamp: String?
    var userId: String?
    var clockingDefinitionId: String?
    var clockingDefinitionName: String?
}

/// `GET /api/v1/Presence/{userId}`, values in minutes. In mode 2, `balance` is today's
/// worked-minus-required time ("You have 05:26 hours left to work today") and
/// `runningBalance` is the overall balance.
struct CurrentBalance: Decodable {
    var balance: Int?
    var balanceText: String?
    var runningBalance: Int?
    var vacationBalance: Double?
    var balanceResponseMode: Int?
}

/// `GET /api/v1/Presence/Current`
struct PresenceStatus: Decodable {
    var userPresences: [UserPresence]?
}

/// `GET /api/v1/Users`
struct UserRecord: Decodable {
    var id: String
    var firstName: String?
    var lastName: String?
    var email: String?
}

/// `GET /api/v1/Users/Basic`
struct UserBasic: Decodable {
    var id: String
    var name: String?
}

/// `POST /api/v1/Clockings/Authentic` response.
struct CreatedClocking: Decodable {
    var id: String?
}

/// `UserPresenceDto.UserStatus`, as interpreted by the All Hours web app.
enum UserStatus: Int {
    case clockedIn = 0
    case clockedOut = 1
    case notClockedInYet = 2
    case offsiteWork = 3
    case onBreak = 4
    case allDayAbsence = 5
    case absenceStarted = 6
    case missing = 7
    case absent = 8
    case workFromHome = 9
    case clockedOutAuto = 10

    var isWorking: Bool { self == .clockedIn || self == .offsiteWork || self == .workFromHome }
    var isPaused: Bool { self == .onBreak || self == .absenceStarted }
    var isOut: Bool {
        switch self {
        case .clockedOut, .notClockedInYet, .missing, .absent, .clockedOutAuto: true
        default: false
        }
    }
}

/// `ClockingDefinitionDto.Type`.
enum ClockingKind: Int {
    case arrival = 0
    case departure = 1
    case absenceStart = 2
    case returning = 3
    case automatic = 4

    /// Fallback when clocking definitions can't be loaded. Covers English and Slovenian names.
    static func guess(from name: String?) -> ClockingKind {
        let n = (name ?? "").folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        func has(_ words: String...) -> Bool { words.contains { n.contains($0) } }
        if has("prihod", "arrival", "clock in", "check in", "in work") { return .arrival }
        if has("odhod", "departure", "clock out", "check out", "konec") { return .departure }
        if has("povratek", "return", "back", "nazaj") { return .returning }
        return .absenceStart
    }
}

/// Decodes either a bare JSON array or an object that wraps one (paged responses).
/// Elements that fail to decode are skipped instead of failing the whole list.
struct FlexibleList<Element: Decodable>: Decodable {
    var items: [Element]

    init(from decoder: Decoder) throws {
        if let array = try? [Lenient<Element>](from: decoder) {
            items = array.compactMap(\.value)
            return
        }
        let container = try decoder.container(keyedBy: AnyKey.self)
        for key in container.allKeys {
            if let array = try? container.decode([Lenient<Element>].self, forKey: key) {
                items = array.compactMap(\.value)
                return
            }
        }
        items = []
    }
}

private struct Lenient<T: Decodable>: Decodable {
    var value: T?
    init(from decoder: Decoder) throws { value = try? T(from: decoder) }
}

struct AnyKey: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }
    init(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
}
