@preconcurrency import AVFoundation
import Foundation

public struct PlaybackBandwidthSample: Equatable, Sendable {
    public let observedThroughputBps: Double?
    public let indicatedMediaBitrateBps: Double?
    public let estimate: BandwidthEstimate?
}

/// Opt-in sampler for an existing AVPlayerItem. Call sample() from the host's
/// access-log observation. Nothing here changes player policy or track selection.
@MainActor
public final class AVPlayerBandwidthMonitor {
    private weak var item: AVPlayerItem?
    private var sampler: AccessLogBandwidthSampler

    public init(configuration: BandwidthEstimatorConfiguration) {
        sampler = AccessLogBandwidthSampler(configuration: configuration)
    }

    public func attach(to item: AVPlayerItem) {
        detach()
        guard let url = (item.asset as? AVURLAsset)?.url,
            let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http"
        else { return }
        self.item = item
        sampler.beginSession(baseline: counters(for: item))
    }

    public func detach() {
        item = nil
        sampler.beginSession(baseline: [])
    }

    /// The explicit item check prevents a delayed callback from sampling a replacement item.
    public func sample(for item: AVPlayerItem) -> [PlaybackBandwidthSample] {
        guard self.item === item else { return [] }
        return sampler.sample(counters(for: item))
    }

    private func counters(for item: AVPlayerItem) -> [AccessLogTransferCounters] {
        item.accessLog()?.events.map {
            AccessLogTransferCounters(
                start: $0.playbackStartDate, bytes: $0.numberOfBytesTransferred, seconds: $0.transferDuration,
                observedBps: $0.observedBitrate, indicatedBps: $0.indicatedBitrate)
        } ?? []
    }
}

struct AccessLogTransferCounters: Equatable {
    let start: Date?
    let bytes: Int64
    let seconds: Double
    let observedBps: Double
    let indicatedBps: Double
}

struct AccessLogBandwidthSampler {
    private var estimator: DualEWMABandwidthEstimator
    private var previous: [AccessLogTransferCounters] = []

    init(configuration: BandwidthEstimatorConfiguration) {
        estimator = DualEWMABandwidthEstimator(configuration: configuration)
    }

    mutating func beginSession(baseline: [AccessLogTransferCounters]) {
        previous = baseline
        estimator.beginSession()
    }

    mutating func sample(_ counters: [AccessLogTransferCounters]) -> [PlaybackBandwidthSample] {
        guard counters.count >= previous.count else {
            previous = counters
            return []
        }

        var output: [PlaybackBandwidthSample] = []
        for (index, current) in counters.enumerated() {
            let old = index < previous.count ? previous[index] : nil
            if current == old { continue }
            var estimate: BandwidthEstimate?
            if current.bytes >= 0, current.seconds.isFinite, current.seconds >= 0 {
                if let old {
                    if old.start == current.start, old.bytes >= 0, old.seconds.isFinite, old.seconds >= 0,
                        old.bytes <= current.bytes, old.seconds <= current.seconds
                    {
                        estimate = record(bytes: current.bytes - old.bytes, seconds: current.seconds - old.seconds)
                    }
                } else {
                    estimate = record(bytes: current.bytes, seconds: current.seconds)
                }
            }
            let observed = rate(current.observedBps)
            let indicated = rate(current.indicatedBps)
            if observed != nil || indicated != nil || estimate != nil {
                output.append(
                    PlaybackBandwidthSample(
                        observedThroughputBps: observed, indicatedMediaBitrateBps: indicated, estimate: estimate))
            }
        }
        previous = counters
        return output
    }

    private mutating func record(bytes: Int64, seconds: Double) -> BandwidthEstimate? {
        let milliseconds = (seconds * 1_000).rounded()
        guard milliseconds > 0, milliseconds < Double(Int64.max) else { return nil }
        return estimator.record(bytes: bytes, durationMs: Int64(milliseconds))
    }

    private func rate(_ value: Double) -> Double? { value.isFinite && value >= 0 ? value : nil }
}

/// Host opt-in to use the custom estimate as an AVPlayer peak bitrate preference.
/// The player still chooses its rendition. This is not a measured switch or a native estimator.
@MainActor
public final class AVPlayerBandwidthPreference {
    private weak var item: AVPlayerItem?
    private var previous: Double = 0
    private var applied: Double?

    public init() {}

    public func apply(_ estimate: BandwidthEstimate, to item: AVPlayerItem) {
        if self.item !== item {
            detach()
            self.item = item
            previous = item.preferredPeakBitRate
        } else if let applied, item.preferredPeakBitRate != applied {
            previous = item.preferredPeakBitRate
        }
        let requested = Double(estimate.drivingBps)
        let limit = previous > 0 ? min(previous, requested) : requested
        item.preferredPeakBitRate = limit
        applied = limit
    }

    public func detach() {
        if let item, let applied, item.preferredPeakBitRate == applied {
            item.preferredPeakBitRate = previous
        }
        item = nil
        applied = nil
    }
}
