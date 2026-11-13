import Foundation
import FramewrightBandwidthMonitor
import Testing

@Test func estimatorMatchesPinnedAndroidVectors() throws {
    let url = try #require(Bundle.module.url(forResource: "android-v0.1.1-ewma", withExtension: "csv"))
    let input = try String(contentsOf: url, encoding: .utf8)
    var estimator = DualEWMABandwidthEstimator(configuration: try BandwidthEstimatorConfiguration())
    for row in input.split(whereSeparator: \.isNewline) {
        let fields = row.split(separator: ",")
        try #require(fields.count == 8)
        let bytes = try #require(Int64(fields[0]))
        let ms = try #require(Int64(fields[1]))
        let recorded = estimator.record(bytes: bytes, durationMs: ms)
        let estimate = try #require(recorded)
        #expect(estimate.instantaneousBps == Int64(fields[2]))
        #expect(estimate.fastBps == Int64(fields[3]))
        #expect(estimate.slowBps == Int64(fields[4]))
        #expect(estimate.drivingBps == Int64(fields[5]))
        #expect(estimate.totalSamples == Int(fields[6]))
        let confidence = try #require(Double(fields[7]))
        #expect(abs(estimate.confidence - confidence) < 1e-12)
    }
}

@Test func sessionResetPreservesMeterHistoryButFullResetDoesNot() throws {
    var estimator = DualEWMABandwidthEstimator(configuration: try BandwidthEstimatorConfiguration())
    for _ in 0..<3 { estimator.record(bytes: 500_000, durationMs: 1_000) }
    estimator.beginSession()
    #expect(estimator.latest == nil)
    #expect(estimator.drivingBps == 4_000_000)
    #expect(estimator.record(bytes: 0, durationMs: 1_000) == nil)
    #expect(estimator.record(bytes: 500_000, durationMs: 0) == nil)
    let recorded = estimator.record(bytes: 500_000, durationMs: 1_000)
    let next = try #require(recorded)
    #expect(next.totalSamples == 4)
    #expect(next.sessionSamples == 1)
    #expect(next.confidence == 0.2)
    estimator.reset()
    #expect(estimator.latest == nil)
    #expect(estimator.drivingBps == 1_000_000)
}
