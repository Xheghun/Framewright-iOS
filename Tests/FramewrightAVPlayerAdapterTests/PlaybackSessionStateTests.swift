import Foundation
import FramewrightAnalytics
import Testing

@testable import FramewrightAVPlayerAdapter

private func time(_ ms: Int64) -> DiagnosticTime { DiagnosticTime(wallMs: 1_000 + ms, monotonicMs: ms) }
private func start(_ state: inout PlaybackSessionState, prepared: Int64? = 0) throws -> [DiagnosticEvent] {
    try state.start(
        id: "session", payload: SessionStartPayload(mediaUri: "https://example.com/video"), preparedMs: prepared,
        at: time(0))
}

@Test func firstFrameRequiresPreparationAndIsReportedOnce() throws {
    var state = PlaybackSessionState()
    _ = try start(&state, prepared: nil)
    #expect(try state.firstFrame(at: time(10)).isEmpty)
    state.markPreparation(at: time(10))
    let events = try state.firstFrame(at: time(40))
    #expect(events.map(\.type) == [.renderFirstFrame])
    #expect(events.first?.payload == .renderFirstFrame(try RenderFirstFramePayload(elapsedSincePrepareMs: 30)))
    #expect(try state.firstFrame(at: time(50)).isEmpty)
}

@Test func bufferingDeduplicatesAndExcludesStartupAndSeek() throws {
    var state = PlaybackSessionState()
    _ = try start(&state)
    #expect(try state.update(control: .waiting, ready: false, buffering: true, bufferedMs: 0, at: time(1)).isEmpty)
    _ = try state.firstFrame(at: time(10))
    #expect(
        try state.update(control: .waiting, ready: true, buffering: true, bufferedMs: 5, at: time(20)).map(\.type) == [
            .rebufferStart
        ])
    #expect(try state.update(control: .waiting, ready: true, buffering: true, bufferedMs: 0, at: time(30)).isEmpty)
    let resumed = try state.update(control: .playing, ready: true, buffering: false, bufferedMs: 100, at: time(50))
    #expect(resumed.first?.payload == .rebufferEnd(try RebufferEndPayload(durationMs: 30)))
    state.beginSeek()
    _ = try state.update(control: .playing, ready: true, buffering: false, bufferedMs: 100, at: time(60))
    #expect(try state.update(control: .waiting, ready: true, buffering: true, bufferedMs: 0, at: time(70)).isEmpty)
    state.finishSeek()
    #expect(
        try state.update(control: .waiting, ready: true, buffering: true, bufferedMs: 0, at: time(80)).map(\.type) == [
            .rebufferStart
        ])
}

@Test func terminalStateClosesRebufferAndDeduplicatesFailures() throws {
    var state = PlaybackSessionState()
    _ = try start(&state)
    _ = try state.firstFrame(at: time(1))
    _ = try state.update(control: .waiting, ready: true, buffering: true, bufferedMs: 0, at: time(10))
    let events = try state.fail(code: "network", message: nil, at: time(30))
    #expect(events.map(\.type) == [.playbackError, .rebufferEnd, .sessionEnd])
    #expect(events.last?.payload == .sessionEnd(try SessionEndPayload(durationMs: 30, reason: .error)))
    #expect(state.sessionID == nil)
    #expect(try state.fail(code: "duplicate", message: nil, at: time(31)).isEmpty)
    #expect(try state.end(reason: .released, at: time(32)).isEmpty)
}

@Test func pauseDoesNotCountPausedTimeAsRebuffering() throws {
    var state = PlaybackSessionState()
    _ = try start(&state)
    _ = try state.firstFrame(at: time(1))
    _ = try state.update(control: .waiting, ready: true, buffering: true, bufferedMs: 0, at: time(10))
    #expect(try state.update(control: .paused, ready: true, buffering: false, bufferedMs: 0, at: time(20)).isEmpty)
    #expect(
        try state.update(control: .playing, ready: true, buffering: false, bufferedMs: 100, at: time(1_000)).isEmpty)
}
