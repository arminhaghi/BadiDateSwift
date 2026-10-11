/// The eleven Bahá’í Holy Days, numbered in the order they occur in a Badí‘ year.
public enum HolyDay: Int, CaseIterable, Sendable, Codable {
    case nawRuz = 1
    case firstRidvan
    case ninthRidvan
    case twelfthRidvan
    case declarationOfTheBab
    case ascensionOfBahaullah
    case martyrdomOfTheBab
    case birthOfTheBab
    case birthOfBahaullah
    case dayOfTheCovenant
    case ascensionOfAbdulBaha

    /// Work is suspended on every Holy Day except the Day of the Covenant and the Ascension of ‘Abdu’l-Bahá.
    public var isWorkSuspended: Bool {
        rawValue < HolyDay.dayOfTheCovenant.rawValue
    }

    /// The name of the Holy Day in `language`, falling back to English.
    public func name(language: String = "en") -> String {
        BadiLocaleData.item(\.holyDay, rawValue, language: language)
    }

    /// Badí‘ month and day of this Holy Day in `year`.
    func monthAndDay(inYear year: Int) -> (month: Int, day: Int) {
        let reformed = year >= BadiYear.firstAstronomicalYear
        switch self {
        case .nawRuz: return (1, 1)
        case .firstRidvan: return (2, 13)
        case .ninthRidvan: return (3, 2)
        case .twelfthRidvan: return (3, 5)
        case .declarationOfTheBab: return (4, reformed ? 8 : 7)
        case .ascensionOfBahaullah: return (4, 13)
        case .martyrdomOfTheBab: return (6, reformed ? 17 : 16)
        case .birthOfTheBab: return BadiYear.info(year).birthOfTheBab
        case .birthOfBahaullah: return BadiYear.info(year).birthOfBahaullah
        case .dayOfTheCovenant: return (14, 4)
        case .ascensionOfAbdulBaha: return (14, 6)
        }
    }
}
