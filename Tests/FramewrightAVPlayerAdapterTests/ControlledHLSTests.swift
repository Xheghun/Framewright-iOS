@preconcurrency import AVFoundation
import Foundation
import FramewrightAnalytics
import Testing

@testable import FramewrightAVPlayerAdapter

@Test(
    .enabled(if: ProcessInfo.processInfo.environment["FRAMEWRIGHT_HLS_TEST_URL"] != nil),
    .timeLimit(.minutes(1))
) @MainActor func controlledHLSPlaybackAndInvalidMedia() async throws {
    let address = try #require(ProcessInfo.processInfo.environment["FRAMEWRIGHT_HLS_TEST_URL"])
    let base = try #require(URL(string: address))
    let pipeline = try DiagnosticEventPipeline()
    let player = AVPlayer()
    player.isMuted = true
    let source = try FramewrightAVPlayer.attach(player: player, pipeline: pipeline, sessionId: "hls")
    defer {
        player.pause()
        source.detach()
    }
    let item = AVPlayerItem(url: base.appendingPathComponent("master.m3u8"))
    try source.recordPreparationStarted(for: item)
    player.replaceCurrentItem(with: item)
    player.play()
    let deadline = ContinuousClock.now.advanced(by: .seconds(15))
    while !(player.currentTime().seconds >= 2), ContinuousClock.now < deadline {
        try await Task.sleep(for: .milliseconds(50))
    }
    try #require(player.currentTime().seconds >= 2)
    await source.flush()
    let snapshot = try await pipeline.snapshot(sessionId: "hls")
    #expect(snapshot.events.first?.type == .sessionStart)
    #expect(!snapshot.events.contains { $0.type == .playbackError })

    let invalid = AVPlayerItem(url: base.appendingPathComponent("invalid.mp4"))
    player.replaceCurrentItem(with: invalid)
    let failedID = try #require(source.activeSessionID)
    player.play()
    let failureDeadline = ContinuousClock.now.advanced(by: .seconds(15))
    while source.activeSessionID != nil, ContinuousClock.now < failureDeadline {
        try await Task.sleep(for: .milliseconds(50))
    }
    try #require(source.activeSessionID == nil)
    await source.flush()
    let failure = try await pipeline.snapshot(sessionId: failedID)
    #expect(failure.events.contains { $0.type == .playbackError })
    #expect(failure.events.last?.type == .sessionEnd)
    print("Framewright controlled HLS verified: playback advanced and invalid media ended with playbackError")
}
