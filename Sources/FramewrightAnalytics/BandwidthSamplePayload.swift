import Foundation

/// Immutable, validated diagnostic data. Durations and timestamps use milliseconds.
public struct BandwidthSamplePayload: Codable, Equatable, Sendable {
    public let segmentSizeBytes: Int64
    public let downloadDurationMs: Int64
    public let instantaneousBps: Int64
    public let fastEstimateBps: Int64
    public let slowEstimateBps: Int64
    public let defaultEstimateBps: Int64
    public let confidence: Double

    public init(
        segmentSizeBytes: Int64, downloadDurationMs: Int64, instantaneousBps: Int64, fastEstimateBps: Int64,
        slowEstimateBps: Int64, defaultEstimateBps: Int64, confidence: Double
    ) throws {
        guard segmentSizeBytes >= 0 else { throw AnalyticsValidationError.invalidField("segmentSizeBytes") }
        guard downloadDurationMs >= 0 else { throw AnalyticsValidationError.invalidField("downloadDurationMs") }
        guard instantaneousBps >= 0 else { throw AnalyticsValidationError.invalidField("instantaneousBps") }
        guard fastEstimateBps >= 0 else { throw AnalyticsValidationError.invalidField("fastEstimateBps") }
        guard slowEstimateBps >= 0 else { throw AnalyticsValidationError.invalidField("slowEstimateBps") }
        guard defaultEstimateBps >= 0 else { throw AnalyticsValidationError.invalidField("defaultEstimateBps") }
        guard confidence.isFinite && (0...1).contains(confidence) else {
            throw AnalyticsValidationError.invalidField("confidence")
        }
        self.segmentSizeBytes = segmentSizeBytes
        self.downloadDurationMs = downloadDurationMs
        self.instantaneousBps = instantaneousBps
        self.fastEstimateBps = fastEstimateBps
        self.slowEstimateBps = slowEstimateBps
        self.defaultEstimateBps = defaultEstimateBps
        self.confidence = confidence
    }

    private enum CodingKeys: String, CodingKey {
        case segmentSizeBytes
        case downloadDurationMs
        case instantaneousBps
        case fastEstimateBps
        case slowEstimateBps
        case defaultEstimateBps
        case confidence
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            segmentSizeBytes: try values.decode(Int64.self, forKey: .segmentSizeBytes),
            downloadDurationMs: try values.decode(Int64.self, forKey: .downloadDurationMs),
            instantaneousBps: try values.decode(Int64.self, forKey: .instantaneousBps),
            fastEstimateBps: try values.decode(Int64.self, forKey: .fastEstimateBps),
            slowEstimateBps: try values.decode(Int64.self, forKey: .slowEstimateBps),
            defaultEstimateBps: try values.decode(Int64.self, forKey: .defaultEstimateBps),
            confidence: try values.decode(Double.self, forKey: .confidence)
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(segmentSizeBytes, forKey: .segmentSizeBytes)
        try values.encode(downloadDurationMs, forKey: .downloadDurationMs)
        try values.encode(instantaneousBps, forKey: .instantaneousBps)
        try values.encode(fastEstimateBps, forKey: .fastEstimateBps)
        try values.encode(slowEstimateBps, forKey: .slowEstimateBps)
        try values.encode(defaultEstimateBps, forKey: .defaultEstimateBps)
        try values.encode(confidence, forKey: .confidence)
    }
}
