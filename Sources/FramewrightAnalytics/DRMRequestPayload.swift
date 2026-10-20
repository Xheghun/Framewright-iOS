import Foundation

public struct DRMRequestPayload: Codable, Equatable, Sendable {
    public let requestKind: DRMRequestKind
    public let licenseRequestType: DRMLicenseRequestType?
    public let attemptNumber: Int
    public let durationMs: Int64
    public let successful: Bool
    public let errorCode: String?
    public let errorMessage: String?

    public init(
        requestKind: DRMRequestKind, licenseRequestType: DRMLicenseRequestType? = nil, attemptNumber: Int,
        durationMs: Int64, successful: Bool, errorCode: String? = nil, errorMessage: String? = nil
    ) throws {
        guard attemptNumber > 0 else { throw AnalyticsValidationError.invalidField("attemptNumber") }
        guard durationMs >= 0 else { throw AnalyticsValidationError.invalidField("durationMs") }
        try validateSchemaInteger(attemptNumber, field: "attemptNumber")
        self.requestKind = requestKind
        self.licenseRequestType = licenseRequestType
        self.attemptNumber = attemptNumber
        self.durationMs = durationMs
        self.successful = successful
        self.errorCode = errorCode
        self.errorMessage = errorMessage
    }

    private enum CodingKeys: String, CodingKey {
        case requestKind
        case licenseRequestType
        case attemptNumber
        case durationMs
        case successful
        case errorCode
        case errorMessage
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            requestKind: try values.decode(DRMRequestKind.self, forKey: .requestKind),
            licenseRequestType: try values.decodeIfPresent(DRMLicenseRequestType.self, forKey: .licenseRequestType),
            attemptNumber: try values.decode(Int.self, forKey: .attemptNumber),
            durationMs: try values.decode(Int64.self, forKey: .durationMs),
            successful: try values.decode(Bool.self, forKey: .successful),
            errorCode: try values.decodeIfPresent(String.self, forKey: .errorCode),
            errorMessage: try values.decodeIfPresent(String.self, forKey: .errorMessage)
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(requestKind, forKey: .requestKind)
        try values.encode(licenseRequestType, forKey: .licenseRequestType)
        try values.encode(attemptNumber, forKey: .attemptNumber)
        try values.encode(durationMs, forKey: .durationMs)
        try values.encode(successful, forKey: .successful)
        try values.encode(errorCode, forKey: .errorCode)
        try values.encode(errorMessage, forKey: .errorMessage)
    }
}
