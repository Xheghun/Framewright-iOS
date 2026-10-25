import AVFoundation
import FramewrightAnalytics
import Testing

@testable import FramewrightDemo

@Test @MainActor func streamValidationRejectsUnsafeOrInvalidInputs() {
    #expect(PlaybackModel.streamURL("http://example.com/movie.mp4") == nil)
    #expect(PlaybackModel.streamURL("file:///private/movie.mp4") == nil)
    #expect(PlaybackModel.streamURL("https://user:secret@example.com/video") == nil)
    #expect(PlaybackModel.streamURL("not a URL") == nil)
    #expect(PlaybackModel.streamURL(" https://example.com/video.m3u8?token=value ") != nil)
}

@Test @MainActor func replacementAndDisconnectExportCompleteSessions() async throws {
    let url = try #require(Bundle.main.url(forResource: "TestPattern", withExtension: "mp4"))
    let model = PlaybackModel()
    await model.connect()
    #expect(model.connected)
    model.load(url)
    let first = model.selectedSession
    model.load(url)
    let second = model.selectedSession
    #expect(first != second)
    let replaced = try await model.exportSession(first)
    #expect(replaced.contains("REPLACED"))
    #expect(!replaced.contains(url.path))
    await model.disconnect()
    #expect(!model.connected)
    #expect(model.player.currentItem == nil)
    let released = try await model.exportSession(second)
    #expect(released.contains("RELEASED"))
}

@Test @MainActor func invalidStreamPreservesCurrentItem() async throws {
    let url = try #require(Bundle.main.url(forResource: "ColorBars", withExtension: "mp4"))
    let model = PlaybackModel()
    await model.connect()
    model.load(url)
    let item = model.player.currentItem
    model.loadStream("http://example.com/video.mp4")
    #expect(model.player.currentItem === item)
    #expect(model.message != nil)
    await model.disconnect()
}

@Test @MainActor func reconnectCreatesNewSessionAndKeepsExportHistory() async throws {
    let url = try #require(Bundle.main.url(forResource: "TestPattern", withExtension: "mp4"))
    let model = PlaybackModel()
    await model.connect()
    model.load(url)
    let first = model.selectedSession
    await model.disconnect()
    await model.connect()
    #expect(model.connected)
    model.load(url)
    #expect(model.selectedSession != first)
    #expect(try await model.exportSession(first).contains("RELEASED"))
    await model.disconnect()
}

@Test(.timeLimit(.minutes(1))) @MainActor func videoPlaybackAndReplayUseSeparateSessions() async throws {
    let url = try #require(Bundle.main.url(forResource: "TestPattern", withExtension: "mp4"))
    let model = PlaybackModel()
    await model.connect()
    model.load(url)
    let initial = model.selectedSession
    model.play()
    let deadline = ContinuousClock.now.advanced(by: .seconds(30))
    while model.player.currentTime().seconds < 0.1, ContinuousClock.now < deadline {
        try await Task.sleep(for: .milliseconds(50))
    }
    #expect(model.player.currentTime().seconds >= 0.1)
    model.replay()
    #expect(model.selectedSession != initial)
    model.pause()
    try await Task.sleep(for: .milliseconds(100))
    #expect(model.player.rate == 0)
    let export = try await model.exportSession(initial)
    #expect(export.contains("REPLACED"))
    #expect(try !DiagnosticEventJSONCodec().decodeSession(export).events.contains { $0.type == .renderFirstFrame })
    await model.disconnect()
}
