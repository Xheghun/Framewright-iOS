import Foundation

public enum FirstFrameSource: String, Codable, Sendable {
    case rendered = "RENDERED"
    case readyForDisplay = "READY_FOR_DISPLAY"
}

public struct RenderFirstFramePayload: Codable, Equatable, Sendable {
    public let source: FirstFrameSource
    public let elapsedSincePrepareMs: Int64

    public init(elapsedSincePrepareMs: Int64, source: FirstFrameSource = .rendered) throws {
        guard elapsedSincePrepareMs >= 0 else { throw AnalyticsValidationError.invalidField("elapsedSincePrepareMs") }
        self.source = source
        self.elapsedSincePrepareMs = elapsedSincePrepareMs
    }

    private enum CodingKeys: String, CodingKey {
        case source
        case elapsedSincePrepareMs
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            elapsedSincePrepareMs: try values.decode(Int64.self, forKey: .elapsedSincePrepareMs),
            source: try values.decodeIfPresent(FirstFrameSource.self, forKey: .source) ?? .rendered
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        if source != .rendered { try values.encode(source, forKey: .source) }
        try values.encode(elapsedSincePrepareMs, forKey: .elapsedSincePrepareMs)
    }
}
