import Foundation

/// Immutable, validated diagnostic data. Durations and timestamps use milliseconds.
public struct PlaybackErrorPayload: Codable, Equatable, Sendable {
    public let errorCode: String
    public let errorMessage: String?
    public let cause: String?
    public let isFatal: Bool

    public init(errorCode: String, errorMessage: String? = nil, cause: String? = nil, isFatal: Bool = true) throws {
        self.errorCode = errorCode
        self.errorMessage = errorMessage
        self.cause = cause
        self.isFatal = isFatal
    }

    private enum CodingKeys: String, CodingKey {
        case errorCode
        case errorMessage
        case cause
        case isFatal
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            errorCode: try values.decode(String.self, forKey: .errorCode),
            errorMessage: try values.decodeIfPresent(String.self, forKey: .errorMessage),
            cause: try values.decodeIfPresent(String.self, forKey: .cause),
            isFatal: try values.decodeIfPresent(Bool.self, forKey: .isFatal) ?? true
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(errorCode, forKey: .errorCode)
        try values.encode(errorMessage, forKey: .errorMessage)
        try values.encode(cause, forKey: .cause)
        try values.encode(isFatal, forKey: .isFatal)
    }
}
