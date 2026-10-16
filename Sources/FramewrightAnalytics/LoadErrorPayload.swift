import Foundation

/// Immutable, validated diagnostic data. Durations and timestamps use milliseconds.
public struct LoadErrorPayload: Codable, Equatable, Sendable {
    public let uri: String
    public let httpStatus: Int?
    public let errorClass: LoadErrorClass
    public let retryCount: Int
    public let wasCanceled: Bool
    public let errorMessage: String?

    public init(
        uri: String, httpStatus: Int? = nil, errorClass: LoadErrorClass, retryCount: Int, wasCanceled: Bool,
        errorMessage: String? = nil
    ) throws {
        guard retryCount >= 0 else { throw AnalyticsValidationError.invalidField("retryCount") }
        self.uri = uri
        self.httpStatus = httpStatus
        self.errorClass = errorClass
        self.retryCount = retryCount
        self.wasCanceled = wasCanceled
        self.errorMessage = errorMessage
    }

    private enum CodingKeys: String, CodingKey {
        case uri
        case httpStatus
        case errorClass
        case retryCount
        case wasCanceled
        case errorMessage
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            uri: try values.decode(String.self, forKey: .uri),
            httpStatus: try values.decodeIfPresent(Int.self, forKey: .httpStatus),
            errorClass: try values.decode(LoadErrorClass.self, forKey: .errorClass),
            retryCount: try values.decode(Int.self, forKey: .retryCount),
            wasCanceled: try values.decode(Bool.self, forKey: .wasCanceled),
            errorMessage: try values.decodeIfPresent(String.self, forKey: .errorMessage)
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(uri, forKey: .uri)
        try values.encode(httpStatus, forKey: .httpStatus)
        try values.encode(errorClass, forKey: .errorClass)
        try values.encode(retryCount, forKey: .retryCount)
        try values.encode(wasCanceled, forKey: .wasCanceled)
        try values.encode(errorMessage, forKey: .errorMessage)
    }
}
