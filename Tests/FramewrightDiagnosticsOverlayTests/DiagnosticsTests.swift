import Foundation
import FramewrightAnalytics
import FramewrightDiagnosticsOverlay
import Testing

private func event(_ payload: DiagnosticPayload, session: String = "first") throws -> DiagnosticEvent {
    try DiagnosticEvent(
        metadata: DiagnosticEventMetadata(
            sessionId: session, eventId: UUID().uuidString,
            timestampMs: 1, elapsedRealtimeMs: 1), payload: payload)
}

@Test func unavailableMetricsAndNamesRemainExplicit() throws {
    let empty = try DiagnosticsState(snapshot: SessionSnapshot(sessionId: "first"))
    #expect(empty.summary.timeToFirstFrameMs == nil)
    #expect(empty.droppedFrames == nil)
    #expect(empty.deviceName == "Unavailable")
    let start = try event(
        .sessionStart(
            .init(
                mediaUri: "https://example.com", deviceModel: "iPhone17,1",
                deviceName: "iPhone 16 Pro")))
    let state = try DiagnosticsState(snapshot: SessionSnapshot(sessionId: "first", events: [start]))
    #expect(state.deviceName == "iPhone 16 Pro")
    #expect(state.deviceModel == "iPhone17,1")
    #expect(state.status == "Started")
}

@Test func reductionPreservesTruncationAndMeasuredZero() throws {
    let events = try [
        event(.playbackStateChanged(.init(status: .playing))),
        event(.droppedFrames(.init(count: 0, elapsedMs: 10))),
        event(.sessionEnd(.init(durationMs: 10, reason: .playbackEnded))),
    ]
    let state = try DiagnosticsState(snapshot: SessionSnapshot(sessionId: "first", truncated: true, events: events))
    #expect(state.snapshot.truncated)
    #expect(state.droppedFrames == 0)
    #expect(state.status == "Ended")
    let codec = DiagnosticEventJSONCodec()
    #expect(try codec.decodeSession(codec.encodeSession(state.snapshot)) == state.snapshot)
}

@MainActor private func waitFor(_ condition: () -> Bool) async throws {
    let deadline = ContinuousClock.now.advanced(by: .seconds(5))
    while !condition() {
        guard ContinuousClock.now < deadline else { throw WaitError.timeout }
        try await Task.sleep(for: .milliseconds(20))
    }
}
private enum WaitError: Error { case timeout }

@Test @MainActor func observationSwitchesSessionsAndCancelsWithoutClosingPipeline() async throws {
    let pipeline = try DiagnosticEventPipeline(maxEventsPerSession: 2, liveBufferCapacity: 1)
    let otherSubscriber = await pipeline.subscribe()
    let model = DiagnosticsModel()
    let first = Task { await model.observe(pipeline: pipeline, sessionID: "first") }
    defer { first.cancel() }
    try await waitFor { model.state?.snapshot.sessionId == "first" }
    for _ in 0..<5 { _ = await pipeline.publish(try event(.playbackStateChanged(.init(status: .playing)))) }
    try await waitFor { model.state?.snapshot.truncated == true }
    #expect(model.state?.snapshot.events.count == 2)
    let second = Task { await model.observe(pipeline: pipeline, sessionID: "second") }
    defer { second.cancel() }
    try await waitFor { model.state?.snapshot.sessionId == "second" }
    await first.value
    _ = await pipeline.publish(try event(.playbackStateChanged(.init(status: .paused)), session: "second"))
    try await waitFor { model.state?.status == "Paused" }
    second.cancel()
    await second.value
    let frozen = model.state
    let result = await pipeline.publish(try event(.playbackStateChanged(.init(status: .playing)), session: "second"))
    #expect(result.recorded)
    #expect(model.state == frozen)
    await pipeline.unsubscribe(otherSubscriber.id)
}

@Test @MainActor func cancelledObservationCannotReplaceCurrentSession() async throws {
    let pipeline = try DiagnosticEventPipeline()
    let model = DiagnosticsModel()
    let active = Task { await model.observe(pipeline: pipeline, sessionID: "first") }
    defer { active.cancel() }
    try await waitFor { model.state?.snapshot.sessionId == "first" }
    let cancelled = Task { await model.observe(pipeline: pipeline, sessionID: "stale") }
    cancelled.cancel()
    await cancelled.value
    #expect(model.state?.snapshot.sessionId == "first")
    _ = await pipeline.publish(try event(.playbackStateChanged(.init(status: .playing))))
    try await waitFor { model.state?.status == "Playing" }
    active.cancel()
    await active.value
}

@Test @MainActor func unchangedHistoryDoesNotPublishRepeatedUpdates() async throws {
    let pipeline = try DiagnosticEventPipeline()
    let model = DiagnosticsModel()
    let observation = Task { await model.observe(pipeline: pipeline, sessionID: "first") }
    defer { observation.cancel() }
    try await waitFor { model.state != nil }
    var updates = 0
    let subscription = model.objectWillChange.sink { updates += 1 }
    defer { subscription.cancel() }
    try await Task.sleep(for: .milliseconds(600))
    #expect(updates == 0)
    observation.cancel()
    await observation.value
}

@Test @MainActor func invalidMetricsRecoverAfterHistoryIsCleared() async throws {
    let pipeline = try DiagnosticEventPipeline()
    _ = await pipeline.publish(try event(.renderFirstFrame(.init(elapsedSincePrepareMs: 1))))
    for _ in 0..<2 {
        _ = await pipeline.publish(try event(.rebufferEnd(.init(durationMs: Int64.max))))
    }
    let model = DiagnosticsModel()
    let observation = Task { await model.observe(pipeline: pipeline, sessionID: "first") }
    defer { observation.cancel() }
    try await waitFor { model.errorMessage != nil }
    #expect(model.state == nil)
    await pipeline.clear(sessionId: "first")
    _ = await pipeline.publish(try event(.playbackStateChanged(.init(status: .playing))))
    try await waitFor { model.state?.status == "Playing" }
    #expect(model.errorMessage == nil)
    observation.cancel()
    await observation.value
}
