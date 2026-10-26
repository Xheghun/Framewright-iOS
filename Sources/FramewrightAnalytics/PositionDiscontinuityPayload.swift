import Foundation

/// An observed timeline jump; its cause may be a seek or a stream discontinuity.
public struct PositionDiscontinuityPayload: Codable, Equatable, Sendable {
    public let positionMs: Int64

    public init(positionMs: Int64) throws {
        guard positionMs >= 0 else { throw AnalyticsValidationError.invalidField("positionMs") }
        self.positionMs = positionMs
    }

    private enum CodingKeys: String, CodingKey { case positionMs }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(positionMs: values.decode(Int64.self, forKey: .positionMs))
    }
}
