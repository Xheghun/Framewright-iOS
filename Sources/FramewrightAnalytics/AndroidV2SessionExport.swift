import Foundation

/// A legacy export and an explicit inventory of information omitted from its JSON.
public struct AndroidV2SessionExport: Equatable, Sendable {
    public enum Omission: Equatable, Sendable {
        case unsupportedEvent(eventID: String, type: EventType)
        case displayReadiness(eventID: String)
        case deviceName(eventID: String)
        case deliveryCompleteness
    }

    public let json: String
    public let omissions: [Omission]
}

extension DiagnosticEventJSONCodec {
    /// Exports a session for Framewright Android v0.1.1. Use the native v3 export
    /// for lossless interchange; callers should surface the returned omissions.
    public func exportAndroidV2(_ snapshot: SessionSnapshot) throws -> AndroidV2SessionExport {
        var omissions: [AndroidV2SessionExport.Omission] = []
        if snapshot.deliveryIncomplete != nil { omissions.append(.deliveryCompleteness) }
        var events: [DiagnosticEvent] = []
        for event in snapshot.events {
            switch event.payload {
            case .playbackStateChanged, .positionDiscontinuity:
                omissions.append(.unsupportedEvent(eventID: event.eventId, type: event.type))
            case .renderFirstFrame(let frame) where frame.source == .readyForDisplay:
                omissions.append(.displayReadiness(eventID: event.eventId))
            case .sessionStart(let start) where start.deviceName != nil:
                omissions.append(.deviceName(eventID: event.eventId))
                let legacy = try SessionStartPayload(
                    mediaUri: start.mediaUri, drmScheme: start.drmScheme, deviceModel: start.deviceModel,
                    osVersion: start.osVersion, appVersion: start.appVersion)
                events.append(DiagnosticEvent(metadata: event.metadata, payload: .sessionStart(legacy)))
            default:
                events.append(event)
            }
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
        let envelope = AndroidV2Envelope(sessionId: snapshot.sessionId, truncated: snapshot.truncated, events: events)
        let json = String(decoding: try encoder.encode(envelope), as: UTF8.self)
        return AndroidV2SessionExport(json: json, omissions: omissions)
    }
}

private struct AndroidV2Envelope: Encodable {
    let schemaVersion = 2
    let sessionId: String
    let truncated: Bool
    let events: [DiagnosticEvent]
}
