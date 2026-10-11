import Foundation
import Testing
@testable import BadiDateSwift

@Suite struct BadiDateTests {
    @Test func yearsMatchReference() throws {
        var mismatches = Mismatches()
        let rows = try Fixtures.rows("years.txt")
        #expect(rows.count == 507)
        for row in rows {
            let year = Int(row[0])!
            let nawRuz = try BadiDate(year: year, month: 1, day: 1)
            mismatches.check(nawRuz.gregorianDate, GregorianDate(iso: row[1]), "Naw-Rúz \(year)")
            mismatches.check(nawRuz.nawRuz, GregorianDate(iso: row[1]), "nawRuz \(year)")
            mismatches.check(nawRuz.ayyamiHaLength, Int(row[2])!, "Ayyám-i-Há \(year)")
            for holyDay in HolyDay.allCases {
                let date = try BadiDate(year: year, holyDay: holyDay)
                mismatches.check(date.gregorianDate, GregorianDate(iso: row[2 + holyDay.rawValue]), "\(holyDay) \(year)")
                mismatches.check(date.holyDay, holyDay, "holyDay of \(holyDay) \(year)")
            }
            for month in 1...20 {
                let date = try BadiDate(year: year, month: month, day: 1)
                mismatches.check(date.gregorianDate, GregorianDate(iso: row[13 + month]), "month \(month) of \(year)")
            }
        }
        #expect(mismatches.isEmpty, "\(mismatches)")
    }

    @Test func sampledDaysMatchReference() throws {
        var mismatches = Mismatches()
        for row in try Fixtures.rows("days.txt") {
            let numbers = row.dropFirst().map { Int($0)! }
            let date = try BadiDate(gregorianDate: GregorianDate(iso: row[0]))
            let actual = [
                date.year, date.month, date.day, date.weekday, date.holyDay?.rawValue ?? 0,
                date.yearInVahid, date.vahid, date.kullIShay,
            ]
            mismatches.check(actual, numbers, "\(row[0])")
        }
        #expect(mismatches.isEmpty, "\(mismatches)")
    }

    /// Walks every day of the valid range, so that together with `yearsMatchReference` every date is pinned down.
    @Test func everyDayIsConsistent() throws {
        var mismatches = Mismatches()
        var gregorian = BadiDate.earliestGregorianDate
        var previous: BadiDate?
        var count = 0
        while gregorian <= BadiDate.latestGregorianDate {
            let date = try BadiDate(gregorianDate: gregorian)
            let roundTrip = try BadiDate(year: date.year, month: date.month, day: date.day)
            mismatches.check(roundTrip, date, "round trip \(gregorian)")
            mismatches.check(GregorianDate(daysSinceEpoch: gregorian.daysSinceEpoch), gregorian, "day number \(gregorian)")
            if let previous {
                mismatches.check(previous.nextDay, date, "nextDay \(gregorian)")
                mismatches.check(date.previousDay, previous, "previousDay \(gregorian)")
                mismatches.check(previous < date, true, "ordering \(gregorian)")
                if date.day == 1 {
                    mismatches.check(previous.nextMonth, date, "nextMonth \(gregorian)")
                    mismatches.check(date.previousMonth?.month, previous.month, "previousMonth \(gregorian)")
                    let length = previous.month == BadiDate.ayyamiHa ? previous.ayyamiHaLength : 19
                    mismatches.check(previous.day, length, "month length \(gregorian)")
                } else {
                    mismatches.check([date.year, date.month, date.day], [previous.year, previous.month, previous.day + 1], "step \(gregorian)")
                }
            }
            previous = date
            gregorian = gregorian.adding(days: 1)
            count += 1
        }
        #expect(mismatches.isEmpty, "\(mismatches)")
        #expect(count == 185_177)
        #expect(previous == (try BadiDate(year: 507, month: 19, day: 19)))
    }

    @Test func rejectsDatesOutsideTheRange() {
        #expect(throws: BadiDateError.outOfRange) { try BadiDate(gregorianYear: 1844, month: 3, day: 20) }
        #expect(throws: BadiDateError.outOfRange) { try BadiDate(gregorianYear: 2351, month: 3, day: 21) }
        #expect(throws: BadiDateError.outOfRange) { try BadiDate(year: 0, month: 19, day: 19) }
        #expect(throws: BadiDateError.outOfRange) { try BadiDate(year: 508, month: 1, day: 1) }
        #expect(throws: BadiDateError.outOfRange) { try BadiDate(year: 508, holyDay: .nawRuz) }
        #expect((try? BadiDate(year: 1, month: 1, day: 1))?.previousDay == nil)
        #expect((try? BadiDate(year: 1, month: 1, day: 1))?.previousMonth == nil)
        #expect((try? BadiDate(year: 507, month: 19, day: 19))?.nextDay == nil)
        #expect((try? BadiDate(year: 507, month: 19, day: 19))?.nextMonth == nil)
    }

    @Test func rejectsInvalidComponents() {
        #expect(throws: BadiDateError.invalidDate) { try BadiDate(year: 183, month: 0, day: 1) }
        #expect(throws: BadiDateError.invalidDate) { try BadiDate(year: 183, month: 21, day: 1) }
        #expect(throws: BadiDateError.invalidDate) { try BadiDate(year: 183, month: 1, day: 0) }
        #expect(throws: BadiDateError.invalidDate) { try BadiDate(year: 183, month: 1, day: 20) }
        #expect(throws: BadiDateError.invalidDate) { try BadiDate(gregorianYear: 2026, month: 2, day: 30) }
    }

    @Test func dayAfterAyyamiHaBecomesFirstOfAla() throws {
        // 183 B.E. has four intercalary days, 174 B.E. has five.
        #expect(try BadiDate(year: 183, month: 20, day: 5) == BadiDate(year: 183, month: 19, day: 1))
        #expect(throws: BadiDateError.invalidDate) { try BadiDate(year: 183, month: 20, day: 6) }
        #expect(try BadiDate(year: 174, month: 20, day: 5).month == 20)
        #expect(try BadiDate(year: 174, month: 20, day: 6) == BadiDate(year: 174, month: 19, day: 1))
    }

    @Test func knownDates() throws {
        let nawRuz183 = try BadiDate(gregorianYear: 2026, month: 3, day: 21)
        #expect(nawRuz183 == (try BadiDate(year: 183, month: 1, day: 1)))
        #expect(nawRuz183.holyDay == .nawRuz)
        #expect(nawRuz183.isWorkSuspended)
        #expect(nawRuz183.isFeast)
        #expect(nawRuz183.dayOfYear == 1)

        // The bicentenary of the Birth of Bahá’u’lláh.
        let bicentenary = try BadiDate(year: 174, holyDay: .birthOfBahaullah)
        #expect(bicentenary.gregorianDate == GregorianDate(year: 2017, month: 10, day: 22))

        let covenant = try BadiDate(year: 183, holyDay: .dayOfTheCovenant)
        #expect(!covenant.isWorkSuspended)
        #expect(try BadiDate(year: 183, month: 19, day: 3).isFast)
        #expect(try BadiDate(year: 183, month: 20, day: 1).isAyyamiHa)
        #expect(try !BadiDate(year: 183, month: 20, day: 1).isFeast)
        #expect(try BadiDate.holyDays(inYear: 183).map(\.holyDay) == HolyDay.allCases)
    }

    @Test func nextFeast() throws {
        #expect(try BadiDate(year: 183, month: 11, day: 15).nextFeast == BadiDate(year: 183, month: 12, day: 1))
        #expect(try BadiDate(year: 183, month: 11, day: 15).nextFeast?.gregorianDate.description == "2026-10-16")
        #expect(try BadiDate(year: 183, month: 12, day: 1).nextFeast == BadiDate(year: 183, month: 13, day: 1))
        // Ayyám-i-Há has no Feast.
        #expect(try BadiDate(year: 183, month: 18, day: 10).nextFeast == BadiDate(year: 183, month: 19, day: 1))
        #expect(try BadiDate(year: 183, month: 20, day: 2).nextFeast == BadiDate(year: 183, month: 19, day: 1))
        #expect(try BadiDate(year: 183, month: 19, day: 19).nextFeast == BadiDate(year: 184, month: 1, day: 1))
        #expect(try BadiDate(year: 507, month: 19, day: 3).nextFeast == nil)
    }

    @Test func nextHolyDay() throws {
        let birthOfTheBab = try BadiDate(year: 183, holyDay: .birthOfTheBab)
        #expect(try BadiDate(year: 183, month: 11, day: 15).nextHolyDay == birthOfTheBab)
        #expect(birthOfTheBab.gregorianDate.description == "2026-11-10")
        #expect(birthOfTheBab.nextHolyDay?.holyDay == .birthOfBahaullah)
        #expect(try BadiDate(year: 183, holyDay: .ascensionOfAbdulBaha).nextHolyDay == BadiDate(year: 184, holyDay: .nawRuz))
        #expect(try BadiDate(year: 507, holyDay: .dayOfTheCovenant).nextHolyDay?.holyDay == .ascensionOfAbdulBaha)
        #expect(try BadiDate(year: 507, holyDay: .ascensionOfAbdulBaha).nextHolyDay == nil)
    }

    @Test func codableRoundTrip() throws {
        let date = try BadiDate(year: 183, month: 11, day: 16)
        let data = try JSONEncoder().encode(date)
        #expect(try JSONSerialization.jsonObject(with: data) as? [String: Int] == ["year": 183, "month": 11, "day": 16])
        #expect(try JSONDecoder().decode(BadiDate.self, from: data) == date)
        #expect(throws: BadiDateError.invalidDate) {
            try JSONDecoder().decode(BadiDate.self, from: Data(#"{"year":183,"month":25,"day":1}"#.utf8))
        }
    }

    @Test func gregorianDateFromMoment() {
        let moment = Date(timeIntervalSince1970: 1_791_676_800) // 2026-10-11T00:00:00Z
        #expect(GregorianDate(moment, in: TimeZone(identifier: "UTC")!).description == "2026-10-11")
        #expect(GregorianDate(moment, in: TimeZone(identifier: "America/New_York")!).description == "2026-10-10")
        #expect(GregorianDate(moment, in: TimeZone(identifier: "Pacific/Auckland")!).description == "2026-10-11")
        #expect(GregorianDate(year: 2026, month: 10, day: 11)?.weekday == 7)
    }
}
