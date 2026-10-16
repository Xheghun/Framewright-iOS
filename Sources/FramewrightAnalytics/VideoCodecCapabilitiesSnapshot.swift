import Foundation

/// Immutable, validated diagnostic data. Durations and timestamps use milliseconds.
public struct VideoCodecCapabilitiesSnapshot: Codable, Equatable, Sendable {
    public let supportedWidths: IntRangeSnapshot
    public let supportedHeights: IntRangeSnapshot
    public let supportedBitratesBps: IntRangeSnapshot
    public let supportedFrameRates: DoubleRangeSnapshot
    public let widthAlignment: Int
    public let heightAlignment: Int

    public init(
        supportedWidths: IntRangeSnapshot, supportedHeights: IntRangeSnapshot, supportedBitratesBps: IntRangeSnapshot,
        supportedFrameRates: DoubleRangeSnapshot, widthAlignment: Int, heightAlignment: Int
    ) throws {
        guard widthAlignment > 0 else { throw AnalyticsValidationError.invalidField("widthAlignment") }
        guard heightAlignment > 0 else { throw AnalyticsValidationError.invalidField("heightAlignment") }
        self.supportedWidths = supportedWidths
        self.supportedHeights = supportedHeights
        self.supportedBitratesBps = supportedBitratesBps
        self.supportedFrameRates = supportedFrameRates
        self.widthAlignment = widthAlignment
        self.heightAlignment = heightAlignment
    }

    private enum CodingKeys: String, CodingKey {
        case supportedWidths
        case supportedHeights
        case supportedBitratesBps
        case supportedFrameRates
        case widthAlignment
        case heightAlignment
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            supportedWidths: try values.decode(IntRangeSnapshot.self, forKey: .supportedWidths),
            supportedHeights: try values.decode(IntRangeSnapshot.self, forKey: .supportedHeights),
            supportedBitratesBps: try values.decode(IntRangeSnapshot.self, forKey: .supportedBitratesBps),
            supportedFrameRates: try values.decode(DoubleRangeSnapshot.self, forKey: .supportedFrameRates),
            widthAlignment: try values.decode(Int.self, forKey: .widthAlignment),
            heightAlignment: try values.decode(Int.self, forKey: .heightAlignment)
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(supportedWidths, forKey: .supportedWidths)
        try values.encode(supportedHeights, forKey: .supportedHeights)
        try values.encode(supportedBitratesBps, forKey: .supportedBitratesBps)
        try values.encode(supportedFrameRates, forKey: .supportedFrameRates)
        try values.encode(widthAlignment, forKey: .widthAlignment)
        try values.encode(heightAlignment, forKey: .heightAlignment)
    }
}
