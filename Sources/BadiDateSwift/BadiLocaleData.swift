/// The strings for one language. Anything a language leaves out falls back to its base language and then English.
struct BadiLocaleData: Sendable {
    var month: [Int: String] = [:]
    /// Month names translated into the language instead of transliterated.
    var monthL: [Int: String] = [:]
    var holyDay: [Int: String] = [:]
    var weekday: [Int: String] = [:]
    var weekdayAbbr3: [Int: String] = [:]
    var weekdayAbbr2: [Int: String] = [:]
    var weekdayL: [Int: String] = [:]
    var yearInVahid: [Int: String] = [:]
    var vahid: String?
    var kulliShay: String?
    var be: String?
    var badiCalendar: String?
    var unicodeCharForZero: String?
    var defaultFormat: String?

    static let fallbackLanguage = "en"

    /// The codes of the languages to consult for `language`, most specific first, keeping only those there is data for.
    static func codes(for language: String) -> [String] {
        let code = language.lowercased().replacingOccurrences(of: "_", with: "-")
        var codes = [code]
        if let base = code.split(separator: "-").first, base != code {
            codes.append(String(base))
        }
        codes.append(fallbackLanguage)
        return codes.filter { all[$0] != nil }
    }

    /// The languages to consult for `language`, most specific first.
    static func chain(for language: String) -> [BadiLocaleData] {
        codes(for: language).compactMap { all[$0] }
    }

    static func item(_ table: KeyPath<BadiLocaleData, [Int: String]>, _ index: Int, language: String) -> String {
        for code in codes(for: language) {
            if let value = correction(code, table, index) ?? all[code]?[keyPath: table][index] {
                return value
            }
        }
        return ""
    }

    static func item(_ string: KeyPath<BadiLocaleData, String?>, language: String) -> String {
        for locale in chain(for: language) {
            if let value = locale[keyPath: string] {
                return value
            }
        }
        return ""
    }
}

private extension String {
    func replacingOccurrences(of target: Character, with replacement: Character) -> String {
        String(map { $0 == target ? replacement : $0 })
    }
}
