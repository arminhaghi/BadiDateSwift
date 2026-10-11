import Foundation
@testable import BadiDateSwift

/// The fixtures are generated from badiDate, the JavaScript reference implementation, by
/// `Scripts/generate-fixtures.mjs`.
enum Fixtures {
    static func url(_ name: String) -> URL {
        Bundle.module.url(forResource: "Fixtures/\(name)", withExtension: nil)!
    }

    /// The whitespace-separated fields of each line.
    static func rows(_ name: String) throws -> [[Substring]] {
        try String(contentsOf: url(name), encoding: .utf8)
            .split(separator: "\n")
            .map { $0.split(separator: " ") }
    }
}

extension GregorianDate {
    init(iso: Substring) {
        let parts = iso.split(separator: "-").map { Int($0)! }
        self.init(year: parts[0], month: parts[1], day: parts[2])!
    }
}

/// Collects mismatches so that a broken test reports a handful of examples instead of thousands of failures.
struct Mismatches: CustomStringConvertible {
    private(set) var count = 0
    private var examples: [String] = []
    /// Mismatches per first word of the context, to show where they cluster.
    private var groups: [Substring: Int] = [:]

    var isEmpty: Bool { count == 0 }

    mutating func check<T: Equatable>(_ actual: T, _ expected: T, _ context: @autoclosure () -> String) {
        guard actual != expected else { return }
        count += 1
        let context = context()
        groups[context.prefix { $0 != " " }, default: 0] += 1
        if groups[context.prefix { $0 != " " }]! <= 3, examples.count < 30 {
            examples.append("\(context): got \(actual), expected \(expected)")
        }
    }

    var description: String {
        let summary = groups.sorted { $0.value > $1.value }.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
        return "\(count) mismatches (\(summary)), e.g.\n" + examples.joined(separator: "\n")
    }
}
