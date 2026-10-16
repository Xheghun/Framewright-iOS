import Foundation

/// Immutable, validated diagnostic data. Durations and timestamps use milliseconds.
public struct DoubleRangeSnapshot: Codable, Equatable, Sendable {
    public let lower: Double
    public let upper: Double

    public init(lower: Double, upper: Double) throws {
        guard lower <= upper else { throw AnalyticsValidationError.invalidField("range") }
        guard lower.isFinite && upper.isFinite else { throw AnalyticsValidationError.invalidField("range") }
        self.lower = lower
        self.upper = upper
    }

    private enum CodingKeys: String, CodingKey {
        case lower
        case upper
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            lower: try values.decode(Double.self, forKey: .lower),
            upper: try values.decode(Double.self, forKey: .upper)
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(lower, forKey: .lower)
        try values.encode(upper, forKey: .upper)
    }
}
