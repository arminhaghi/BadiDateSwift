import Foundation
import Testing
@testable import BadiDateSwift

@Suite struct FormatTests {
    struct Reference: Decodable {
        let entries: [[Value]]
        let holyDays: [[Value]]
    }

    enum Value: Decodable {
        case int(Int), string(String), null

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if container.decodeNil() {
                self = .null
            } else if let int = try? container.decode(Int.self) {
                self = .int(int)
            } else {
                self = .string(try container.decode(String.self))
            }
        }

        var int: Int {
            if case let .int(value) = self { return value }
            fatalError("not an Int")
        }

        var string: String? {
            if case let .string(value) = self { return value }
            return nil
        }
    }

    static let reference = try! JSONDecoder().decode(Reference.self, from: Data(contentsOf: Fixtures.url("format.json")))

    @Test func formattingMatchesReference() throws {
        let styles: [String: UnderlineStyle] = ["diacritic": .diacritic, "none": .none, "u": .htmlTag, "css": .htmlStyle]
        var mismatches = Mismatches()
        #expect(Self.reference.entries.count > 5000)
        for entry in Self.reference.entries {
            let date = try BadiDate(year: entry[0].int, month: entry[1].int, day: entry[2].int)
            let language = entry[3].string!
            let actual = date.format(entry[5].string, language: language, underline: styles[entry[4].string!]!)
            mismatches.check(actual, entry[6].string!, "\(date.year)-\(date.month)-\(date.day) \(language) \(entry[5].string ?? "default")")
        }
        #expect(mismatches.isEmpty, "\(mismatches)")
    }

    @Test func holyDayNamesMatchReference() {
        var mismatches = Mismatches()
        for entry in Self.reference.holyDays {
            let language = entry[1].string!
            mismatches.check(HolyDay(rawValue: entry[0].int)!.name(language: language), entry[2].string!, "\(entry[0].int) \(language)")
        }
        #expect(mismatches.isEmpty, "\(mismatches)")
    }

    @Test func names() throws {
        let date = try BadiDate(year: 183, month: 16, day: 11)
        #expect(date.format() == "11 S\u{332}h\u{332}araf (Honour) 183 B.E.")
        #expect(date.format(language: "en-US", underline: .none) == "11 Sharaf (Honor) 183 B.E.")
        #expect(date.monthName(underline: .none) == "Sharaf")
        #expect(date.translatedMonthName() == "Honour")
        #expect(date.dayName(underline: .none) == "Mashíyyat")
        #expect(date.translatedDayName() == "Will")
        #expect(date.weekdayName() == "Jamál")
        #expect(date.translatedWeekdayName(language: "de") == "Schönheit")
        #expect(date.yearInVahidName() == "Javáb")
        #expect(HolyDay.nawRuz.name(language: "fa-IR") == HolyDay.nawRuz.name(language: "fa"))
        #expect(HolyDay.nawRuz.name(language: "xx") == "Naw-Rúz")
        #expect(BadiDate.supportedLanguages.contains("fa"))
    }

    @Test func zeroPaddedVahid() throws {
        // The 18th and 19th Váḥid, which badiDate's 'vv' renders as "-1" and "00".
        #expect(try BadiDate(year: 324, month: 1, day: 1).format("vv v") == "18 18")
        #expect(try BadiDate(year: 343, month: 1, day: 1).format("vv v") == "19 19")
        #expect(try BadiDate(year: 362, month: 1, day: 1).format("vv v kk") == "01 1 02")
    }

    @Test func abbreviationsKeepCombiningMarks() throws {
        // Raḥmat and ‘Aẓamat are written with combining dots in Russian; badiDate cuts those off.
        #expect(try BadiDate(year: 183, month: 6, day: 4).format("M D", language: "ru") == "Рах\u{323} ‘Аз\u{323}а")
        #expect(try BadiDate(year: 183, month: 16, day: 4).format("M D", underline: .none) == "Sha ‘Aẓa")
        #expect(try BadiDate(year: 183, month: 16, day: 9).format("M D", underline: .htmlTag) == "<u>Sh</u>a Asm")
        // A doubled letter keeps its mark in Persian and Arabic, where badiDate cuts it off.
        #expect(try BadiDate(year: 183, month: 11, day: 10).format("M D", language: "fa") == "مشیّ عزّت")
        #expect(try BadiDate(year: 183, month: BadiDate.ayyamiHa, day: 1).format("M", language: "ar") == "أيّا")
    }

    @Test func unmatchedBraceIsLiteral() throws {
        #expect(try BadiDate(year: 183, month: 1, day: 1).format("{d} d {d") == "d 1 {1")
    }

    @Test func persianMonthNamesAreThePersianForms() throws {
        let names = try (1...19).map { try BadiDate(year: 183, month: $0, day: 1).monthName(language: "fa") }
        #expect(names == [
            "بهاء", "جلال", "جمال", "عظمت", "نور", "رحمت", "کلمات", "کمال", "اسماء", "عزّت", "مشیّت", "علم", "قدرت", "قول",
            "مسائل", "شرف", "سلطان", "ملک", "علاء",
        ])
        let ayyamiHa = try BadiDate(year: 183, month: BadiDate.ayyamiHa, day: 1)
        #expect(ayyamiHa.monthName(language: "fa") == "ایّام ها")
        #expect(ayyamiHa.monthName(language: "fa-IR") == "ایّام ها")
        #expect(try BadiDate(year: 183, month: 3, day: 11).dayName(language: "fa") == "مشیّت")
        #expect(try BadiDate(year: 183, month: 11, day: 1).translatedMonthName(language: "fa") == "مشیّت")
        // No Arabic kaf or yeh is left in a Persian month name.
        #expect(names.allSatisfy { !$0.contains("ك") && !$0.contains("ي") })
        #expect(HolyDay.birthOfBahaullah.name(language: "fa") == "تولّد حضرت بهاءالله")
    }

    @Test func arabicMonthNamesKeepTheirMarks() throws {
        #expect(try BadiDate(year: 183, month: 11, day: 1).monthName(language: "ar") == "المشيّة")
        #expect(try BadiDate(year: 183, month: BadiDate.ayyamiHa, day: 1).monthName(language: "ar") == "أيّام الهاء")
        #expect(try BadiDate(year: 183, month: 1, day: 1).monthName(language: "ar") == "البهاء")
    }
}
