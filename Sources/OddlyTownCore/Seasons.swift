import Foundation

/// The town follows the real calendar's (meteorological) seasons.
public enum Season: String, CaseIterable, Codable, Sendable {
    case spring, summer, autumn, winter

    public var displayName: String { rawValue.capitalized }

    /// Northern: Mar–May spring, Jun–Aug summer, Sep–Nov autumn, Dec–Feb winter.
    /// Southern: the same, six months on.
    public static func at(_ date: Date, hemisphere: Hemisphere, calendar: Calendar = .current) -> Season {
        let month = calendar.component(.month, from: date)
        let local = hemisphere == .southern ? (month + 5) % 12 + 1 : month
        switch local {
        case 3...5: return .spring
        case 6...8: return .summer
        case 9...11: return .autumn
        default: return .winter
        }
    }
}

public enum Hemisphere: String, CaseIterable, Codable, Sendable {
    case northern, southern

    /// Best guess from the time zone alone (no location permission). Unknown zones count as
    /// northern; users in the wrong bucket can pick their hemisphere in Settings.
    public static func guess(from timeZone: TimeZone) -> Hemisphere {
        let id = timeZone.identifier
        if southernPrefixes.contains(where: { id.hasPrefix($0) }) || southernZones.contains(id) {
            return .southern
        }
        return .northern
    }

    static let southernPrefixes = ["Australia/", "Antarctica/", "America/Argentina/"]

    /// Zones that lie (mostly) south of the equator.
    static let southernZones: Set<String> = [
        // Pacific
        "Pacific/Auckland", "Pacific/Chatham", "Pacific/Fiji", "Pacific/Tongatapu", "Pacific/Apia",
        "Pacific/Noumea", "Pacific/Efate", "Pacific/Port_Moresby", "Pacific/Norfolk", "Pacific/Rarotonga",
        "Pacific/Tahiti", "Pacific/Easter", "Pacific/Pago_Pago", "Pacific/Guadalcanal", "Pacific/Wallis",
        "Pacific/Niue", "Pacific/Funafuti", "Pacific/Fakaofo", "Pacific/Galapagos", "NZ",
        // South America
        "America/Buenos_Aires", "America/Santiago", "America/Punta_Arenas", "America/Sao_Paulo",
        "America/Montevideo", "America/Asuncion", "America/La_Paz", "America/Lima", "America/Guayaquil",
        "America/Bahia", "America/Recife", "America/Fortaleza", "America/Maceio", "America/Belem",
        "America/Araguaina", "America/Cuiaba", "America/Campo_Grande", "America/Porto_Velho",
        "America/Rio_Branco", "America/Manaus", "America/Noronha", "America/Santarem", "America/Eirunepe",
        // Atlantic
        "Atlantic/Stanley", "Atlantic/South_Georgia", "Atlantic/St_Helena",
        // Africa
        "Africa/Johannesburg", "Africa/Maputo", "Africa/Harare", "Africa/Lusaka", "Africa/Windhoek",
        "Africa/Gaborone", "Africa/Maseru", "Africa/Mbabane", "Africa/Luanda", "Africa/Lubumbashi",
        "Africa/Blantyre", "Africa/Lilongwe", "Africa/Dar_es_Salaam", "Africa/Kinshasa", "Africa/Brazzaville",
        "Africa/Bujumbura", "Africa/Kigali", "Africa/Nairobi",
        // Indian Ocean
        "Indian/Antananarivo", "Indian/Mauritius", "Indian/Reunion", "Indian/Mayotte", "Indian/Comoro",
        "Indian/Mahe", "Indian/Chagos", "Indian/Cocos", "Indian/Christmas", "Indian/Kerguelen",
        // Asia
        "Asia/Jakarta", "Asia/Makassar", "Asia/Jayapura", "Asia/Dili",
    ]
}

/// Settings → Seasons.
public enum SeasonSetting: String, CaseIterable, Codable, Sendable {
    /// Real calendar; hemisphere guessed from the time zone.
    case automatic
    case northern
    case southern
    /// Always summer (how the town looked before seasons).
    case off

    public var displayName: String {
        switch self {
        case .automatic: return "Follow the calendar"
        case .northern: return "Northern hemisphere"
        case .southern: return "Southern hemisphere"
        case .off: return "Off (always summer)"
        }
    }

    /// The hemisphere in use, or nil when seasons are off.
    public func hemisphere(timeZone: TimeZone) -> Hemisphere? {
        switch self {
        case .automatic: return Hemisphere.guess(from: timeZone)
        case .northern: return .northern
        case .southern: return .southern
        case .off: return nil
        }
    }

    public func season(at date: Date, calendar: Calendar = .current) -> Season {
        guard let hemisphere = hemisphere(timeZone: calendar.timeZone) else { return .summer }
        return Season.at(date, hemisphere: hemisphere, calendar: calendar)
    }
}
