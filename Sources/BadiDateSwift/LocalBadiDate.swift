import Foundation

/// How far the sun is through the night or the daytime of a Badí‘ day.
public struct SunPosition: Hashable, Sendable {
    /// `false` from sunset to sunrise, `true` from sunrise to sunset.
    public let isDaytime: Bool
    /// From 0 at the start of the night or daytime to 1 at its end.
    public let fraction: Double

    public init(isDaytime: Bool, fraction: Double) {
        self.isDaytime = isDaytime
        self.fraction = fraction
    }
}

/// A Badí‘ date at a particular place, with the moments it starts and ends there.
///
/// The Badí‘ day runs from sunset to sunset, so which date it is depends on where you are. In a few high-latitude
/// regions fixed clock times are used instead of the actual sunset, see `ClockLocation`.
public struct LocalBadiDate: Hashable, Sendable {
    public let badiDate: BadiDate
    public let latitude: Double
    public let longitude: Double
    public let timeZone: TimeZone
    /// Whether fixed clock times were applied if the location lies in a `ClockLocation`.
    public let usesClockLocations: Bool
    /// The fixed-time region the location lies in, if any and if `usesClockLocations` is set.
    public let clockLocation: ClockLocation?

    /// Sunset on the previous Gregorian day, when this Badí‘ date begins.
    public let start: Date
    public let sunrise: Date
    public let solarNoon: Date
    /// Sunset, when this Badí‘ date ends.
    public let end: Date
    /// The time at which the Holy Day is commemorated, for the Holy Days that have one: 3 p.m. on the first day of
    /// Riḍván, two hours after sunset for the Declaration of the Báb, 3 a.m. for the Ascension of Bahá’u’lláh, noon
    /// for the Martyrdom of the Báb and 1 a.m. for the Ascension of ‘Abdu’l-Bahá. The clock hours are in local
    /// standard time, so they fall an hour later on the clock while daylight saving time is in force.
    public let holyDayCommemoration: Date?

    /// Creates the Badí‘ date in effect at the moment `date` at the given location.
    public init(
        _ date: Date = Date(),
        latitude: Double,
        longitude: Double,
        timeZone: TimeZone,
        usesClockLocations: Bool = true
    ) throws {
        let clock = LocalClock(timeZone)
        let clockLocation = usesClockLocations ? ClockLocation(latitude: latitude, longitude: longitude) : nil
        var day = GregorianDate(date, in: timeZone)
        // Not throwing here yet: the evening before the first valid day already belongs to it.
        let badiDate = try? BadiDate(gregorianDate: day)

        let sunset: Date
        let sunsetIsDuringAla = badiDate.map {
            $0.month == 19 || ($0.month == BadiDate.ayyamiHa && $0.day == $0.ayyamiHaLength)
        } ?? false
        if clockLocation == nil || (clockLocation == .finland && sunsetIsDuringAla) {
            sunset = Sun(clock: clock, latitude: latitude, longitude: longitude).sunset(on: date)
        } else {
            let observesDST = clockLocation == .finland || clockLocation == .usa
            let fraction = date.timeIntervalSince1970 - date.timeIntervalSince1970.rounded(.down)
            sunset = clock.date(day, hour: observesDST && clock.isInDST(date) ? 19 : 18) + fraction
        }
        if date > sunset {
            day = day.adding(days: 1)
        }
        try self.init(
            BadiDate(gregorianDate: day),
            latitude: latitude,
            longitude: longitude,
            timeZone: timeZone,
            usesClockLocations: usesClockLocations
        )
    }

    /// Creates the local times for a given Badí‘ date at the given location.
    public init(
        _ badiDate: BadiDate,
        latitude: Double,
        longitude: Double,
        timeZone: TimeZone,
        usesClockLocations: Bool = true
    ) {
        self.badiDate = badiDate
        self.latitude = latitude
        self.longitude = longitude
        self.timeZone = timeZone
        self.usesClockLocations = usesClockLocations
        let clockLocation = usesClockLocations ? ClockLocation(latitude: latitude, longitude: longitude) : nil
        self.clockLocation = clockLocation

        let clock = LocalClock(timeZone)
        let sun = Sun(clock: clock, latitude: latitude, longitude: longitude)
        let day = badiDate.gregorianDate
        let dayBefore = day.adding(days: -1)
        let midnight = clock.date(day)

        var start: Date
        var sunrise: Date
        var solarNoon: Date
        var end: Date
        // Should be 1 Ala still start at clocktime, 19 Ala end on sunset
        if clockLocation == nil || (clockLocation == .finland && badiDate.month == 19) {
            end = sun.sunset(on: midnight)
            solarNoon = sun.solarNoon(on: midnight)
            sunrise = sun.sunrise(on: midnight)
            start = sun.sunset(on: clock.date(dayBefore))
        } else {
            // First we set times to 18:00, 06:00, 12:00, 18:00, modifications are then made depending on the region.
            start = clock.date(dayBefore, hour: 18)
            solarNoon = clock.date(day, hour: 12)
            sunrise = clock.date(day, hour: 6)
            end = clock.date(day, hour: 18)
            switch clockLocation {
            case .canada:
                sunrise += 30 * 60
            case .iceland:
                solarNoon += 3600
            case .finland, .usa:
                if clock.isInDST(end) {
                    sunrise += 3600
                    solarNoon += 3600
                    end += 3600
                }
                if clock.isInDST(start) {
                    start += 3600
                }
            default:
                break
            }
        }
        if clockLocation == .finland {
            if badiDate.month == BadiDate.ayyamiHa, badiDate.day == badiDate.ayyamiHaLength {
                end = sun.sunset(on: midnight)
            }
            if badiDate.month == 1, badiDate.day == 1 {
                start = sun.sunset(on: clock.date(dayBefore))
            }
        }
        self.start = start
        self.sunrise = sunrise
        self.solarNoon = solarNoon
        self.end = end

        let standardHour = { (hour: Int) in clock.date(day, hour: clock.isInDST(midnight) ? hour + 1 : hour) }
        switch badiDate.holyDay {
        case .firstRidvan:
            // 15:00 local standard time
            holyDayCommemoration = standardHour(15)
        case .declarationOfTheBab:
            // Two hours after sunset. badiDate uses 2 hours 11 minutes; the guidance is "about two hours".
            holyDayCommemoration = start + 2 * 3600
        case .ascensionOfBahaullah:
            // 03:00 local standard time
            holyDayCommemoration = standardHour(3)
        case .martyrdomOfTheBab:
            // 12:00 local standard time. badiDate uses solar noon; the guidance is "about noon", given by the clock
            // like the other hours.
            holyDayCommemoration = standardHour(12)
        case .ascensionOfAbdulBaha:
            // 01:00 local standard time
            holyDayCommemoration = standardHour(1)
        default:
            holyDayCommemoration = nil
        }
    }

    /// Where the sun is on its way through this Badí‘ day at `date`: in the night between `start` and `sunrise`,
    /// or in the daytime between `sunrise` and `end`. Moments outside the day are clamped to its ends.
    public func sunPosition(at date: Date = Date()) -> SunPosition {
        let isDaytime = date >= sunrise
        let (from, to) = isDaytime ? (sunrise, end) : (start, sunrise)
        let length = to.timeIntervalSince(from)
        let fraction = length > 0 ? date.timeIntervalSince(from) / length : 0
        return SunPosition(isDaytime: isDaytime, fraction: min(max(fraction, 0), 1))
    }

    public var nextDay: LocalBadiDate? {
        badiDate.nextDay.map(relocated)
    }

    public var previousDay: LocalBadiDate? {
        badiDate.previousDay.map(relocated)
    }

    /// The first day of the following month, or `nil` past the end of the valid range.
    public var nextMonth: LocalBadiDate? {
        badiDate.nextMonth.map(relocated)
    }

    /// The first day of the preceding month, or `nil` before the start of the valid range.
    public var previousMonth: LocalBadiDate? {
        badiDate.previousMonth.map(relocated)
    }

    private func relocated(_ badiDate: BadiDate) -> LocalBadiDate {
        LocalBadiDate(
            badiDate,
            latitude: latitude,
            longitude: longitude,
            timeZone: timeZone,
            usesClockLocations: usesClockLocations
        )
    }
}
