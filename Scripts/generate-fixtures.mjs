// Generates the test fixtures from badiDate (https://github.com/janrg/badiDate), which the Swift tests treat as
// the reference implementation.
//
//   npm install && node generate-fixtures.mjs
//
// Writes into ../Tests/BadiDateSwiftTests/Fixtures/.
import fs from 'node:fs';
import { createRequire } from 'node:module';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const require = createRequire(import.meta.url);
const { BadiDate, LocalBadiDate, badiDateSettings } = require('badidate');
const { DateTime } = require('luxon');

const here = path.dirname(fileURLToPath(import.meta.url));
const outDir = path.join(here, '..', 'Tests', 'BadiDateSwiftTests', 'Fixtures');
fs.mkdirSync(outDir, { recursive: true });
const write = (name, lines) => fs.writeFileSync(path.join(outDir, name), `${lines.join('\n')}\n`);

const iso = (badiDate) => badiDate.gregorianDate.toISODate();
const seconds = (datetime) => (datetime === undefined ? '-' : String(datetime.toSeconds()));

// years.txt: year, Naw-Rúz, length of Ayyám-i-Há, the 11 Holy Days, the first day of months 1 to 20
{
    const lines = [];
    for (let year = 1; year <= 507; year++) {
        const nawRuz = new BadiDate({ year, month: 1, day: 1 });
        const fields = [year, iso(nawRuz), nawRuz.ayyamiHaLength];
        for (let holyDayNumber = 1; holyDayNumber <= 11; holyDayNumber++) {
            fields.push(iso(new BadiDate({ year, holyDayNumber })));
        }
        for (let month = 1; month <= 20; month++) {
            fields.push(iso(new BadiDate({ year, month, day: 1 })));
        }
        lines.push(fields.join(' '));
    }
    write('years.txt', lines);
}

// days.txt: Gregorian date, then year, month, day, weekday, Holy Day number (0 for none), year in Váḥid, Váḥid,
// Kull-i-Shay’
{
    const lines = [];
    const first = DateTime.fromISO('1844-03-21', { zone: 'UTC' });
    const last = DateTime.fromISO('2351-03-20', { zone: 'UTC' });
    const total = last.diff(first).as('days');
    for (let offset = 0; offset <= total; offset++) {
        // A sample across the whole range, plus every day near both ends and around the 172 B.E. reform.
        const nearEdge = offset < 400 || offset > total - 400;
        const nearReform = Math.abs(offset - 62456) < 800;
        if (offset % 29 !== 0 && !nearEdge && !nearReform) continue;
        const gregorian = first.plus({ days: offset });
        const badiDate = new BadiDate(gregorian);
        lines.push(
            [
                gregorian.toISODate(),
                badiDate.year,
                badiDate.month,
                badiDate.day,
                badiDate.weekday,
                badiDate.holyDayNumber ?? 0,
                badiDate.yearInVahid,
                badiDate.vahid,
                badiDate.kullIShay,
            ].join(' '),
        );
    }
    write('days.txt', lines);
}

// The expected times depend on the time zone database of the machine running the tests agreeing with the one
// in Node, so only zones without recent rule changes are used.
const locations = [
    ['haifa', 'Asia/Jerusalem', 32.8191, 34.9983],
    ['tehran', 'Asia/Tehran', 35.6892, 51.389],
    ['london', 'Europe/London', 51.5074, -0.1278],
    ['newyork', 'America/New_York', 40.7128, -74.006],
    ['losangeles', 'America/Los_Angeles', 34.0522, -118.2437],
    ['sydney', 'Australia/Sydney', -33.8688, 151.2093],
    ['auckland', 'Pacific/Auckland', -36.8485, 174.7633],
    ['nairobi', 'Africa/Nairobi', -1.2921, 36.8219],
    ['saopaulo', 'America/Sao_Paulo', -23.5505, -46.6333],
    ['tokyo', 'Asia/Tokyo', 35.6762, 139.6503],
    ['delhi', 'Asia/Kolkata', 28.6139, 77.209],
    ['kathmandu', 'Asia/Kathmandu', 27.7172, 85.324],
    ['stjohns', 'America/St_Johns', 47.5615, -52.7126],
    ['apia', 'Pacific/Apia', -13.8333, -171.7667],
    ['murmansk', 'Europe/Moscow', 68.9585, 33.0827],
    ['mcmurdo', 'Antarctica/McMurdo', -77.8419, 166.6863],
    ['anchorage', 'America/Anchorage', 61.2181, -149.9003],
    ['attu', 'America/Adak', 52.9, 172.9],
    ['iqaluit', 'America/Iqaluit', 63.7467, -68.517],
    ['reykjavik', 'Atlantic/Reykjavik', 64.1466, -21.9426],
    ['oslo', 'Europe/Oslo', 59.9139, 10.7522],
    ['tromso', 'Europe/Oslo', 69.6492, 18.9553],
    ['longyearbyen', 'Arctic/Longyearbyen', 78.2232, 15.6267],
    ['stockholm', 'Europe/Stockholm', 59.3293, 18.0686],
    ['kiruna', 'Europe/Stockholm', 67.8558, 20.2253],
    ['helsinki', 'Europe/Helsinki', 60.1699, 24.9384],
    ['rovaniemi', 'Europe/Helsinki', 66.5039, 25.7294],
];
// Locations to repeat with the fixed clock time rules switched off.
const withoutClock = ['anchorage', 'iqaluit', 'reykjavik', 'tromso', 'kiruna', 'rovaniemi'];

const sampleDates = () => {
    const dates = [];
    let badiDate = new BadiDate({ year: 172, month: 1, day: 1 });
    let index = 0;
    while (badiDate.year < 192) {
        const aroundYearEnd =
            badiDate.month === 20 || (badiDate.month === 19 && [1, 19].includes(badiDate.day)) ||
            (badiDate.month === 18 && badiDate.day === 19);
        if (index % 31 === 0 || badiDate.holyDayNumber || aroundYearEnd) {
            dates.push(badiDate);
        }
        badiDate = badiDate.nextDay;
        index++;
    }
    // A thin sample of other eras, which exercise the different ΔT approximations.
    for (const year of [107, 132, 157, 257, 357, 497]) {
        for (let month = 1; month <= 19; month += 3) {
            dates.push(new BadiDate({ year, month, day: 7 }));
        }
    }
    return dates;
};

// local.txt: location lines start with '#': id, time zone, latitude, longitude, whether clock locations are used.
// Then for each sampled date: year, month, day, start, sunrise, solar noon, end, Holy Day commemoration, clock
// location. Times are in seconds since 1970.
//
// moments.txt: location id, a moment in seconds since 1970, then the year, month and day in effect then.
{
    const dates = sampleDates();
    const local = [];
    const moments = [];
    const emit = (id, zone, latitude, longitude, useClock) => {
        local.push(['#', id, zone, latitude, longitude, useClock ? 1 : 0].join(' '));
        dates.forEach((badiDate, index) => {
            const date = { year: badiDate.year, month: badiDate.month, day: badiDate.day };
            const localDate = new LocalBadiDate(date, latitude, longitude, zone);
            local.push(
                [
                    date.year,
                    date.month,
                    date.day,
                    seconds(localDate.start),
                    seconds(localDate.sunrise),
                    seconds(localDate.solarNoon),
                    seconds(localDate.end),
                    seconds(localDate.holyDayCommemoration),
                    localDate.clockLocation ?? '-',
                ].join(' '),
            );
            if (index % 9 !== 0) return;
            const end = localDate.end.toSeconds();
            for (const moment of [end - 6 * 3600, end, end + 1, end + 4 * 3600]) {
                const { badiDate: result } = new LocalBadiDate(
                    DateTime.fromSeconds(moment, { zone }),
                    latitude,
                    longitude,
                    zone,
                );
                moments.push([id, moment, result.year, result.month, result.day].join(' '));
            }
        });
    };
    for (const [id, zone, latitude, longitude] of locations) {
        emit(id, zone, latitude, longitude, true);
    }
    badiDateSettings({ useClockLocations: false });
    for (const [id, zone, latitude, longitude] of locations.filter(([id]) => withoutClock.includes(id))) {
        emit(`${id}-noclock`, zone, latitude, longitude, false);
    }
    badiDateSettings({ useClockLocations: true });
    write('local.txt', local);
    write('moments.txt', moments);
}

// format.json: [year, month, day, language, underline, format or null, output]
{
    const languages = ['en', 'en-us', 'en-GB', 'ar', 'de', 'es', 'fa', 'fa-IR', 'fr', 'lv', 'nl', 'pt', 'ru', 'sv', 'zh', 'xx'];
    const formats = [
        null,
        'd|dd|D|DD|DDL|DD+',
        'm|mm|M|MM|MML|MM+',
        'W|ww|WW|WWL',
        'y|yy|yv|yyv|YV|v|k|kk|Va|KiS|BE|BC',
        '{Today is} WW, d MM y BE {(}dd.mm.yy{)}',
        'vv',
    ];
    const dates = [];
    for (let i = 0; i < 40; i++) {
        const year = [1, 19, 20, 100, 171, 172, 183, 300, 361, 362, 400, 507][i % 12];
        const month = (i % 20) + 1;
        const day = month === 20 ? (i % 4) + 1 : ((i * 7) % 19) + 1;
        dates.push(new BadiDate({ year, month, day }));
    }
    for (let month = 1; month <= 20; month++) {
        dates.push(new BadiDate({ year: 183, month, day: month === 20 ? 2 : month }));
    }
    // badiDate renders its right-to-left marks and isolation as HTML; the Swift port emits the plain characters.
    const normalize = (output) =>
        output.replaceAll('&#8207;', '‏').replace(/<span dir="rtl">([^<]*)<\/span>/g, '$1');
    const entries = [];
    for (const underline of ['diacritic', 'none', 'u', 'css']) {
        badiDateSettings({ underlineFormat: underline });
        for (const language of underline === 'diacritic' ? languages : ['en', 'ru']) {
            for (const badiDate of dates) {
                for (let format of formats) {
                    // badiDate crops by UTF-16 code unit, which splits letters from their combining marks in
                    // Russian. The Swift port crops by character, so those tokens are tested separately.
                    if (language === 'ru' && format) format = format.replace('|D|', '|').replace('|M|', '|');
                    // badiDate's 'vv' goes wrong for the 18th and 19th Váḥid; that case is tested separately.
                    if (format === 'vv' && badiDate.vahid >= 18) continue;
                    entries.push([
                        badiDate.year,
                        badiDate.month,
                        badiDate.day,
                        language,
                        underline,
                        format,
                        normalize(badiDate.format(format ?? undefined, language)),
                    ]);
                }
            }
        }
    }
    const holyDays = [];
    // badiDate's holyDay() doesn't fall back from a regional code to its base language, so those are left out.
    for (const language of languages.filter((code) => code !== 'fa-IR')) {
        for (let holyDayNumber = 1; holyDayNumber <= 11; holyDayNumber++) {
            holyDays.push([holyDayNumber, language, new BadiDate({ year: 183, holyDayNumber }).holyDay(language)]);
        }
    }
    fs.writeFileSync(path.join(outDir, 'format.json'), `${JSON.stringify({ entries, holyDays })}\n`);
}

console.log(`Wrote fixtures to ${outDir}`);
