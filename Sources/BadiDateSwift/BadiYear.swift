/// The facts about one Badí‘ year that the rest of the calendar is derived from.
struct BadiYear: Sendable {
    /// Gregorian day on whose sunset Naw-Rúz ends.
    let nawRuz: GregorianDate
    let ayyamiHaLength: Int
    let birthOfTheBab: (month: Int, day: Int)
    let birthOfBahaullah: (month: Int, day: Int)

    /// From 172 B.E. Naw-Rúz follows the equinox in Ṭihrán and the Twin Birthdays follow the moon. Before that the
    /// calendar was tied to the Gregorian one.
    static let firstAstronomicalYear = BadiYearTable.firstYear

    /// Valid for 1 B.E. up to one year past `BadiDate.validYears`, which is needed to place Gregorian dates in
    /// the final months of the range.
    static func info(_ year: Int) -> BadiYear {
        if year < firstAstronomicalYear {
            let gregorianYear = 1843 + year
            return BadiYear(
                nawRuz: GregorianDate(uncheckedYear: gregorianYear, month: 3, day: 21),
                ayyamiHaLength: GregorianDate.isLeapYear(gregorianYear + 1) ? 5 : 4,
                birthOfTheBab: (12, 5),
                birthOfBahaullah: (13, 9)
            )
        }
        return table[year - firstAstronomicalYear]
    }

    private static let table: [BadiYear] = {
        let digits = BadiYearTable.packed.utf8.map { byte -> Int in
            // Base 36: '0'-'9' then 'a'-'z'.
            byte < 58 ? Int(byte) - 48 : Int(byte) - 87
        }
        return (0..<BadiYearTable.count).map { index in
            let entry = digits[(index * 4)..<(index * 4 + 4)]
            let first = (month: entry[entry.startIndex + 2], day: entry[entry.startIndex + 3])
            return BadiYear(
                nawRuz: GregorianDate(uncheckedYear: 2015 + index, month: 3, day: entry[entry.startIndex]),
                ayyamiHaLength: entry[entry.startIndex + 1],
                birthOfTheBab: first,
                birthOfBahaullah: first.day < 19 ? (first.month, first.day + 1) : (first.month + 1, 1)
            )
        }
    }()
}
