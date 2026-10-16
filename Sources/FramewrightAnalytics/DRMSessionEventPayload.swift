import Foundation

public struct DRMSessionEventPayload: Codable, Equatable, Sendable {
    public let eventType: DRMSessionEventType
    public let state: DRMSessionState?
    public let errorCode: String?
    public let errorMessage: String?

    public init(
        eventType: DRMSessionEventType, state: DRMSessionState? = nil, errorCode: String? = nil,
        errorMessage: String? = nil
    ) throws {
        self.eventType = eventType
        self.state = state
        self.errorCode = errorCode
        self.errorMessage = errorMessage
    }

    private enum CodingKeys: String, CodingKey {
        case eventType
        case state
        case errorCode
        case errorMessage
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            eventType: try values.decode(DRMSessionEventType.self, forKey: .eventType),
            state: try values.decodeIfPresent(DRMSessionState.self, forKey: .state),
            errorCode: try values.decodeIfPresent(String.self, forKey: .errorCode),
            errorMessage: try values.decodeIfPresent(String.self, forKey: .errorMessage)
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(eventType, forKey: .eventType)
        try values.encode(state, forKey: .state)
        try values.encode(errorCode, forKey: .errorCode)
        try values.encode(errorMessage, forKey: .errorMessage)
    }
}
