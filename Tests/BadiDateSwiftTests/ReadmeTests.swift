import Foundation
import Testing
import BadiDateSwift

/// The examples in the README, through the public interface only.
@Suite struct ReadmeTests {
    @Test func basics() throws {
        let date = try BadiDate(gregorianYear: 2026, month: 3, day: 21)
        #expect(date == (try BadiDate(year: 183, month: 1, day: 1)))
        #expect(date.year == 183)
        #expect(date.holyDay == .nawRuz)
        #expect(date.isWorkSuspended)
        #expect(date.gregorianDate.description == "2026-03-21")
        #expect(date.format() == "1 Bahá (Splendour) 183 B.E.")
        #expect(date.format("d MM y", language: "fa") == "۱ بهاء ۱۸۳")
        #expect(try BadiDate(year: 183, holyDay: .firstRidvan).gregorianDate.description == "2026-04-21")
    }

    @Test func local() throws {
        let haifa = TimeZone(identifier: "Asia/Jerusalem")!
        let now = try LocalBadiDate(Date(), latitude: 32.8191, longitude: 34.9983, timeZone: haifa)
        #expect(now.start < now.end)
        #expect(now.start <= Date() && Date() <= now.end)
        #expect(now.nextDay?.start == now.end)

        let martyrdom = LocalBadiDate(
            try BadiDate(year: 183, holyDay: .martyrdomOfTheBab), latitude: 32.8191, longitude: 34.9983, timeZone: haifa
        )
        // Noon standard time in Haifa is 13:00 on the clock in July, which is 10:00 UTC.
        #expect(martyrdom.holyDayCommemoration == Date(timeIntervalSince1970: 1_783_677_600))
        #expect(martyrdom.sunPosition(at: martyrdom.sunrise) == SunPosition(isDaytime: true, fraction: 0))
    }
}
