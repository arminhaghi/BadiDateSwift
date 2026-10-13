import Foundation

/// A calendar day in the proleptic Gregorian calendar, with no time or time zone attached.
public struct GregorianDate: Hashable, Comparable, Sendable, Codable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    /// Returns `nil` if the components don't designate a real day.
    public init?(year: Int, month: Int, day: Int) {
        guard (1...12).contains(month), day >= 1, day <= GregorianDate.daysInMonth(month, year: year) else {
            return nil
        }
        self.init(uncheckedYear: year, month: month, day: day)
    }

    /// The calendar day on which `date` falls in `timeZone`.
    public init(_ date: Date, in timeZone: TimeZone) {
        let shifted = date.timeIntervalSince1970 + Double(timeZone.secondsFromGMT(for: date))
        self.init(daysSinceEpoch: Int((shifted / 86400).rounded(.down)))
    }

    init(uncheckedYear year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// Days since 1970-01-01. See Howard Hinnant's `civil_from_days`.
    init(daysSinceEpoch: Int) {
        let z = daysSinceEpoch + 719_468
        let era = (z >= 0 ? z : z - 146_096) / 146_097
        let doe = z - era * 146_097
        let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146_096) / 365
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
        let mp = (5 * doy + 2) / 153
        let month = mp < 10 ? mp + 3 : mp - 9
        self.init(uncheckedYear: yoe + era * 400 + (month <= 2 ? 1 : 0), month: month, day: doy - (153 * mp + 2) / 5 + 1)
    }

    /// Days since 1970-01-01. See Howard Hinnant's `days_from_civil`.
    var daysSinceEpoch: Int {
        let y = month <= 2 ? year - 1 : year
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let doy = (153 * (month > 2 ? month - 3 : month + 9) + 2) / 5 + day - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146_097 + doe - 719_468
    }

    /// ISO weekday, 1 (Monday) to 7 (Sunday).
    public var weekday: Int {
        let remainder = (daysSinceEpoch + 3) % 7
        return (remainder < 0 ? remainder + 7 : remainder) + 1
    }

    public func adding(days: Int) -> GregorianDate {
        GregorianDate(daysSinceEpoch: daysSinceEpoch + days)
    }

    /// The first moment of this day in `timeZone`.
    public func startOfDay(in timeZone: TimeZone) -> Date {
        LocalClock(timeZone).date(self)
    }

    public static func < (lhs: GregorianDate, rhs: GregorianDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    /// ISO 8601 form, e.g. `2026-03-21`.
    public var description: String {
        let pad = { (value: Int, width: Int) in
            String(repeating: "0", count: max(0, width - String(value).count)) + String(value)
        }
        return "\(pad(year, 4))-\(pad(month, 2))-\(pad(day, 2))"
    }

    static func isLeapYear(_ year: Int) -> Bool {
        (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
    }

    static func daysInMonth(_ month: Int, year: Int) -> Int {
        switch month {
        case 2: return isLeapYear(year) ? 29 : 28
        case 4, 6, 9, 11: return 30
        default: return 31
        }
    }
}

/// Wall-clock arithmetic in one time zone.
struct LocalClock {
    let timeZone: TimeZone
    private let calendar: Calendar

    init(_ timeZone: TimeZone) {
        self.timeZone = timeZone
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        self.calendar = calendar
    }

    func date(_ day: GregorianDate, hour: Int = 0, minute: Int = 0, second: Int = 0) -> Date {
        let components = DateComponents(
            year: day.year, month: day.month, day: day.day, hour: hour, minute: minute, second: second
        )
        // Only nil for components no Gregorian calendar can represent, which GregorianDate rules out.
        return calendar.date(from: components)!
    }

    /// Minutes east of UTC at `date`.
    func offset(at date: Date) -> Double {
        Double(timeZone.secondsFromGMT(for: date)) / 60
    }

    /// Whether the offset at `date` is larger than at the same wall-clock time in January or May of that year.
    /// This is Luxon's definition, which doesn't depend on how the time zone database labels its rules.
    func isInDST(_ date: Date) -> Bool {
        let parts = calendar.dateComponents([.year, .day, .hour, .minute, .second], from: date)
        let offset = offset(at: date)
        for month in [1, 5] {
            var reference = DateComponents(year: parts.year, month: month, day: month == 1 ? 1 : parts.day)
            reference.hour = parts.hour
            reference.minute = parts.minute
            reference.second = parts.second
            if let referenceDate = calendar.date(from: reference), offset > self.offset(at: referenceDate) {
                return true
            }
        }
        return false
    }
}
