import Foundation

public struct IntRangeSnapshot: Codable, Equatable, Sendable {
    public let lower: Int
    public let upper: Int

    public init(lower: Int, upper: Int) throws {
        guard lower <= upper else { throw AnalyticsValidationError.invalidField("range") }
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
            lower: try values.decode(Int.self, forKey: .lower),
            upper: try values.decode(Int.self, forKey: .upper)
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(lower, forKey: .lower)
        try values.encode(upper, forKey: .upper)
    }
}
