import Foundation

/// Immutable, validated diagnostic data. Durations and timestamps use milliseconds.
public struct RebufferStartPayload: Codable, Equatable, Sendable {
    public let bufferedMsAtStart: Int64

    public init(bufferedMsAtStart: Int64) throws {
        guard bufferedMsAtStart >= 0 else { throw AnalyticsValidationError.invalidField("bufferedMsAtStart") }
        self.bufferedMsAtStart = bufferedMsAtStart
    }

    private enum CodingKeys: String, CodingKey {
        case bufferedMsAtStart
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            bufferedMsAtStart: try values.decode(Int64.self, forKey: .bufferedMsAtStart)
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(bufferedMsAtStart, forKey: .bufferedMsAtStart)
    }
}
