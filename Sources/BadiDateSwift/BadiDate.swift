import Foundation

public enum BadiDateError: Error, Equatable, Sendable {
    /// The date is outside 1 Bahá 1 B.E. (21 March 1844) to 19 ‘Alá’ 507 B.E. (20 March 2351).
    case outOfRange
    /// The month and day don't designate a date in that year.
    case invalidDate
}

/// A date in the Badí‘ calendar.
///
/// A `BadiDate` is treated as corresponding to exactly one Gregorian day: the one on whose sunset it ends. It knows
/// nothing about location, so it can't tell you which Badí‘ date it is right now after sunset. Use `LocalBadiDate`
/// for that.
///
/// Months are numbered 1 to 19 as usual, with Ayyám-i-Há as month 20. Note that month 20 falls between months 18
/// and 19.
public struct BadiDate: Hashable, Comparable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int
    /// The Gregorian day on whose sunset this Badí‘ date ends.
    public let gregorianDate: GregorianDate

    public static let validYears = 1...507
    public static let ayyamiHa = 20
    public static let earliestGregorianDate = GregorianDate(uncheckedYear: 1844, month: 3, day: 21)
    public static let latestGregorianDate = GregorianDate(uncheckedYear: 2351, month: 3, day: 20)

    /// Creates a date from Badí‘ components.
    ///
    /// The day after the last day of Ayyám-i-Há is accepted and becomes 1 ‘Alá’, so that asking for a fifth
    /// intercalary day in a year with four still gives a usable date.
    public init(year: Int, month: Int, day: Int) throws {
        guard BadiDate.validYears.contains(year) else { throw BadiDateError.outOfRange }
        let info = BadiYear.info(year)
        var (month, day) = (month, day)
        if month == BadiDate.ayyamiHa, day > info.ayyamiHaLength {
            guard day - info.ayyamiHaLength == 1 else { throw BadiDateError.invalidDate }
            (month, day) = (19, 1)
        }
        guard (1...20).contains(month), (1...19).contains(day) else { throw BadiDateError.invalidDate }
        self.init(uncheckedYear: year, month: month, day: day, info: info)
    }

    /// Creates the date of `holyDay` in `year`.
    public init(year: Int, holyDay: HolyDay) throws {
        guard BadiDate.validYears.contains(year) else { throw BadiDateError.outOfRange }
        let (month, day) = holyDay.monthAndDay(inYear: year)
        self.init(uncheckedYear: year, month: month, day: day, info: BadiYear.info(year))
    }

    /// Creates the Badí‘ date that ends at sunset on `gregorianDate`.
    public init(gregorianDate: GregorianDate) throws {
        guard gregorianDate >= BadiDate.earliestGregorianDate, gregorianDate <= BadiDate.latestGregorianDate else {
            throw BadiDateError.outOfRange
        }
        var year = gregorianDate.year - 1843
        if gregorianDate < BadiYear.info(year).nawRuz {
            year -= 1
        }
        let info = BadiYear.info(year)
        let dayOfYear = gregorianDate.daysSinceEpoch - info.nawRuz.daysSinceEpoch + 1
        self.year = year
        if dayOfYear < 343 {
            month = (dayOfYear - 1) / 19 + 1
            day = (dayOfYear - 1) % 19 + 1
        } else if dayOfYear < 343 + info.ayyamiHaLength {
            month = BadiDate.ayyamiHa
            day = dayOfYear - 342
        } else {
            month = 19
            day = dayOfYear - (342 + info.ayyamiHaLength)
        }
        self.gregorianDate = gregorianDate
    }

    /// Creates the Badí‘ date that ends at sunset on the given Gregorian day.
    public init(gregorianYear: Int, month: Int, day: Int) throws {
        guard let gregorianDate = GregorianDate(year: gregorianYear, month: month, day: day) else {
            throw BadiDateError.invalidDate
        }
        try self.init(gregorianDate: gregorianDate)
    }

    /// Creates the Badí‘ date that ends at sunset on the Gregorian day `date` falls on in `timeZone`.
    ///
    /// The time of day is ignored, so after sunset this is one day behind. Use `LocalBadiDate` when the time matters.
    public init(gregorianDayOf date: Date, in timeZone: TimeZone) throws {
        try self.init(gregorianDate: GregorianDate(date, in: timeZone))
    }

    private init(uncheckedYear year: Int, month: Int, day: Int, info: BadiYear) {
        self.year = year
        self.month = month
        self.day = day
        let dayOfYear = BadiDate.dayOfYear(month: month, day: day, ayyamiHaLength: info.ayyamiHaLength)
        gregorianDate = info.nawRuz.adding(days: dayOfYear - 1)
    }

    private static func dayOfYear(month: Int, day: Int, ayyamiHaLength: Int) -> Int {
        switch month {
        case 19: return 342 + ayyamiHaLength + day
        case 20: return 342 + day
        default: return 19 * (month - 1) + day
        }
    }

    /// Position in the year, with Naw-Rúz as day 1.
    public var dayOfYear: Int {
        BadiDate.dayOfYear(month: month, day: day, ayyamiHaLength: ayyamiHaLength)
    }

    /// Number of intercalary days in this date's year, 4 or 5.
    public var ayyamiHaLength: Int {
        BadiYear.info(year).ayyamiHaLength
    }

    /// The Gregorian day on whose sunset Naw-Rúz of this date's year ends.
    public var nawRuz: GregorianDate {
        BadiYear.info(year).nawRuz
    }

    public var isAyyamiHa: Bool {
        month == BadiDate.ayyamiHa
    }

    /// Whether the date falls in ‘Alá’, the month of the Nineteen Day Fast.
    public var isFast: Bool {
        month == 19
    }

    /// Whether the date is the first day of a month, when the Nineteen Day Feast is held.
    public var isFeast: Bool {
        day == 1 && month != BadiDate.ayyamiHa
    }

    public var holyDay: HolyDay? {
        HolyDay.allCases.first { $0.monthAndDay(inYear: year) == (month, day) }
    }

    public var isWorkSuspended: Bool {
        holyDay?.isWorkSuspended ?? false
    }

    /// Badí‘ weekday, 1 (Jalál, ending on Saturday) to 7 (Istiqlál, ending on Friday).
    public var weekday: Int {
        (gregorianDate.weekday + 1) % 7 + 1
    }

    /// Position of the year in its Váḥid, 1 to 19.
    public var yearInVahid: Int {
        (year - 1) % 19 + 1
    }

    /// Position of the Váḥid in its Kull-i-Shay’, 1 to 19.
    public var vahid: Int {
        (year - 1) / 19 % 19 + 1
    }

    public var kullIShay: Int {
        (year - 1) / 361 + 1
    }

    /// The first day of the following month, or `nil` past the end of the valid range.
    public var nextMonth: BadiDate? {
        switch month {
        case 18: return try? BadiDate(year: year, month: 20, day: 1)
        case 19: return try? BadiDate(year: year + 1, month: 1, day: 1)
        case 20: return try? BadiDate(year: year, month: 19, day: 1)
        default: return try? BadiDate(year: year, month: month + 1, day: 1)
        }
    }

    /// The first day of the preceding month, or `nil` before the start of the valid range.
    public var previousMonth: BadiDate? {
        switch month {
        case 1: return try? BadiDate(year: year - 1, month: 19, day: 1)
        case 19: return try? BadiDate(year: year, month: 20, day: 1)
        case 20: return try? BadiDate(year: year, month: 18, day: 1)
        default: return try? BadiDate(year: year, month: month - 1, day: 1)
        }
    }

    public var nextDay: BadiDate? {
        try? BadiDate(gregorianDate: gregorianDate.adding(days: 1))
    }

    public var previousDay: BadiDate? {
        try? BadiDate(gregorianDate: gregorianDate.adding(days: -1))
    }

    /// The next first day of a month after this date, when the Nineteen Day Feast is held, or `nil` past the end
    /// of the valid range. Ayyám-i-Há has no Feast and is skipped.
    public var nextFeast: BadiDate? {
        guard let next = nextMonth else { return nil }
        return next.isAyyamiHa ? next.nextMonth : next
    }

    /// The next Holy Day after this date, or `nil` past the end of the valid range. On a Holy Day this is the
    /// following one.
    public var nextHolyDay: BadiDate? {
        for year in [year, year + 1] {
            guard let holyDays = try? BadiDate.holyDays(inYear: year) else { return nil }
            if let next = holyDays.first(where: { $0 > self }) {
                return next
            }
        }
        return nil
    }

    /// The dates of all eleven Holy Days in `year`, in order.
    public static func holyDays(inYear year: Int) throws -> [BadiDate] {
        try HolyDay.allCases.map { try BadiDate(year: year, holyDay: $0) }
    }

    public static func < (lhs: BadiDate, rhs: BadiDate) -> Bool {
        lhs.gregorianDate < rhs.gregorianDate
    }
}

extension BadiDate: Codable {
    private enum CodingKeys: String, CodingKey {
        case year, month, day
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            year: container.decode(Int.self, forKey: .year),
            month: container.decode(Int.self, forKey: .month),
            day: container.decode(Int.self, forKey: .day)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(year, forKey: .year)
        try container.encode(month, forKey: .month)
        try container.encode(day, forKey: .day)
    }
}
