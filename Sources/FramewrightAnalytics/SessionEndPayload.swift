import Foundation

public struct SessionEndPayload: Codable, Equatable, Sendable {
    public let durationMs: Int64
    public let reason: SessionEndReason

    public init(durationMs: Int64, reason: SessionEndReason) throws {
        guard durationMs >= 0 else { throw AnalyticsValidationError.invalidField("durationMs") }
        self.durationMs = durationMs
        self.reason = reason
    }

    private enum CodingKeys: String, CodingKey {
        case durationMs
        case reason
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            durationMs: try values.decode(Int64.self, forKey: .durationMs),
            reason: try values.decode(SessionEndReason.self, forKey: .reason)
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(durationMs, forKey: .durationMs)
        try values.encode(reason, forKey: .reason)
    }
}
