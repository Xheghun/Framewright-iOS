import Foundation

public enum DiagnosticPayload: Equatable, Sendable {
    case playbackStateChanged(PlaybackStateChangedPayload)
    case positionDiscontinuity(PositionDiscontinuityPayload)
    case sessionStart(SessionStartPayload)
    case sessionEnd(SessionEndPayload)
    case renderFirstFrame(RenderFirstFramePayload)
    case rebufferStart(RebufferStartPayload)
    case rebufferEnd(RebufferEndPayload)
    case trackSwitch(TrackSwitchPayload)
    case decoderInit(DecoderInitPayload)
    case droppedFrames(DroppedFramesPayload)
    case loadError(LoadErrorPayload)
    case drmKeyStatus(DRMKeyStatusPayload)
    case drmSessionEvent(DRMSessionEventPayload)
    case drmRequest(DRMRequestPayload)
    case drmExpirationUpdate(DRMExpirationUpdatePayload)
    case bandwidthSample(BandwidthSamplePayload)
    case playbackError(PlaybackErrorPayload)

    public var type: EventType {
        switch self {
        case .playbackStateChanged: .playbackStateChanged
        case .positionDiscontinuity: .positionDiscontinuity
        case .sessionStart: .sessionStart
        case .sessionEnd: .sessionEnd
        case .renderFirstFrame: .renderFirstFrame
        case .rebufferStart: .rebufferStart
        case .rebufferEnd: .rebufferEnd
        case .trackSwitch: .trackSwitch
        case .decoderInit: .decoderInit
        case .droppedFrames: .droppedFrames
        case .loadError: .loadError
        case .drmKeyStatus: .drmKeyStatus
        case .drmSessionEvent: .drmSessionEvent
        case .drmRequest: .drmRequest
        case .drmExpirationUpdate: .drmExpirationUpdate
        case .bandwidthSample: .bandwidthSample
        case .playbackError: .playbackError
        }
    }
}

/// Codable uses a flat metadata envelope with a typed payload.
public struct DiagnosticEvent: Codable, Equatable, Sendable {
    public let metadata: DiagnosticEventMetadata
    public let payload: DiagnosticPayload
    public var type: EventType { payload.type }
    public var sessionId: String { metadata.sessionId }
    public var eventId: String { metadata.eventId }

    public init(metadata: DiagnosticEventMetadata, payload: DiagnosticPayload) {
        self.metadata = metadata
        self.payload = payload
    }

    private enum CodingKeys: String, CodingKey { case type, payload }

    public init(from decoder: any Decoder) throws {
        metadata = try DiagnosticEventMetadata(from: decoder)
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let rawType = try values.decode(String.self, forKey: .type)
        guard let type = EventType(rawValue: rawType) else { throw CodecError.unknownEventType(rawType) }
        switch type {
        case .playbackStateChanged:
            payload = .playbackStateChanged(try values.decode(PlaybackStateChangedPayload.self, forKey: .payload))
        case .positionDiscontinuity:
            payload = .positionDiscontinuity(try values.decode(PositionDiscontinuityPayload.self, forKey: .payload))
        case .sessionStart: payload = .sessionStart(try values.decode(SessionStartPayload.self, forKey: .payload))
        case .sessionEnd: payload = .sessionEnd(try values.decode(SessionEndPayload.self, forKey: .payload))
        case .renderFirstFrame:
            payload = .renderFirstFrame(try values.decode(RenderFirstFramePayload.self, forKey: .payload))
        case .rebufferStart: payload = .rebufferStart(try values.decode(RebufferStartPayload.self, forKey: .payload))
        case .rebufferEnd: payload = .rebufferEnd(try values.decode(RebufferEndPayload.self, forKey: .payload))
        case .trackSwitch: payload = .trackSwitch(try values.decode(TrackSwitchPayload.self, forKey: .payload))
        case .decoderInit: payload = .decoderInit(try values.decode(DecoderInitPayload.self, forKey: .payload))
        case .droppedFrames: payload = .droppedFrames(try values.decode(DroppedFramesPayload.self, forKey: .payload))
        case .loadError: payload = .loadError(try values.decode(LoadErrorPayload.self, forKey: .payload))
        case .drmKeyStatus: payload = .drmKeyStatus(try values.decode(DRMKeyStatusPayload.self, forKey: .payload))
        case .drmSessionEvent:
            payload = .drmSessionEvent(try values.decode(DRMSessionEventPayload.self, forKey: .payload))
        case .drmRequest: payload = .drmRequest(try values.decode(DRMRequestPayload.self, forKey: .payload))
        case .drmExpirationUpdate:
            payload = .drmExpirationUpdate(try values.decode(DRMExpirationUpdatePayload.self, forKey: .payload))
        case .bandwidthSample:
            payload = .bandwidthSample(try values.decode(BandwidthSamplePayload.self, forKey: .payload))
        case .playbackError: payload = .playbackError(try values.decode(PlaybackErrorPayload.self, forKey: .payload))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        try metadata.encode(to: encoder)
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(type, forKey: .type)
        switch payload {
        case .playbackStateChanged(let value): try values.encode(value, forKey: .payload)
        case .positionDiscontinuity(let value): try values.encode(value, forKey: .payload)
        case .sessionStart(let value): try values.encode(value, forKey: .payload)
        case .sessionEnd(let value): try values.encode(value, forKey: .payload)
        case .renderFirstFrame(let value): try values.encode(value, forKey: .payload)
        case .rebufferStart(let value): try values.encode(value, forKey: .payload)
        case .rebufferEnd(let value): try values.encode(value, forKey: .payload)
        case .trackSwitch(let value): try values.encode(value, forKey: .payload)
        case .decoderInit(let value): try values.encode(value, forKey: .payload)
        case .droppedFrames(let value): try values.encode(value, forKey: .payload)
        case .loadError(let value): try values.encode(value, forKey: .payload)
        case .drmKeyStatus(let value): try values.encode(value, forKey: .payload)
        case .drmSessionEvent(let value): try values.encode(value, forKey: .payload)
        case .drmRequest(let value): try values.encode(value, forKey: .payload)
        case .drmExpirationUpdate(let value): try values.encode(value, forKey: .payload)
        case .bandwidthSample(let value): try values.encode(value, forKey: .payload)
        case .playbackError(let value): try values.encode(value, forKey: .payload)
        }
    }
}
