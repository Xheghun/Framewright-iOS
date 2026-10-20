@preconcurrency import AVFoundation
import Foundation
import FramewrightAnalytics
import Testing

@testable import FramewrightAVPlayerAdapter

@MainActor
private func waitUntil(_ condition: () async throws -> Bool) async throws {
    let deadline = ContinuousClock.now.advanced(by: .seconds(30))
    while try await !condition() {
        guard ContinuousClock.now < deadline else { throw TestFailure.timeout }
        try await Task.sleep(for: .milliseconds(20))
    }
}

private enum TestFailure: Error { case timeout }

private func audioFixture() throws -> URL {
    let sampleCount: UInt32 = 4_000
    let size = sampleCount * 2
    var data = Data()
    func text(_ value: String) { data.append(contentsOf: value.utf8) }
    func integer<T: FixedWidthInteger>(_ value: T) {
        var littleEndian = value.littleEndian
        withUnsafeBytes(of: &littleEndian) { data.append(contentsOf: $0) }
    }
    text("RIFF")
    integer(UInt32(36) + size)
    text("WAVEfmt ")
    integer(UInt32(16))
    integer(UInt16(1))
    integer(UInt16(1))
    integer(UInt32(8_000))
    integer(UInt32(16_000))
    integer(UInt16(2))
    integer(UInt16(16))
    text("data")
    integer(size)
    data.append(Data(repeating: 0, count: Int(size)))
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension(
        "wav")
    try data.write(to: url)
    return url
}

@Test @MainActor func invalidAttachCanBeRetriedAndDuplicateAttachIsRejected() async throws {
    let player = AVPlayer()
    let pipeline = try DiagnosticEventPipeline()
    let source = FramewrightAVPlayer(player: player)
    #expect(throws: AVPlayerDiagnosticsError.invalidSessionID) { try source.attach(pipeline: pipeline, sessionId: " ") }
    #expect(!source.isAttached)
    try source.attach(pipeline: pipeline, sessionId: "session")
    #expect(throws: AVPlayerDiagnosticsError.alreadyAttached) {
        try source.attach(pipeline: pipeline, sessionId: "second")
    }
    #expect(source.activeSessionID == nil)
    source.detach()
    source.detach()
    await source.flush()
    #expect(try await pipeline.snapshot(sessionId: "session").events.isEmpty)
}

@Test(.timeLimit(.minutes(1))) @MainActor func replacementRemovalAndReattachmentPreserveEventOrder() async throws {
    let url = try audioFixture()
    defer { try? FileManager.default.removeItem(at: url) }
    let first = AVPlayerItem(url: url)
    let second = AVPlayerItem(url: url)
    let player = AVPlayer(playerItem: first)
    let pipeline = try DiagnosticEventPipeline()
    let subscription = await pipeline.subscribe()
    let source = try FramewrightAVPlayer.attach(player: player, pipeline: pipeline, sessionId: "first")
    player.replaceCurrentItem(with: second)
    let secondID = try #require(source.activeSessionID)
    #expect(secondID != "first")
    NotificationCenter.default.post(name: AVPlayerItem.didPlayToEndTimeNotification, object: first)
    #expect(source.activeSessionID == secondID)
    player.replaceCurrentItem(with: nil)
    #expect(source.activeSessionID == nil)
    source.detach()
    try source.attach(pipeline: pipeline, sessionId: "third")
    player.replaceCurrentItem(with: first)
    source.detach()
    await source.flush()
    await pipeline.unsubscribe(subscription.id)
    var events: [DiagnosticEvent] = []
    for await event in subscription.events { events.append(event) }
    #expect(events.map(\.type) == [.sessionStart, .sessionEnd, .sessionStart, .sessionEnd, .sessionStart, .sessionEnd])
    #expect(events.map(\.sessionId) == ["first", "first", secondID, secondID, "third", "third"])
    #expect(player.currentItem === first)
}

@Test(.timeLimit(.minutes(1))) @MainActor func realPlaybackEndsWithoutInventingFirstFrame() async throws {
    let url = try audioFixture()
    defer { try? FileManager.default.removeItem(at: url) }
    let player = AVPlayer(url: url)
    player.isMuted = true
    let pipeline = try DiagnosticEventPipeline()
    let source = try FramewrightAVPlayer.attach(player: player, pipeline: pipeline, sessionId: "playback")
    player.play()
    try await waitUntil { source.activeSessionID == nil }
    await source.flush()
    let events = try await pipeline.snapshot(sessionId: "playback").events
    #expect(events.first?.type == .sessionStart)
    guard case .sessionEnd(let end) = events.last?.payload else {
        Issue.record("Missing session end")
        return
    }
    #expect(end.reason == .playbackEnded)
    #expect(!events.contains { $0.type == .renderFirstFrame || $0.type == .playbackError })
    source.detach()
}

@Test(.timeLimit(.minutes(1))) @MainActor func realItemFailureIsRecordedOnce() async throws {
    let missing = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("wav")
    let player = AVPlayer(url: missing)
    let pipeline = try DiagnosticEventPipeline()
    let source = try FramewrightAVPlayer.attach(player: player, pipeline: pipeline, sessionId: "failure")
    player.play()
    try await waitUntil { source.activeSessionID == nil }
    await source.flush()
    let events = try await pipeline.snapshot(sessionId: "failure").events
    #expect(events.map(\.type) == [.sessionStart, .playbackError, .sessionEnd])
    guard case .playbackError(let error) = events[1].payload else {
        Issue.record("Missing playback error")
        return
    }
    #expect(error.errorMessage == nil)
    #expect(error.isFatal)
    source.detach()
}

@Test(.timeLimit(.minutes(1))) @MainActor func detachLeavesHostPlaybackRunning() async throws {
    let url = try audioFixture()
    defer { try? FileManager.default.removeItem(at: url) }
    let player = AVPlayer(url: url)
    player.isMuted = true
    let pipeline = try DiagnosticEventPipeline()
    let source = try FramewrightAVPlayer.attach(player: player, pipeline: pipeline, sessionId: "detach")
    player.play()
    try await waitUntil { player.timeControlStatus == .playing }
    source.detach()
    let position = player.currentTime().seconds
    await source.flush()
    try await waitUntil { player.currentTime().seconds > position }
    #expect(player.currentItem != nil)
    #expect(player.isMuted)
    let events = try await pipeline.snapshot(sessionId: "detach").events
    guard case .sessionEnd(let end) = events.last?.payload else {
        Issue.record("Missing session end")
        return
    }
    #expect(end.reason == .released)
    player.pause()
}

@Test(.timeLimit(.minutes(1))) @MainActor func deallocationRemovesObserversAndEndsSession() async throws {
    let url = try audioFixture()
    defer { try? FileManager.default.removeItem(at: url) }
    let player = AVPlayer(url: url)
    let pipeline = try DiagnosticEventPipeline()
    var source: FramewrightAVPlayer? = try FramewrightAVPlayer.attach(
        player: player, pipeline: pipeline, sessionId: "release")
    weak var weakSource = source
    source = nil
    #expect(weakSource == nil)
    try await waitUntil { try await pipeline.snapshot(sessionId: "release").events.count == 2 }
    player.replaceCurrentItem(with: nil)
    #expect(try await pipeline.snapshot(sessionId: "release").events.map(\.type) == [.sessionStart, .sessionEnd])
}

@Test @MainActor func firstFrameHooksRejectUntrackedAndStaleItems() async throws {
    let url = try audioFixture()
    defer { try? FileManager.default.removeItem(at: url) }
    let player = AVPlayer()
    let item = AVPlayerItem(url: url)
    let pipeline = try DiagnosticEventPipeline()
    let source = try FramewrightAVPlayer.attach(player: player, pipeline: pipeline, sessionId: "frame")
    #expect(!source.recordFirstFrame(for: item))
    try source.recordPreparationStarted(for: item)
    player.replaceCurrentItem(with: item)
    #expect(source.recordFirstFrame(for: item))
    #expect(!source.recordFirstFrame(for: item))
    let seek = try source.beginSeek(for: item)
    player.replaceCurrentItem(with: nil)
    source.endSeek(seek)
    #expect(!source.recordFirstFrame(for: item))
    source.detach()
    await source.flush()
    #expect(try await pipeline.snapshot(sessionId: "frame").events.filter { $0.type == .renderFirstFrame }.count == 1)
}

@Test func defaultRedactionRemovesCredentialsAndPrivateLocations() {
    #expect(
        AVPlayerDiagnosticsConfiguration.redactURI("https://user:password@example.com/video.m3u8?token=secret#key")
            == "https://example.com/video.m3u8")
    #expect(AVPlayerDiagnosticsConfiguration.redactURI("file:///Users/name/video.mov") == "<redacted>")
    #expect(AVPlayerDiagnosticsConfiguration.redactURI("not a URL") == "<redacted>")
}

@Test @MainActor func bufferedTimeUsesOnlyContiguousRanges() {
    func range(_ start: Int64, _ duration: Int64) -> CMTimeRange {
        CMTimeRange(start: CMTime(value: start, timescale: 1), duration: CMTime(value: duration, timescale: 1))
    }
    #expect(
        FramewrightAVPlayer.bufferedDurationMs(
            position: CMTime(value: 5, timescale: 1),
            ranges: [range(20, 10), range(8, 4), range(0, 8)]) == 7_000)
    #expect(FramewrightAVPlayer.bufferedDurationMs(position: .indefinite, ranges: [range(0, 10)]) == 0)
    #expect(
        FramewrightAVPlayer.bufferedDurationMs(position: CMTime(value: 12, timescale: 1), ranges: [range(0, 10)]) == 0)
}

@Test @MainActor func closedPipelineIsReportedWithoutChangingPlayer() async throws {
    let url = try audioFixture()
    defer { try? FileManager.default.removeItem(at: url) }
    let player = AVPlayer(url: url)
    let item = player.currentItem
    let pipeline = try DiagnosticEventPipeline()
    await pipeline.close()
    var failures: [AVPlayerDiagnosticsError] = []
    let configuration = AVPlayerDiagnosticsConfiguration(onDiagnosticsError: { error in
        if let error = error as? AVPlayerDiagnosticsError { failures.append(error) }
    })
    let source = try FramewrightAVPlayer.attach(player: player, pipeline: pipeline, configuration: configuration)
    await source.flush()
    #expect(failures == [.pipelineClosed])
    #expect(player.currentItem === item)
    source.detach()
    await source.flush()
}

@Test(.timeLimit(.minutes(1))) @MainActor func queuedOldNotificationsCannotEndReattachedSession() async throws {
    let url = try audioFixture()
    defer { try? FileManager.default.removeItem(at: url) }
    let item = AVPlayerItem(url: url)
    let player = AVPlayer(playerItem: item)
    let pipeline = try DiagnosticEventPipeline()
    let source = try FramewrightAVPlayer.attach(player: player, pipeline: pipeline, sessionId: "old")
    #expect(queueEndNotification(item))
    source.detach()
    try source.attach(pipeline: pipeline, sessionId: "new")
    await source.flush()
    #expect(source.activeSessionID == "new")
    #expect(try await pipeline.snapshot(sessionId: "new").events.map(\.type) == [.sessionStart])
    source.detach()
    await source.flush()
}

private struct NotificationItem: @unchecked Sendable {
    let item: AVPlayerItem
}

@MainActor private func queueEndNotification(_ item: AVPlayerItem) -> Bool {
    let posted = DispatchSemaphore(value: 0)
    let reference = NotificationItem(item: item)
    DispatchQueue.global().async {
        NotificationCenter.default.post(name: AVPlayerItem.didPlayToEndTimeNotification, object: reference.item)
        posted.signal()
    }
    return posted.wait(timeout: .now() + 2) == .success
}
