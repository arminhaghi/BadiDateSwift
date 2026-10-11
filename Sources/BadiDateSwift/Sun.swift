import Foundation

/// Sunrise, sunset and solar noon after Jean Meeus, "Astronomical Algorithms" (AA), 2nd edition.
///
/// A port of the solar half of MeeusSunMoon by Jan Greis (https://github.com/janrg/MeeusSunMoon), configured the
/// way badiDate uses it: times are rounded to the nearest minute, and a day without a sunrise or sunset yields a
/// fixed clock time instead.
struct Sun {
    let clock: LocalClock
    let latitude: Double
    let longitude: Double

    private enum Event {
        case rise, set
    }

    private enum NoEvent: Error {
        case sunHigh, sunLow
    }

    /// Sunrise on the day `date` falls on, or 06:00 (07:00 during DST) if the sun doesn't rise that day.
    func sunrise(on date: Date) -> Date {
        riseOrSet(.rise, on: date, fallbackHour: 6)
    }

    /// Sunset on the day `date` falls on, or 18:00 (19:00 during DST) if the sun doesn't set that day.
    func sunset(on date: Date) -> Date {
        riseOrSet(.set, on: date, fallbackHour: 18)
    }

    /// Solar transit on the day `date` falls on (AA p102f).
    func solarNoon(on date: Date) -> Date {
        let day = GregorianDate(date, in: clock.timeZone)
        let start = Midnight(day)
        // Sign flip for longitude from AA as we take East as positive
        var m = normalized((start.alpha - longitude - start.theta0) / 360, offset: clock.offset(at: date))
        let theta = start.theta0 + 360.985647 * m
        let n = m + start.deltaT / 864_000
        m += -localHourAngle(theta, interpolatedRightAscension(start.t, n)) / 360
        return start.date(addingSeconds: (m * 86400 + 0.5).rounded(.down))
    }

    private func riseOrSet(_ event: Event, on date: Date, fallbackHour: Int) -> Date {
        do {
            return try riseOrSet(event, on: date)
        } catch {
            let day = GregorianDate(date, in: clock.timeZone)
            let fraction = date.timeIntervalSince1970 - date.timeIntervalSince1970.rounded(.down)
            return clock.date(day, hour: fallbackHour) + fraction + (clock.isInDST(date) ? 3600 : 0)
        }
    }

    /// AA p102f. `offset` is the number of degrees below the horizon that counts as the event.
    private func riseOrSet(_ event: Event, on date: Date, degreesBelowHorizon offset: Double = 50 / 60) throws -> Date {
        let day = GregorianDate(date, in: clock.timeZone)
        let start = Midnight(day)
        let delta = sunApparentDeclination(start.td)
        let h0 = try approximateLocalHourAngle(delta, offset)
        // Sign flip for longitude from AA as we take East as positive
        let m0 = normalized((start.alpha - longitude - start.theta0) / 360, offset: clock.offset(at: date))
        var m = event == .rise ? m0 - h0 / 360 : m0 + h0 / 360
        var correction = 1.0
        var iterations = 0
        // Repeat if correction is larger than ~9s
        while abs(correction) > 0.0001, iterations < 3 {
            let theta = start.theta0 + 360.985647 * m
            let n = m + start.deltaT / 864_000
            let delta = interpolatedDeclination(start.t, n)
            let hourAngle = localHourAngle(theta, interpolatedRightAscension(start.t, n))
            correction = (altitude(delta, hourAngle) + offset) / (360 * cosd(delta) * cosd(latitude) * sind(hourAngle))
            m += correction
            iterations += 1
        }
        let seconds = m > 0 ? (m * 86400 + 0.5).rounded(.down) : -(abs(m) * 86400 + 0.5).rounded(.down)
        return start.date(addingSeconds: seconds)
    }

    /// The quantities AA's method needs at 0h UT of a calendar day.
    private struct Midnight {
        let secondsSinceEpoch: Double
        /// ΔT = TT − UT, in seconds.
        let deltaT: Double
        /// Julian centuries since J2000.0.
        let t: Double
        /// `t` at 0h dynamical time instead of 0h UT.
        let td: Double
        /// Apparent sidereal time at Greenwich.
        let theta0: Double
        /// Apparent right ascension of the sun.
        let alpha: Double

        init(_ day: GregorianDate) {
            secondsSinceEpoch = Double(day.daysSinceEpoch) * 86400
            deltaT = Sun.deltaT(year: Double(day.year) + (Double(day.month) - 0.5) / 12)
            // The Julian date of 1970-01-01T00:00Z is 2440587.5 and of J2000.0 is 2451545.
            t = (Double(day.daysSinceEpoch) + 2_440_587.5 - 2_451_545) / 36525
            td = t - deltaT / (3600 * 24 * 36525)
            theta0 = apparentSiderealTimeGreenwich(t)
            alpha = sunApparentRightAscension(td)
        }

        func date(addingSeconds seconds: Double) -> Date {
            // Round to the nearest minute.
            let rounded = ((secondsSinceEpoch + seconds + 30) / 60).rounded(.down) * 60
            return Date(timeIntervalSince1970: rounded)
        }
    }

    /// AA p102 Eq15.1
    private func approximateLocalHourAngle(_ delta: Double, _ offset: Double) throws -> Double {
        let cosH0 = (sind(-offset) - sind(latitude) * sind(delta)) / (cosd(latitude) * cosd(delta))
        if cosH0 < -1 {
            throw NoEvent.sunHigh
        } else if cosH0 > 1 {
            throw NoEvent.sunLow
        }
        return rad2deg(acos(cosH0))
    }

    /// Moves a fractional time of day onto the correct local date. `offset` is in minutes east of UTC.
    private func normalized(_ m: Double, offset: Double) -> Double {
        let localM = m + offset / 1440
        if localM < 0 {
            return m + 1
        }
        if localM > 1 {
            return m - 1
        }
        return m
    }

    /// AA p103
    private func localHourAngle(_ theta0: Double, _ alpha: Double) -> Double {
        // Sign flip for longitude
        let hourAngle = reduceAngle(theta0 + longitude - alpha)
        return hourAngle > 180 ? hourAngle - 360 : hourAngle
    }

    /// AA p93 Eq13.6
    private func altitude(_ delta: Double, _ hourAngle: Double) -> Double {
        rad2deg(asin(sind(latitude) * sind(delta) + cosd(latitude) * cosd(delta) * cosd(hourAngle)))
    }
}

// MARK: - Position of the sun

/// AA p103
private func interpolatedRightAscension(_ t: Double, _ n: Double) -> Double {
    let alpha1 = sunApparentRightAscension(t - 1 / 36525)
    let alpha2 = sunApparentRightAscension(t)
    let alpha3 = sunApparentRightAscension(t + 1 / 36525)
    return reduceAngle(interpolateFromThree(alpha1, alpha2, alpha3, n, normalize: true))
}

/// AA p103
private func interpolatedDeclination(_ t: Double, _ n: Double) -> Double {
    let delta1 = sunApparentDeclination(t - 1 / 36525)
    let delta2 = sunApparentDeclination(t)
    let delta3 = sunApparentDeclination(t + 1 / 36525)
    return reduceAngle(interpolateFromThree(delta1, delta2, delta3, n))
}

/// AA p165 Eq25.6
private func sunApparentRightAscension(_ t: Double) -> Double {
    let omega = moonAscendingNodeLongitude(t)
    let epsilon = trueObliquityOfEcliptic(t) + 0.00256 * cosd(omega)
    let lambda = sunApparentLongitude(t)
    return reduceAngle(rad2deg(atan2(cosd(epsilon) * sind(lambda), cosd(lambda))))
}

/// AA p165 Eq25.7
private func sunApparentDeclination(_ t: Double) -> Double {
    let omega = moonAscendingNodeLongitude(t)
    let epsilon = trueObliquityOfEcliptic(t) + 0.00256 * cosd(omega)
    let lambda = sunApparentLongitude(t)
    return rad2deg(asin(sind(epsilon) * sind(lambda)))
}

/// AA p88
private func apparentSiderealTimeGreenwich(_ t: Double) -> Double {
    let theta0 = meanSiderealTimeGreenwich(t)
    let epsilon = trueObliquityOfEcliptic(t)
    return reduceAngle(theta0 + nutation(t).longitude * cosd(epsilon))
}

/// AA p88 Eq12.4
private func meanSiderealTimeGreenwich(_ t: Double) -> Double {
    let jd2000 = t * 36525
    return 280.46061837 + 360.98564736629 * jd2000 + 0.000387933 * (t * t) - (t * t * t) / 38_710_000
}

/// AA p147
private func trueObliquityOfEcliptic(_ t: Double) -> Double {
    meanObliquityOfEcliptic(t) + nutation(t).obliquity
}

/// AA p147 Eq22.3
private func meanObliquityOfEcliptic(_ t: Double) -> Double {
    polynomial(t / 100, Coefficients.meanObliquityOfEcliptic)
}

/// AA p164
private func sunApparentLongitude(_ t: Double) -> Double {
    sunTrueLongitude(t) - 0.00569 - 0.00478 * sind(moonAscendingNodeLongitude(t))
}

/// AA p164
private func sunTrueLongitude(_ t: Double) -> Double {
    sunMeanLongitude(t) + sunEquationOfCenter(t)
}

/// AA p164
private func sunEquationOfCenter(_ t: Double) -> Double {
    let m = sunMeanAnomaly(t)
    return (1.914602 - 0.004817 * t - 0.000014 * (t * t)) * sind(m)
        + (0.019993 - 0.000101 * t) * sind(2 * m)
        + 0.000290 * sind(3 * m)
}

/// Nutation in longitude and in obliquity (AA p144ff).
private func nutation(_ t: Double) -> (longitude: Double, obliquity: Double) {
    let d = moonMeanElongation(t)
    let m = sunMeanAnomaly(t)
    let mPrime = moonMeanAnomaly(t)
    let f = moonArgumentOfLatitude(t)
    let omega = moonAscendingNodeLongitude(t)
    var deltaPsi = 0.0
    var deltaEpsilon = 0.0
    for term in Coefficients.nutations {
        let argument = term[0] * d + term[1] * m + term[2] * mPrime + term[3] * f + term[4] * omega
        deltaPsi += (term[5] + term[6] * t) * sind(argument)
        deltaEpsilon += (term[7] + term[8] * t) * cosd(argument)
    }
    return (deltaPsi / 36_000_000, deltaEpsilon / 36_000_000)
}

/// AA p144
private func moonArgumentOfLatitude(_ t: Double) -> Double {
    reduceAngle(polynomial(t, Coefficients.moonArgumentOfLatitude))
}

/// Longitude of the ascending node of the moon's mean orbit on the ecliptic (AA p144).
private func moonAscendingNodeLongitude(_ t: Double) -> Double {
    reduceAngle(polynomial(t, Coefficients.moonAscendingNodeLongitude))
}

/// AA p144
private func moonMeanAnomaly(_ t: Double) -> Double {
    reduceAngle(polynomial(t, Coefficients.moonMeanAnomaly))
}

/// AA p144
private func moonMeanElongation(_ t: Double) -> Double {
    reduceAngle(polynomial(t, Coefficients.moonMeanElongation))
}

/// AA p144
private func sunMeanAnomaly(_ t: Double) -> Double {
    reduceAngle(polynomial(t, Coefficients.sunMeanAnomaly))
}

/// AA p163
private func sunMeanLongitude(_ t: Double) -> Double {
    reduceAngle(polynomial(t, Coefficients.sunMeanLongitude))
}

extension Sun {
    /// ΔT = TT − UT for a fractional year (http://eclipse.gsfc.nasa.gov/SEcat5/deltatpoly.html).
    static func deltaT(year y: Double) -> Double {
        switch y {
        case ..<1800:
            // Before the range of the Badí‘ calendar; only the long-term parabola is kept.
            let u = (y - 1820) / 100
            return -20 + 32 * (u * u)
        case ..<1860:
            return polynomial(
                y - 1800,
                [13.72, -0.332447, 0.0068612, 0.0041116, -0.00037436, 0.0000121272, -0.0000001699, 0.000000000875]
            )
        case ..<1900:
            return polynomial(y - 1860, [7.62, 0.5737, -0.251754, 0.01680668, -0.0004473624, 1 / 233_174])
        case ..<1920:
            return polynomial(y - 1900, [-2.79, 1.494119, -0.0598939, 0.0061966, -0.000197])
        case ..<1941:
            return polynomial(y - 1920, [21.20, 0.84493, -0.076100, 0.0020936])
        case ..<1961:
            return polynomial(y - 1950, [29.07, 0.407, -1 / 233, 1 / 2547])
        case ..<1986:
            return polynomial(y - 1975, [45.45, 1.067, -1 / 260, -1 / 718])
        case ..<2005:
            return polynomial(y - 2000, [63.86, 0.3345, -0.060374, 0.0017275, 0.000651814, 0.00002373599])
        case ..<2050:
            return polynomial(y - 2000, [62.92, 0.32217, 0.005589])
        case ..<2150:
            let u = (y - 1820) / 100
            return -20 + 32 * (u * u) - 0.5628 * (2150 - y)
        default:
            let u = (y - 1820) / 100
            return -20 + 32 * (u * u)
        }
    }
}

// MARK: - Maths

private func sind(_ degrees: Double) -> Double {
    sin(degrees * 0.017453292519943295)
}

private func cosd(_ degrees: Double) -> Double {
    cos(degrees * 0.017453292519943295)
}

private func rad2deg(_ radians: Double) -> Double {
    radians * 57.29577951308232
}

/// Reduces an angle to the interval 0-360°.
private func reduceAngle(_ angle: Double) -> Double {
    angle - 360 * (angle / 360).rounded(.down)
}

/// Evaluates A + Bx + Cx^2...
private func polynomial(_ x: Double, _ coefficients: [Double]) -> Double {
    var power = 1.0
    var sum = 0.0
    for coefficient in coefficients {
        sum += power * coefficient
        power *= x
    }
    return sum
}

/// Interpolates from three equidistant values (AA p24 Eq3.3).
private func interpolateFromThree(_ y1: Double, _ y2: Double, _ y3: Double, _ n: Double, normalize: Bool = false) -> Double {
    var a = y2 - y1
    var b = y3 - y2
    if normalize {
        if a < 0 {
            a += 360
        }
        if b < 0 {
            b += 360
        }
    }
    let c = b - a
    return y2 + (n / 2) * (a + b + n * c)
}

private enum Coefficients {
    /// AA p144
    static let sunMeanAnomaly: [Double] = [357.52772, 35999.050340, -0.0001603, -1 / 300_000]

    /// AA p163 Eq25.2
    static let sunMeanLongitude: [Double] = [280.46646, 36000.76983, 0.0003032]

    /// AA p147 Eq22.3
    static let meanObliquityOfEcliptic: [Double] = [
        84381.448 / 3600,
        -4680.93 / 3600,
        -1.55 / 3600,
        1999.25 / 3600,
        -51.38 / 3600,
        -249.67 / 3600,
        -39.05 / 3600,
        7.12 / 3600,
        27.87 / 3600,
        5.79 / 3600,
        2.45 / 3600,
    ]

    /// AA p144
    static let moonArgumentOfLatitude: [Double] = [93.27191, 483202.017538, -0.0036825, 1 / 327_270]

    /// AA p144
    static let moonAscendingNodeLongitude: [Double] = [125.04452, -1934.136261, 0.0020708, 1 / 450_000]

    /// AA p144
    static let moonMeanAnomaly: [Double] = [134.96298, 477198.867398, 0.0086972, 1 / 56250]

    /// AA p144
    static let moonMeanElongation: [Double] = [297.85036, 445267.111480, -0.0019142, 1 / 189_474]

    /// Nutations in longitude and obliquity (AA p145f).
    static let nutations: [[Double]] = [
        [0, 0, 0, 0, 1, -171996, -174.2, 92025, 8.9],
        [-2, 0, 0, 2, 2, -13187, -1.6, 5736, -3.1],
        [0, 0, 0, 2, 2, -2274, -0.2, 977, -0.5],
        [0, 0, 0, 0, 2, 2062, 0.2, -895, 0.5],
        [0, 1, 0, 0, 0, 1426, -3.4, 54, -0.1],
        [0, 0, 1, 0, 0, 712, 0.1, -7, 0],
        [-2, 1, 0, 2, 2, -517, 1.2, 224, -0.6],
        [0, 0, 0, 2, 1, -386, -0.4, 200, 0],
        [0, 0, 1, 2, 2, -301, 0, 129, -0.1],
        [-2, -1, 0, 2, 2, 217, -0.5, -95, 0.3],
        [-2, 0, 1, 0, 0, -158, 0, 0, 0],
        [-2, 0, 0, 2, 1, 129, 0.1, -70, 0],
        [0, 0, -1, 2, 2, 123, 0, -53, 0],
        [2, 0, 0, 0, 0, 63, 0, 0, 0],
        [0, 0, 1, 0, 1, 63, 0.1, -33, 0],
        [2, 0, -1, 2, 2, -59, 0, 26, 0],
        [0, 0, -1, 0, 1, -58, -0.1, 32, 0],
        [0, 0, 1, 2, 1, -51, 0, 27, 0],
        [-2, 0, 2, 0, 0, 48, 0, 0, 0],
        [0, 0, -2, 2, 1, 46, 0, -24, 0],
        [2, 0, 0, 2, 2, -38, 0, 16, 0],
        [0, 0, 2, 2, 2, -31, 0, 13, 0],
        [0, 0, 2, 0, 0, 29, 0, 0, 0],
        [-2, 0, 1, 2, 2, 29, 0, -12, 0],
        [0, 0, 0, 2, 0, 26, 0, 0, 0],
        [-2, 0, 0, 2, 0, -22, 0, 0, 0],
        [0, 0, -1, 2, 1, 21, 0, -10, 0],
        [0, 2, 0, 0, 0, 17, -0.1, 0, 0],
        [2, 0, -1, 0, 1, 16, 0, -8, 0],
        [-2, 2, 0, 2, 2, -16, 0.1, 7, 0],
        [0, 1, 0, 0, 1, -15, 0, 9, 0],
        [-2, 0, 1, 0, 1, -13, 0, 7, 0],
        [0, -1, 0, 0, 1, -12, 0, 6, 0],
        [0, 0, 2, -2, 0, 11, 0, 0, 0],
        [2, 0, -1, 2, 1, -10, 0, 5, 0],
        [2, 0, 1, 2, 2, -8, 0, 3, 0],
        [0, 1, 0, 2, 2, 7, 0, -3, 0],
        [-2, 1, 1, 0, 0, -7, 0, 0, 0],
        [0, -1, 0, 2, 2, -7, 0, 3, 0],
        [2, 0, 0, 2, 1, -7, 0, 3, 0],
        [2, 0, 1, 0, 0, 6, 0, 0, 0],
        [-2, 0, 2, 2, 2, 6, 0, -3, 0],
        [-2, 0, 1, 2, 1, 6, 0, -3, 0],
        [2, 0, -2, 0, 1, -6, 0, 3, 0],
        [2, 0, 0, 0, 1, -6, 0, 3, 0],
        [0, -1, 1, 0, 0, 5, 0, 0, 0],
        [-2, -1, 0, 2, 1, -5, 0, 3, 0],
        [-2, 0, 0, 0, 1, -5, 0, 3, 0],
        [0, 0, 2, 2, 1, -5, 0, 3, 0],
        [-2, 0, 2, 0, 1, 4, 0, 0, 0],
        [-2, 1, 0, 2, 1, 4, 0, 0, 0],
        [0, 0, 1, -2, 0, 4, 0, 0, 0],
        [-1, 0, 1, 0, 0, -4, 0, 0, 0],
        [-2, 1, 0, 0, 0, -4, 0, 0, 0],
        [1, 0, 0, 0, 0, -4, 0, 0, 0],
        [0, 0, 1, 2, 0, 3, 0, 0, 0],
        [0, 0, -2, 2, 2, -3, 0, 0, 0],
        [-1, -1, 1, 0, 0, -3, 0, 0, 0],
        [0, 1, 1, 0, 0, -3, 0, 0, 0],
        [0, -1, 1, 2, 2, -3, 0, 0, 0],
        [2, -1, -1, 2, 2, -3, 0, 0, 0],
        [0, 0, 3, 2, 2, 3, 0, 0, 0],
        [2, -1, 0, 2, 2, -3, 0, 0, 0],
    ]
}
