/// A high-latitude region where the Bahá’í community goes by fixed clock times instead of the actual sunset.
///
/// A location matching a region doesn't just mean it lies in that country, but that it lies in the part of the
/// country where the fixed time rule applies.
public enum ClockLocation: String, CaseIterable, Sendable, Codable {
    case canada = "Canada"
    case finland = "Finland"
    case iceland = "Iceland"
    case norway = "Norway"
    case sweden = "Sweden"
    case usa = "USA"

    /// The region containing the coordinates, if any.
    public init?(latitude: Double, longitude: Double) {
        // First exclude as large an area as possible from having to check polygons
        if latitude < 51.0 {
            return nil
        }
        if latitude < 57.0, longitude > -129.0, longitude < 172.0 {
            return nil
        }
        // Make a list of plausible areas based on longitude, then only check those
        var candidates: [(ClockLocation, [[Double]])] = []
        if longitude < -129.9 || longitude > 172.4 {
            candidates.append((.usa, ClockLocationPolygons.usa))
        }
        if longitude > -141.1, longitude < -61.1 {
            candidates.append((.canada, ClockLocationPolygons.canada))
        }
        if longitude > -25.0, longitude < -12.8 {
            candidates.append((.iceland, ClockLocationPolygons.iceland))
        }
        if longitude > -9.2, longitude < 33.6 {
            candidates.append((.norway, ClockLocationPolygons.norway))
        }
        if longitude > 10.9, longitude < 24.2 {
            candidates.append((.sweden, ClockLocationPolygons.sweden))
        }
        if longitude > 19.1, longitude < 31.6 {
            candidates.append((.finland, ClockLocationPolygons.finland))
        }
        for (location, polygons) in candidates {
            if polygons.contains(where: { ClockLocation.polygon($0, containsX: longitude, y: latitude) }) {
                self = location
                return
            }
        }
        return nil
    }

    /// `polygon` is a flat list of x, y pairs.
    private static func polygon(_ polygon: [Double], containsX x: Double, y: Double) -> Bool {
        let count = polygon.count / 2
        var inside = false
        var j = count - 1
        for i in 0..<count {
            let (xi, yi) = (polygon[2 * i], polygon[2 * i + 1])
            let (xj, yj) = (polygon[2 * j], polygon[2 * j + 1])
            // Check that a) the segment crosses the y coordinate of the point
            //            b) at least one of the two vertices is left of the point
            //            c) at the y coordinate of the point, the segment is left of it
            if (yi < y) != (yj < y), xi <= x || xj <= x, xi + ((y - yi) * (xj - xi)) / (yj - yi) < x {
                inside.toggle()
            }
            j = i
        }
        return inside
    }
}
