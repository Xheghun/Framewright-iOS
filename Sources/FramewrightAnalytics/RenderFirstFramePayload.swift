import Foundation

public struct RenderFirstFramePayload: Codable, Equatable, Sendable {
    public let elapsedSincePrepareMs: Int64

    public init(elapsedSincePrepareMs: Int64) throws {
        guard elapsedSincePrepareMs >= 0 else { throw AnalyticsValidationError.invalidField("elapsedSincePrepareMs") }
        self.elapsedSincePrepareMs = elapsedSincePrepareMs
    }

    private enum CodingKeys: String, CodingKey {
        case elapsedSincePrepareMs
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            elapsedSincePrepareMs: try values.decode(Int64.self, forKey: .elapsedSincePrepareMs)
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(elapsedSincePrepareMs, forKey: .elapsedSincePrepareMs)
    }
}
