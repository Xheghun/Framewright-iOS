import Foundation

public struct TrackSwitchPayload: Codable, Equatable, Sendable {
    public let fromFormat: FormatSnapshot?
    public let toFormat: FormatSnapshot
    public let reason: TrackSwitchReason
    public let estimatedBandwidthBps: Int64
    public let bufferedDurationMs: Int64
    public let availableVideoFormats: [FormatSnapshot]

    public init(
        fromFormat: FormatSnapshot? = nil, toFormat: FormatSnapshot, reason: TrackSwitchReason,
        estimatedBandwidthBps: Int64, bufferedDurationMs: Int64, availableVideoFormats: [FormatSnapshot] = []
    ) throws {
        guard estimatedBandwidthBps >= 0 else { throw AnalyticsValidationError.invalidField("estimatedBandwidthBps") }
        guard bufferedDurationMs >= 0 else { throw AnalyticsValidationError.invalidField("bufferedDurationMs") }
        self.fromFormat = fromFormat
        self.toFormat = toFormat
        self.reason = reason
        self.estimatedBandwidthBps = estimatedBandwidthBps
        self.bufferedDurationMs = bufferedDurationMs
        self.availableVideoFormats = availableVideoFormats
    }

    private enum CodingKeys: String, CodingKey {
        case fromFormat
        case toFormat
        case reason
        case estimatedBandwidthBps
        case bufferedDurationMs
        case availableVideoFormats
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            fromFormat: try values.decodeIfPresent(FormatSnapshot.self, forKey: .fromFormat),
            toFormat: try values.decode(FormatSnapshot.self, forKey: .toFormat),
            reason: try values.decode(TrackSwitchReason.self, forKey: .reason),
            estimatedBandwidthBps: try values.decode(Int64.self, forKey: .estimatedBandwidthBps),
            bufferedDurationMs: try values.decode(Int64.self, forKey: .bufferedDurationMs),
            availableVideoFormats: try values.decodeIfPresent([FormatSnapshot].self, forKey: .availableVideoFormats)
                ?? []
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(fromFormat, forKey: .fromFormat)
        try values.encode(toFormat, forKey: .toFormat)
        try values.encode(reason, forKey: .reason)
        try values.encode(estimatedBandwidthBps, forKey: .estimatedBandwidthBps)
        try values.encode(bufferedDurationMs, forKey: .bufferedDurationMs)
        try values.encode(availableVideoFormats, forKey: .availableVideoFormats)
    }
}
