import Foundation

public struct DecoderInspectionRequest: Codable, Equatable, Sendable {
    public let decoderName: String
    public let mimeType: String
    public let format: FormatSnapshot?

    public init(decoderName: String, mimeType: String, format: FormatSnapshot? = nil) throws {
        guard !decoderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AnalyticsValidationError.invalidField("decoderName")
        }
        guard !mimeType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AnalyticsValidationError.invalidField("mimeType")
        }
        self.decoderName = decoderName
        self.mimeType = mimeType
        self.format = format
    }

    private enum CodingKeys: String, CodingKey {
        case decoderName
        case mimeType
        case format
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            decoderName: try values.decode(String.self, forKey: .decoderName),
            mimeType: try values.decode(String.self, forKey: .mimeType),
            format: try values.decodeIfPresent(FormatSnapshot.self, forKey: .format)
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(decoderName, forKey: .decoderName)
        try values.encode(mimeType, forKey: .mimeType)
        try values.encode(format, forKey: .format)
    }
}
