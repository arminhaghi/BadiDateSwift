/// How to render the letters that are underlined in transliterated Persian and Arabic, such as the "Sh" in
/// Sharaf.
public enum UnderlineStyle: Sendable {
    /// Leave the letters plain.
    case none
    /// Follow each letter with a combining low line (U+0332).
    case diacritic
    /// Wrap the letters in `<u>`.
    case htmlTag
    /// Wrap the letters in a `<span>` with an inline underline style.
    case htmlStyle
}

extension BadiDate {
    /// The languages `format(_:language:underline:)` and the name properties have strings for.
    public static let supportedLanguages: [String] = BadiLocaleData.all.keys.sorted()

    /// Formats the date according to `format`, or the default format of `language` if `nil`.
    ///
    /// | Token | Output |
    /// |---|---|
    /// | `d`, `dd` | Day of the month, plain and zero-padded |
    /// | `D`, `DD`, `DDL`, `DD+` | Name of the day: first three letters, full, translated, full with translation |
    /// | `m`, `mm` | Number of the month, plain and zero-padded |
    /// | `M`, `MM`, `MML`, `MM+` | Name of the month, as for the day |
    /// | `W`, `ww`, `WW`, `WWL` | Weekday: three letters, two letters, full, translated |
    /// | `y`, `yy` | Year, plain and zero-padded to three digits |
    /// | `yv`, `yyv`, `YV` | Year in the Váḥid: plain, zero-padded, name |
    /// | `v`, `vv` | Váḥid, plain and zero-padded |
    /// | `k`, `kk` | Kull-i-Shay’, plain and zero-padded |
    /// | `Va`, `KiS`, `BE`, `BC` | The words "Váḥid", "Kull-i-Shay’", "B.E." and "Badí‘ Calendar" |
    ///
    /// Text in braces is output as is. Languages that leave a string out fall back to their base language and then
    /// to English, and so does an unknown language.
    public func format(_ format: String? = nil, language: String = "en", underline: UnderlineStyle = .diacritic) -> String {
        let pattern = Array(format ?? BadiLocaleData.item(\.defaultFormat, language: language))
        var output = ""
        var index = 0
        while index < pattern.count {
            if pattern[index] == "{", let close = pattern[index...].firstIndex(of: "}") {
                output += String(pattern[(index + 1)..<close])
                index = close + 1
                continue
            }
            var matched = false
            for length in [3, 2, 1] where index + length <= pattern.count {
                let token = String(pattern[index..<(index + length)])
                if let item = formatItem(token, language: language, underline: underline) {
                    output += item
                    index += length
                    matched = true
                    break
                }
            }
            if !matched {
                output.append(pattern[index])
                index += 1
            }
        }
        return output
    }

    /// The transliterated name of the month, e.g. "Bahá".
    public func monthName(language: String = "en", underline: UnderlineStyle = .diacritic) -> String {
        underlined(BadiLocaleData.item(\.month, month, language: language), underline)
    }

    /// The name of the month translated into `language`, e.g. "Splendour".
    public func translatedMonthName(language: String = "en") -> String {
        BadiLocaleData.item(\.monthL, month, language: language)
    }

    /// The transliterated name of the day of the month. Days carry the same names as the months.
    public func dayName(language: String = "en", underline: UnderlineStyle = .diacritic) -> String {
        underlined(BadiLocaleData.item(\.month, day, language: language), underline)
    }

    /// The name of the day of the month translated into `language`, e.g. "Splendour".
    public func translatedDayName(language: String = "en") -> String {
        BadiLocaleData.item(\.monthL, day, language: language)
    }

    /// The transliterated name of the weekday, e.g. "Jalál".
    public func weekdayName(language: String = "en") -> String {
        BadiLocaleData.item(\.weekday, weekday, language: language)
    }

    /// The name of the weekday translated into `language`, e.g. "Glory".
    public func translatedWeekdayName(language: String = "en") -> String {
        BadiLocaleData.item(\.weekdayL, weekday, language: language)
    }

    /// The name of the year within its Váḥid, e.g. "Alif".
    public func yearInVahidName(language: String = "en") -> String {
        BadiLocaleData.item(\.yearInVahid, yearInVahid, language: language)
    }

    private func formatItem(_ token: String, language: String, underline: UnderlineStyle) -> String? {
        let digits = { (number: Int, width: Int) in BadiDate.localizedDigits(number, width: width, language: language) }
        let item = { (table: KeyPath<BadiLocaleData, [Int: String]>, index: Int) in
            BadiLocaleData.item(table, index, language: language)
        }
        let withTranslation = { (index: Int) -> String in
            let name = underlined(item(\.month, index), underline)
            let translation = item(\.monthL, index)
            return name == translation ? name : "\(name) (\(translation))"
        }
        switch token {
        case "d": return digits(day, 1)
        case "D": return underlined(item(\.month, day), underline, crop: 3)
        case "m": return digits(month, 1)
        case "M": return underlined(item(\.month, month), underline, crop: 3)
        case "W": return item(\.weekdayAbbr3, weekday)
        case "y": return digits(year, 1)
        case "v": return digits(vahid, 1)
        case "k": return digits(kullIShay, 1)
        case "dd": return digits(day, 2)
        case "DD": return underlined(item(\.month, day), underline)
        case "mm": return digits(month, 2)
        case "MM": return underlined(item(\.month, month), underline)
        case "ww": return item(\.weekdayAbbr2, weekday)
        case "WW": return item(\.weekday, weekday)
        case "yy": return digits(year, 3)
        case "yv": return digits(yearInVahid, 1)
        case "YV": return item(\.yearInVahid, yearInVahid)
        case "vv": return digits(vahid, 2)
        case "kk": return digits(kullIShay, 2)
        case "Va": return BadiLocaleData.item(\.vahid, language: language)
        case "BE": return BadiLocaleData.item(\.be, language: language)
        case "BC": return BadiLocaleData.item(\.badiCalendar, language: language)
        case "DDL": return item(\.monthL, day)
        case "DD+": return withTranslation(day)
        case "MML": return item(\.monthL, month)
        case "MM+": return withTranslation(month)
        case "WWL": return item(\.weekdayL, weekday)
        case "yyv": return digits(yearInVahid, 2)
        case "KiS": return underlined(BadiLocaleData.item(\.kulliShay, language: language), underline)
        default: return nil
        }
    }

    private static func localizedDigits(_ number: Int, width: Int, language: String) -> String {
        let plain = String(number)
        let padded = String(repeating: "0", count: max(0, width - plain.count)) + plain
        guard let zero = BadiLocaleData.item(\.unicodeCharForZero, language: language).unicodeScalars.first,
              zero != "0"
        else {
            return padded
        }
        return String(String.UnicodeScalarView(padded.unicodeScalars.map { digit in
            Unicode.Scalar(zero.value + digit.value - 48) ?? digit
        }))
    }
}

/// Locale strings mark underlined letters by wrapping them in underscores, as in "_Sh_araf". Renders that markup,
/// optionally after cropping the string to its first `crop` letters.
private func underlined(_ item: String, _ style: UnderlineStyle, crop: Int? = nil) -> String {
    let ignored: Set<Character> = ["_", "’", "‘"]
    var characters = Array(item)
    if let crop, crop < characters.count {
        var end = 0
        var counted = 0
        while counted < crop, end < characters.count {
            if !ignored.contains(characters[end]) {
                counted += 1
            }
            end += 1
        }
        if end < characters.count, ignored.contains(characters[end]) {
            end += 1
        }
        characters = Array(characters[..<end])
        // Close an underline that the crop cut open.
        if characters.filter({ $0 == "_" }).count % 2 == 1 {
            characters.append("_")
        }
    }
    let parts = characters.split(separator: "_", omittingEmptySubsequences: false).map { String($0) }
    return parts.enumerated().map { index, part in
        guard index % 2 == 1 else { return part }
        switch style {
        case .none: return part
        case .diacritic: return part.map { "\($0)\u{0332}" }.joined()
        case .htmlTag: return "<u>\(part)</u>"
        case .htmlStyle: return "<span style=\"text-decoration:underline\">\(part)</span>"
        }
    }.joined()
}
