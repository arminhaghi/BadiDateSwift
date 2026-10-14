/// Corrections to the month names in badiDate's Persian and Arabic data, applied over the generated tables so that
/// those stay a faithful copy of upstream. Each one belongs upstream too; remove it here once it has been made there.
extension BadiLocaleData {
    /// Off only in tests that compare this package with badiDate itself.
    @TaskLocal static var appliesCorrections = true

    /// The corrected entry for `index` in `table` of the language `code`, if there is one. Month names double as the
    /// names of the days of the month, so both tables of month names are covered.
    static func correction(_ code: String, _ table: KeyPath<BadiLocaleData, [Int: String]>, _ index: Int) -> String? {
        guard appliesCorrections, table == \BadiLocaleData.month || table == \BadiLocaleData.monthL else { return nil }
        switch code {
        case "fa": return persianMonths[index]
        case "ar": return arabicMonths[index]
        default: return nil
        }
    }

    /// The Persian forms, without the Arabic article and in Persian letters (ک and ی rather than ك and ي), as the
    /// Bahá’í community writes them. badiDate's Persian data has the Arabic forms in `month` and Arabic letters in
    /// `monthL`.
    static let persianMonths: [Int: String] = [
        1: "بهاء", 2: "جلال", 3: "جمال", 4: "عظمت", 5: "نور", 6: "رحمت", 7: "کلمات", 8: "کمال", 9: "اسماء", 10: "عزّت",
        11: "مشیّت", 12: "علم", 13: "قدرت", 14: "قول", 15: "مسائل", 16: "شرف", 17: "سلطان", 18: "ملک", 19: "علاء",
        20: "ایّام ها",
    ]

    /// The Arabic forms with the two marks badiDate's data leaves out: the doubled ي of المشيّة, and the hamza and
    /// doubled ي of أيّام الهاء.
    static let arabicMonths: [Int: String] = [11: "المشيّة", 20: "أيّام الهاء"]
}
