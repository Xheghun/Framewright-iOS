import Foundation

public struct DecoderInitPayload: Codable, Equatable, Sendable {
    public let decoderName: String
    public let mimeType: String
    public let trackType: TrackType
    public let initializationDurationMs: Int64
    public let isHardwareAccelerated: Bool?
    public let capabilities: DecoderCapabilitySnapshot?

    public init(
        decoderName: String, mimeType: String, trackType: TrackType, initializationDurationMs: Int64,
        isHardwareAccelerated: Bool? = nil, capabilities: DecoderCapabilitySnapshot? = nil
    ) throws {
        guard !decoderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AnalyticsValidationError.invalidField("decoderName")
        }
        guard !mimeType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AnalyticsValidationError.invalidField("mimeType")
        }
        guard initializationDurationMs >= 0 else {
            throw AnalyticsValidationError.invalidField("initializationDurationMs")
        }
        self.decoderName = decoderName
        self.mimeType = mimeType
        self.trackType = trackType
        self.initializationDurationMs = initializationDurationMs
        self.isHardwareAccelerated = isHardwareAccelerated
        self.capabilities = capabilities
    }

    private enum CodingKeys: String, CodingKey {
        case decoderName
        case mimeType
        case trackType
        case initializationDurationMs
        case isHardwareAccelerated
        case capabilities
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            decoderName: try values.decode(String.self, forKey: .decoderName),
            mimeType: try values.decode(String.self, forKey: .mimeType),
            trackType: try values.decode(TrackType.self, forKey: .trackType),
            initializationDurationMs: try values.decode(Int64.self, forKey: .initializationDurationMs),
            isHardwareAccelerated: try values.decodeIfPresent(Bool.self, forKey: .isHardwareAccelerated),
            capabilities: try values.decodeIfPresent(DecoderCapabilitySnapshot.self, forKey: .capabilities)
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(decoderName, forKey: .decoderName)
        try values.encode(mimeType, forKey: .mimeType)
        try values.encode(trackType, forKey: .trackType)
        try values.encode(initializationDurationMs, forKey: .initializationDurationMs)
        try values.encode(isHardwareAccelerated, forKey: .isHardwareAccelerated)
        try values.encode(capabilities, forKey: .capabilities)
    }
}
