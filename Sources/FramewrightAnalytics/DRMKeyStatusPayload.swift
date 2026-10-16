import Foundation

/// Immutable, validated diagnostic data. Durations and timestamps use milliseconds.
public struct DRMKeyStatusPayload: Codable, Equatable, Sendable {
    public let keyId: String
    public let status: DRMKeyState
    public let securityLevel: String
    public let expirationTimeMs: Int64?
    public let hdcpLevel: String?
    public let maxHdcpLevel: String?
    public let hasNewUsableKey: Bool?

    public init(
        keyId: String, status: DRMKeyState, securityLevel: String, expirationTimeMs: Int64? = nil,
        hdcpLevel: String? = nil, maxHdcpLevel: String? = nil, hasNewUsableKey: Bool? = nil
    ) throws {
        guard expirationTimeMs.map({ $0 >= 0 }) ?? true else {
            throw AnalyticsValidationError.invalidField("expirationTimeMs")
        }
        self.keyId = keyId
        self.status = status
        self.securityLevel = securityLevel
        self.expirationTimeMs = expirationTimeMs
        self.hdcpLevel = hdcpLevel
        self.maxHdcpLevel = maxHdcpLevel
        self.hasNewUsableKey = hasNewUsableKey
    }

    private enum CodingKeys: String, CodingKey {
        case keyId
        case status
        case securityLevel
        case expirationTimeMs
        case hdcpLevel
        case maxHdcpLevel
        case hasNewUsableKey
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            keyId: try values.decode(String.self, forKey: .keyId),
            status: try values.decode(DRMKeyState.self, forKey: .status),
            securityLevel: try values.decode(String.self, forKey: .securityLevel),
            expirationTimeMs: try values.decodeIfPresent(Int64.self, forKey: .expirationTimeMs),
            hdcpLevel: try values.decodeIfPresent(String.self, forKey: .hdcpLevel),
            maxHdcpLevel: try values.decodeIfPresent(String.self, forKey: .maxHdcpLevel),
            hasNewUsableKey: try values.decodeIfPresent(Bool.self, forKey: .hasNewUsableKey)
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(keyId, forKey: .keyId)
        try values.encode(status, forKey: .status)
        try values.encode(securityLevel, forKey: .securityLevel)
        try values.encode(expirationTimeMs, forKey: .expirationTimeMs)
        try values.encode(hdcpLevel, forKey: .hdcpLevel)
        try values.encode(maxHdcpLevel, forKey: .maxHdcpLevel)
        try values.encode(hasNewUsableKey, forKey: .hasNewUsableKey)
    }
}
