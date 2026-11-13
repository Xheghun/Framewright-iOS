import AVFoundation
import Foundation
import Testing

@testable import FramewrightBandwidthMonitor

@Test func accessLogCounterDeltasDoNotCountDuplicatesOrResetsAsTransfers() throws {
    func entry(
        _ bytes: Int64, _ seconds: Double, start: Double = 1, observed: Double = -1, indicated: Double = -1
    ) -> AccessLogTransferCounters {
        .init(
            start: Date(timeIntervalSince1970: start), bytes: bytes, seconds: seconds,
            observedBps: observed, indicatedBps: indicated)
    }
    var sampler = AccessLogBandwidthSampler(configuration: try BandwidthEstimatorConfiguration())
    sampler.beginSession(baseline: [entry(100_000, 1)])
    #expect(sampler.sample([entry(100_000, 1)]).isEmpty)
    let delta = sampler.sample([entry(250_000, 2, observed: 900_000, indicated: 500_000)])
    #expect(delta.first?.estimate?.instantaneousBps == 1_200_000)
    #expect(delta.first?.observedThroughputBps == 900_000)
    #expect(delta.first?.indicatedMediaBitrateBps == 500_000)
    #expect(sampler.sample([entry(10, 0.1)]).isEmpty)
    #expect(sampler.sample([entry(-1, -1)]).isEmpty)
    #expect(sampler.sample([entry(50_000, 0.5, start: 2)]).isEmpty)
    #expect(sampler.sample([]).isEmpty)
}

@Test @MainActor func samplerRejectsAnOldItemAndDoesNotSampleLocalMedia() throws {
    let monitor = AVPlayerBandwidthMonitor(configuration: try BandwidthEstimatorConfiguration())
    let original = AVPlayerItem(url: try #require(URL(string: "https://example.invalid/old.m3u8")))
    let replacement = AVPlayerItem(url: URL(fileURLWithPath: "/tmp/new-framewright-test.mp4"))
    monitor.attach(to: original)
    monitor.attach(to: replacement)
    #expect(monitor.sample(for: original).isEmpty)
    #expect(monitor.sample(for: replacement).isEmpty)
    monitor.detach()
    #expect(monitor.sample(for: replacement).isEmpty)
}

@Test @MainActor func optionalBitratePreferenceRestoresHostLimitAndPreservesHostOverrides() throws {
    let firstURL = try #require(URL(string: "https://example.invalid/one.m3u8"))
    let nextURL = try #require(URL(string: "https://example.invalid/two.m3u8"))
    let item = AVPlayerItem(url: firstURL)
    let next = AVPlayerItem(url: nextURL)
    item.preferredPeakBitRate = 800_000
    var estimator = DualEWMABandwidthEstimator(configuration: try BandwidthEstimatorConfiguration())
    let sample = estimator.record(bytes: 500_000, durationMs: 1_000)
    let estimate = try #require(sample)
    let policy = AVPlayerBandwidthPreference()
    policy.apply(estimate, to: item)
    #expect(item.preferredPeakBitRate == 800_000)
    item.preferredPeakBitRate = 2_000_000
    policy.apply(estimate, to: item)
    #expect(item.preferredPeakBitRate == 1_000_000)
    policy.apply(estimate, to: next)
    #expect(item.preferredPeakBitRate == 2_000_000)
    #expect(next.preferredPeakBitRate == 1_000_000)
    next.preferredPeakBitRate = 600_000
    policy.detach()
    #expect(next.preferredPeakBitRate == 600_000)
}
