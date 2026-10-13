import Foundation
import Testing
@testable import BadiDateSwift

@Suite struct LocalBadiDateTests {
    struct Location {
        let timeZone: TimeZone
        let latitude: Double
        let longitude: Double
        let usesClockLocations: Bool
    }

    static func location(_ row: [Substring]) -> (id: String, location: Location) {
        (String(row[1]), Location(
            timeZone: TimeZone(identifier: String(row[2]))!,
            latitude: Double(row[3])!,
            longitude: Double(row[4])!,
            usesClockLocations: row[5] == "1"
        ))
    }

    /// The commemoration time expected of this package, given badiDate's. They agree except on two Holy Days, where
    /// this package follows the guidance more closely: the hour nearest two hours after sunset rather than 2 hours
    /// 11 minutes for the Declaration of the Báb, and noon by the clock in standard time rather than solar noon for
    /// the Martyrdom of the Báb.
    private static func commemoration(_ date: BadiDate, reference: Double?, in timeZone: TimeZone) -> Double? {
        switch date.holyDay {
        case .declarationOfTheBab:
            // badiDate's time less its 11 minutes is two hours after sunset, which is then taken to the nearest hour
            // of the local clock.
            return reference.map { reference in
                let offset = Double(timeZone.secondsFromGMT(for: Date(timeIntervalSince1970: reference)))
                return ((reference - 11 * 60 + offset) / 3600).rounded() * 3600 - offset
            }
        case .martyrdomOfTheBab:
            // Noon on the Gregorian day as if it were GMT, moved to where standard time reads noon in this zone.
            let noon = date.gregorianDate.startOfDay(in: .gmt) + 12 * 3600
            let standardOffset = Double(timeZone.secondsFromGMT(for: noon)) - timeZone.daylightSavingTimeOffset(for: noon)
            return noon.timeIntervalSince1970 - standardOffset
        default:
            return reference
        }
    }

    @Test func theDeclarationIsCommemoratedOnTheHourNearestTwoHoursAfterSunset() throws {
        let places: [(String, Double, Double)] = [
            ("America/Los_Angeles", 33.88, -117.57), ("Asia/Jerusalem", 32.8191, 34.9983), ("Asia/Kolkata", 28.61, 77.21),
            ("Australia/Adelaide", -34.93, 138.6), ("Asia/Kathmandu", 27.72, 85.32),
        ]
        for (identifier, latitude, longitude) in places {
            let timeZone = TimeZone(identifier: identifier)!
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone
            for year in 172...200 {
                let day = LocalBadiDate(
                    try BadiDate(year: year, holyDay: .declarationOfTheBab),
                    latitude: latitude, longitude: longitude, timeZone: timeZone, usesClockLocations: false
                )
                let commemoration = try #require(day.holyDayCommemoration)
                let clock = calendar.dateComponents([.minute, .second], from: commemoration)
                #expect(clock.minute == 0 && clock.second == 0, "\(identifier) \(year)")
                #expect(abs(commemoration.timeIntervalSince(day.start + 2 * 3600)) <= 30 * 60, "\(identifier) \(year)")
            }
        }
    }

    @Test func localTimesMatchReference() throws {
        var mismatches = Mismatches()
        var id = ""
        var location: Location!
        var checked = 0
        for row in try Fixtures.rows("local.txt") {
            if row[0] == "#" {
                (id, location) = Self.location(row)
                continue
            }
            let badiDate = try BadiDate(year: Int(row[0])!, month: Int(row[1])!, day: Int(row[2])!)
            let local = LocalBadiDate(
                badiDate,
                latitude: location.latitude,
                longitude: location.longitude,
                timeZone: location.timeZone,
                usesClockLocations: location.usesClockLocations
            )
            let context = "\(id) \(badiDate.gregorianDate)"
            mismatches.check(local.start.timeIntervalSince1970, Double(row[3])!, "\(context) start")
            mismatches.check(local.sunrise.timeIntervalSince1970, Double(row[4])!, "\(context) sunrise")
            mismatches.check(local.solarNoon.timeIntervalSince1970, Double(row[5])!, "\(context) solar noon")
            mismatches.check(local.end.timeIntervalSince1970, Double(row[6])!, "\(context) end")
            mismatches.check(
                local.holyDayCommemoration?.timeIntervalSince1970,
                Self.commemoration(badiDate, reference: Double(row[7]), in: location.timeZone),
                "\(context) commemoration"
            )
            mismatches.check(local.clockLocation?.rawValue ?? "-", String(row[8]), "\(context) clock location")
            checked += 1
        }
        #expect(mismatches.isEmpty, "\(mismatches)")
        #expect(checked > 10_000)
    }

    @Test func momentsMatchReference() throws {
        var locations: [String: Location] = [:]
        for row in try Fixtures.rows("local.txt") where row[0] == "#" {
            let (id, location) = Self.location(row)
            locations[id] = location
        }
        var mismatches = Mismatches()
        for row in try Fixtures.rows("moments.txt") {
            let location = locations[String(row[0])]!
            let local = try LocalBadiDate(
                Date(timeIntervalSince1970: Double(row[1])!),
                latitude: location.latitude,
                longitude: location.longitude,
                timeZone: location.timeZone,
                usesClockLocations: location.usesClockLocations
            )
            let actual = [local.badiDate.year, local.badiDate.month, local.badiDate.day]
            mismatches.check(actual, row[2...].map { Int($0)! }, "\(row[0]) \(row[1])")
        }
        #expect(mismatches.isEmpty, "\(mismatches)")
    }

    @Test func dateChangesAtSunset() throws {
        let newYork = TimeZone(identifier: "America/New_York")!
        let day = try BadiDate(gregorianYear: 2026, month: 10, day: 11)
        let local = LocalBadiDate(day, latitude: 40.7128, longitude: -74.006, timeZone: newYork)
        #expect(local.start < local.sunrise && local.sunrise < local.solarNoon && local.solarNoon < local.end)
        #expect(local.nextDay?.start == local.end)
        #expect(local.previousDay?.end == local.start)

        let before = try LocalBadiDate(local.end, latitude: 40.7128, longitude: -74.006, timeZone: newYork)
        let after = try LocalBadiDate(local.end + 1, latitude: 40.7128, longitude: -74.006, timeZone: newYork)
        #expect(before.badiDate == day)
        #expect(after.badiDate == day.nextDay)
        #expect(after == local.nextDay)
    }

    @Test func sunPosition() throws {
        let newYork = TimeZone(identifier: "America/New_York")!
        let day = try BadiDate(gregorianYear: 2026, month: 10, day: 11)
        let local = LocalBadiDate(day, latitude: 40.7128, longitude: -74.006, timeZone: newYork)
        let night = local.sunrise.timeIntervalSince(local.start)
        let daytime = local.end.timeIntervalSince(local.sunrise)

        #expect(local.sunPosition(at: local.start) == SunPosition(isDaytime: false, fraction: 0))
        #expect(local.sunPosition(at: local.start + night / 4) == SunPosition(isDaytime: false, fraction: 0.25))
        #expect(local.sunPosition(at: local.sunrise) == SunPosition(isDaytime: true, fraction: 0))
        #expect(local.sunPosition(at: local.sunrise + daytime / 2) == SunPosition(isDaytime: true, fraction: 0.5))
        #expect(local.sunPosition(at: local.end) == SunPosition(isDaytime: true, fraction: 1))
        // Outside the day the position stays at its ends.
        #expect(local.sunPosition(at: local.start - 3600) == SunPosition(isDaytime: false, fraction: 0))
        #expect(local.sunPosition(at: local.end + 3600) == SunPosition(isDaytime: true, fraction: 1))
    }

    @Test func eveningBeforeTheFirstDayBelongsToIt() throws {
        let utc = TimeZone(identifier: "UTC")!
        let evening = GregorianDate(year: 1844, month: 3, day: 20)!.startOfDay(in: utc) + 23 * 3600
        let local = try LocalBadiDate(evening, latitude: 0, longitude: 0, timeZone: utc)
        #expect(local.badiDate == (try BadiDate(year: 1, month: 1, day: 1)))
        #expect(throws: BadiDateError.outOfRange) {
            try LocalBadiDate(evening - 12 * 3600, latitude: 0, longitude: 0, timeZone: utc)
        }
    }

    @Test func clockLocations() {
        #expect(ClockLocation(latitude: 64.1466, longitude: -21.9426) == .iceland)
        #expect(ClockLocation(latitude: 61.2181, longitude: -149.9003) == .usa)
        #expect(ClockLocation(latitude: 63.7467, longitude: -68.517) == .canada)
        #expect(ClockLocation(latitude: 59.9139, longitude: 10.7522) == .norway)
        #expect(ClockLocation(latitude: 67.8558, longitude: 20.2253) == .sweden)
        #expect(ClockLocation(latitude: 60.1699, longitude: 24.9384) == .finland)
        #expect(ClockLocation(latitude: 59.3293, longitude: 18.0686) == nil)
        #expect(ClockLocation(latitude: 40.7128, longitude: -74.006) == nil)
        #expect(ClockLocation(latitude: -77.8419, longitude: 166.6863) == nil)
    }
}
