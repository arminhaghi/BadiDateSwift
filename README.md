# BadiDateSwift

Dates in the Badí‘ (Bahá’í) calendar for Swift: conversion to and from Gregorian dates, Holy Days, the sunset
that starts and ends each day at a given place, and names in 12 languages.

It is a port of [badiDate](https://github.com/janrg/badiDate) by Jan Greis and is tested against it, so both give
the same answers. It has no dependencies beyond Foundation.

## Installation

```swift
.package(url: "https://github.com/arminhaghi/BadiDateSwift.git", from: "0.2.0")
```

Requires Swift 6. Supports iOS 13, macOS 10.15, watchOS 6, tvOS 13 and visionOS 1 or later.

## Usage

```swift
import BadiDateSwift

// From a Gregorian day, from Badí‘ components, or from a Holy Day
let date = try BadiDate(gregorianYear: 2026, month: 3, day: 21)
let same = try BadiDate(year: 183, month: 1, day: 1)
let ridvan = try BadiDate(year: 183, holyDay: .firstRidvan)

date.year            // 183
date.holyDay         // .nawRuz
date.isWorkSuspended // true
date.gregorianDate   // 2026-03-21
date.format()        // "1 Bahá (Splendour) 183 B.E."
date.nextFeast       // 1 Jalál 183
date.nextHolyDay     // First Day of Riḍván
date.format("d MM y", language: "fa")
```

A `BadiDate` stands for one Gregorian day, the one on whose sunset it ends. The Badí‘ day actually runs from
sunset to sunset, so to know which date it is at some moment and place, use `LocalBadiDate`:

```swift
let now = try LocalBadiDate(
    Date(),
    latitude: 32.8191,
    longitude: 34.9983,
    timeZone: TimeZone(identifier: "Asia/Jerusalem")!
)

now.badiDate             // the date in effect right now
now.start                // sunset that began it
now.end                  // sunset that ends it
now.sunrise              // useful during the Fast
now.holyDayCommemoration // e.g. noon for the Martyrdom of the Báb
now.nextDay              // tomorrow, with its own times
now.sunPosition()        // how far through the night or the daytime it is
```

`now.end` is the moment to schedule a widget or complication refresh for.

### Things to know

- Months are numbered 1 to 19, and Ayyám-i-Há is month 20, even though it falls between months 18 and 19.
- Valid dates run from 1 Bahá 1 B.E. (21 March 1844) to 19 ‘Alá’ 507 B.E. (20 March 2351). Anything outside
  throws `BadiDateError.outOfRange`.
- In parts of Canada, Finland, Iceland, Norway, Sweden and Alaska, fixed clock times are used instead of the
  actual sunset. `LocalBadiDate` applies these by default; pass `usesClockLocations: false` to turn that off.
- Where the sun doesn't set or rise on a day and no such rule applies, 18:00 and 06:00 are used (an hour later
  during daylight saving time).
- Sun times are rounded to the minute.

### Formatting

`format(_:language:underline:)` takes the same tokens as badiDate, listed in its documentation comment. Languages:
Arabic, Chinese, Dutch, English, French, German, Latvian, Persian, Portuguese, Russian, Spanish and Swedish.

Some transliterated names contain underlined letters, such as the "Sh" in Sharaf. `underline:` chooses between
combining low lines (the default), plain letters, and two HTML forms.

## Differences from badiDate

- Invalid input throws instead of producing an invalid date object.
- Right-to-left marks are emitted as characters, not HTML entities, and the `<span dir="rtl">` wrapper is left out.
- Three-letter abbreviations are cut by character, so a letter keeps its combining marks.
- The `vv` token is correct for the 18th and 19th Váḥid.
- `HolyDay.name(language:)` falls back from a regional code such as `fa-IR` to its base language.
- An unmatched `{` in a format is output as is.
- Two commemoration times follow the guidance more closely. The Declaration of the Báb is the hour on the clock
  nearest to two hours after sunset, where badiDate uses 2 hours 11 minutes to the minute, and the Martyrdom of the
  Báb is noon in local standard time, where badiDate uses solar noon.

## How it is tested

`Scripts/generate-fixtures.mjs` runs badiDate over every year, a sample of days across the whole range, and about
600 dates in each of 27 places from Apia to Longyearbyen, and writes the results to
`Tests/BadiDateSwiftTests/Fixtures`. The Swift tests check that this package agrees with all of it, and separately
walk every day of the valid range for internal consistency.

The local times in the fixtures depend on the time zone database, so they only use zones without recent rule
changes. If a test fails after an operating system update, a changed time zone rule is the first thing to check.

To regenerate the fixtures, or the data files in `Sources/BadiDateSwift/Generated` after an upstream change:

```bash
cd Scripts
npm install
node generate-fixtures.mjs
node generate-swift-data.mjs /path/to/badiDate
```

## Credits and licence

MIT, Copyright (c) 2026 Armin Haghi. The calendar logic, the table of years, the clock location polygons and the translations come from
[badiDate](https://github.com/janrg/badiDate), and the sun calculations from
[MeeusSunMoon](https://github.com/janrg/MeeusSunMoon), both by Jan Greis.
