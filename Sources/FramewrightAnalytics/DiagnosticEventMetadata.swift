import Foundation

public struct DiagnosticEventMetadata: Codable, Equatable, Sendable {
    public let sessionId: String
    public let eventId: String
    public let timestampMs: Int64
    public let elapsedRealtimeMs: Int64
    public let playerState: PlayerState?

    public init(
        sessionId: String, eventId: String, timestampMs: Int64, elapsedRealtimeMs: Int64,
        playerState: PlayerState? = nil
    ) throws {
        guard !sessionId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AnalyticsValidationError.invalidField("sessionId")
        }
        guard !eventId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AnalyticsValidationError.invalidField("eventId")
        }
        guard timestampMs >= 0 else { throw AnalyticsValidationError.invalidField("timestampMs") }
        guard elapsedRealtimeMs >= 0 else { throw AnalyticsValidationError.invalidField("elapsedRealtimeMs") }
        self.sessionId = sessionId
        self.eventId = eventId
        self.timestampMs = timestampMs
        self.elapsedRealtimeMs = elapsedRealtimeMs
        self.playerState = playerState
    }

    private enum CodingKeys: String, CodingKey {
        case sessionId
        case eventId
        case timestampMs
        case elapsedRealtimeMs
        case playerState
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            sessionId: try values.decode(String.self, forKey: .sessionId),
            eventId: try values.decode(String.self, forKey: .eventId),
            timestampMs: try values.decode(Int64.self, forKey: .timestampMs),
            elapsedRealtimeMs: try values.decode(Int64.self, forKey: .elapsedRealtimeMs),
            playerState: try values.decodeIfPresent(PlayerState.self, forKey: .playerState)
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(sessionId, forKey: .sessionId)
        try values.encode(eventId, forKey: .eventId)
        try values.encode(timestampMs, forKey: .timestampMs)
        try values.encode(elapsedRealtimeMs, forKey: .elapsedRealtimeMs)
        try values.encode(playerState, forKey: .playerState)
    }
}
