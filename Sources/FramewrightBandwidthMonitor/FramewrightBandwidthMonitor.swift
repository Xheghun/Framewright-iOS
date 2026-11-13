import FramewrightAnalytics

public struct BandwidthEstimatorConfiguration: Equatable, Sendable {
    public let fastAlpha: Double
    public let slowAlpha: Double
    public let initialBitrateBps: Int64
    public let minimumSamples: Int
    public let fullConfidenceSamples: Int
    public let representativeBytes: Int64

    public init(
        fastAlpha: Double = 0.5, slowAlpha: Double = 0.1, initialBitrateBps: Int64 = 1_000_000,
        minimumSamples: Int = 3, fullConfidenceSamples: Int = 5, representativeBytes: Int64 = 65_536
    ) throws {
        guard fastAlpha > 0, fastAlpha <= 1, slowAlpha > 0, slowAlpha <= fastAlpha else {
            throw AnalyticsValidationError.invalidField("alpha")
        }
        guard initialBitrateBps > 0, minimumSamples > 0, fullConfidenceSamples >= minimumSamples,
            representativeBytes > 0
        else {
            throw AnalyticsValidationError.invalidField("bandwidthEstimatorConfiguration")
        }
        self.fastAlpha = fastAlpha
        self.slowAlpha = slowAlpha
        self.initialBitrateBps = initialBitrateBps
        self.minimumSamples = minimumSamples
        self.fullConfidenceSamples = fullConfidenceSamples
        self.representativeBytes = representativeBytes
    }
}

public struct BandwidthEstimate: Equatable, Sendable {
    public let instantaneousBps: Int64
    public let fastBps: Int64
    public let slowBps: Int64
    public let drivingBps: Int64
    public let totalSamples: Int
    public let sessionSamples: Int
    public let confidence: Double
}

/// Android Framewright's dual EWMA over caller-supplied, completed network transfers.
public struct DualEWMABandwidthEstimator: Sendable {
    private let configuration: BandwidthEstimatorConfiguration
    private var fast = 0.0
    private var slow = 0.0
    private var totalSamples = 0
    private var sessionSamples = 0
    public private(set) var latest: BandwidthEstimate?

    public init(configuration: BandwidthEstimatorConfiguration) { self.configuration = configuration }

    public var drivingBps: Int64 {
        totalSamples < configuration.minimumSamples
            ? configuration.initialBitrateBps : bitrate(min(fast, slow))
    }

    /// Reset session confidence while preserving the transfer history used by the meter.
    public mutating func beginSession() {
        sessionSamples = 0
        latest = nil
    }

    /// Clear estimates and session confidence when starting a new meter.
    public mutating func reset() {
        fast = 0
        slow = 0
        totalSamples = 0
        beginSession()
    }

    @discardableResult
    public mutating func record(bytes: Int64, durationMs: Int64) -> BandwidthEstimate? {
        guard bytes > 0, durationMs > 0 else { return nil }
        let instantaneous = bitrate(Double(bytes) * 8 * 1_000 / Double(durationMs))
        let sample = Double(instantaneous)
        fast = update(fast, sample, configuration.fastAlpha)
        slow = update(slow, sample, configuration.slowAlpha)
        if totalSamples < Int.max { totalSamples += 1 }
        if sessionSamples < Int.max { sessionSamples += 1 }
        let confidence = min(
            1, Double(sessionSamples) / Double(configuration.fullConfidenceSamples),
            Double(bytes) / Double(configuration.representativeBytes))
        let estimate = BandwidthEstimate(
            instantaneousBps: instantaneous, fastBps: bitrate(fast), slowBps: bitrate(slow),
            drivingBps: drivingBps, totalSamples: totalSamples, sessionSamples: sessionSamples,
            confidence: confidence)
        latest = estimate
        return estimate
    }

    private func update(_ current: Double, _ sample: Double, _ alpha: Double) -> Double {
        current == 0 ? sample : alpha * sample + (1 - alpha) * current
    }

    private func bitrate(_ value: Double) -> Int64 {
        value >= Double(Int64.max) ? Int64.max : max(1, Int64(value))
    }
}
