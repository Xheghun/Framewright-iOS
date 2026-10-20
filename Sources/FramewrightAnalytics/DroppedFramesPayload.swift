import Foundation

public struct DroppedFramesPayload: Codable, Equatable, Sendable {
    public let count: Int
    public let elapsedMs: Int64

    public init(count: Int, elapsedMs: Int64) throws {
        guard count >= 0 else { throw AnalyticsValidationError.invalidField("count") }
        guard elapsedMs >= 0 else { throw AnalyticsValidationError.invalidField("elapsedMs") }
        try validateSchemaInteger(count, field: "count")
        self.count = count
        self.elapsedMs = elapsedMs
    }

    private enum CodingKeys: String, CodingKey {
        case count
        case elapsedMs
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            count: try values.decode(Int.self, forKey: .count),
            elapsedMs: try values.decode(Int64.self, forKey: .elapsedMs)
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(count, forKey: .count)
        try values.encode(elapsedMs, forKey: .elapsedMs)
    }
}
