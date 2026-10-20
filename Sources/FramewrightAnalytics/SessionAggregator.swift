import Foundation

/// Truncated histories produce partial summaries.
public struct SessionSnapshot: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let sessionId: String
    public let truncated: Bool
    public let events: [DiagnosticEvent]

    public init(sessionId: String, truncated: Bool = false, events: [DiagnosticEvent] = []) throws {
        guard !sessionId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AnalyticsValidationError.invalidField("sessionId")
        }
        guard events.allSatisfy({ $0.sessionId == sessionId }) else {
            throw AnalyticsValidationError.invalidField("events.sessionId")
        }
        self.schemaVersion = diagnosticSchemaVersion
        self.sessionId = sessionId
        self.truncated = truncated
        self.events = events
    }

    private enum CodingKeys: String, CodingKey { case schemaVersion, sessionId, truncated, events }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let version = try values.decode(Int.self, forKey: .schemaVersion)
        guard version == diagnosticSchemaVersion else { throw CodecError.unsupportedSchemaVersion(version) }
        try self.init(
            sessionId: values.decode(String.self, forKey: .sessionId),
            truncated: values.decode(Bool.self, forKey: .truncated),
            events: values.decode([DiagnosticEvent].self, forKey: .events)
        )
    }
}

/// Value-owned history. Use the pipeline actor when publishing from multiple tasks.
/// Retention is bounded per session; owners must clear sessions they no longer need.
public struct SessionAggregator: Sendable {
    private struct History: Sendable {
        var events: [DiagnosticEvent] = []
        var oldest = 0
        var truncated = false

        var ordered: [DiagnosticEvent] {
            guard oldest != 0 else { return events }
            return Array(events[oldest...]) + Array(events[..<oldest])
        }

        mutating func record(_ event: DiagnosticEvent, capacity: Int) {
            if events.count < capacity {
                events.append(event)
            } else {
                events[oldest] = event
                oldest = (oldest + 1) % capacity
                truncated = true
            }
        }
    }

    public let maxEventsPerSession: Int
    private var sessions: [String: History] = [:]

    public init(maxEventsPerSession: Int = 5_000) throws {
        guard maxEventsPerSession > 0 else { throw AnalyticsValidationError.invalidField("maxEventsPerSession") }
        self.maxEventsPerSession = maxEventsPerSession
    }

    public mutating func record(_ event: DiagnosticEvent) {
        sessions[event.sessionId, default: History()].record(event, capacity: maxEventsPerSession)
    }

    public func snapshot(sessionId: String) throws -> SessionSnapshot {
        let history = sessions[sessionId]
        return try SessionSnapshot(
            sessionId: sessionId, truncated: history?.truncated ?? false, events: history?.ordered ?? []
        )
    }

    public mutating func clear(sessionId: String) { sessions.removeValue(forKey: sessionId) }
}
