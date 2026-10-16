import Foundation

/// Immutable, validated diagnostic data. Durations and timestamps use milliseconds.
public struct RebufferEndPayload: Codable, Equatable, Sendable {
    public let durationMs: Int64

    public init(durationMs: Int64) throws {
        guard durationMs >= 0 else { throw AnalyticsValidationError.invalidField("durationMs") }
        self.durationMs = durationMs
    }

    private enum CodingKeys: String, CodingKey {
        case durationMs
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            durationMs: try values.decode(Int64.self, forKey: .durationMs)
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(durationMs, forKey: .durationMs)
    }
}
