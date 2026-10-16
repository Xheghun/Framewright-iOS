import Foundation

public struct DRMExpirationUpdatePayload: Codable, Equatable, Sendable {
    public let expirationTimeMs: Int64

    public init(expirationTimeMs: Int64) throws {
        guard expirationTimeMs >= 0 else { throw AnalyticsValidationError.invalidField("expirationTimeMs") }
        self.expirationTimeMs = expirationTimeMs
    }

    private enum CodingKeys: String, CodingKey {
        case expirationTimeMs
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            expirationTimeMs: try values.decode(Int64.self, forKey: .expirationTimeMs)
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(expirationTimeMs, forKey: .expirationTimeMs)
    }
}
