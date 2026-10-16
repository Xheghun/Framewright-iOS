import Foundation

/// Immutable, validated diagnostic data. Durations and timestamps use milliseconds.
public struct FormatSnapshot: Codable, Equatable, Sendable {
    public let width: Int?
    public let height: Int?
    public let bitrate: Int
    public let mimeType: String?
    public let codecs: String?

    public init(width: Int? = nil, height: Int? = nil, bitrate: Int, mimeType: String? = nil, codecs: String? = nil)
        throws
    {
        guard width.map({ $0 >= 0 }) ?? true else { throw AnalyticsValidationError.invalidField("width") }
        guard height.map({ $0 >= 0 }) ?? true else { throw AnalyticsValidationError.invalidField("height") }
        guard bitrate >= 0 else { throw AnalyticsValidationError.invalidField("bitrate") }
        guard mimeType.map({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) ?? true else {
            throw AnalyticsValidationError.invalidField("mimeType")
        }
        self.width = width
        self.height = height
        self.bitrate = bitrate
        self.mimeType = mimeType
        self.codecs = codecs
    }

    private enum CodingKeys: String, CodingKey {
        case width
        case height
        case bitrate
        case mimeType
        case codecs
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            width: try values.decodeIfPresent(Int.self, forKey: .width),
            height: try values.decodeIfPresent(Int.self, forKey: .height),
            bitrate: try values.decode(Int.self, forKey: .bitrate),
            mimeType: try values.decodeIfPresent(String.self, forKey: .mimeType),
            codecs: try values.decodeIfPresent(String.self, forKey: .codecs)
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(width, forKey: .width)
        try values.encode(height, forKey: .height)
        try values.encode(bitrate, forKey: .bitrate)
        try values.encode(mimeType, forKey: .mimeType)
        try values.encode(codecs, forKey: .codecs)
    }
}
