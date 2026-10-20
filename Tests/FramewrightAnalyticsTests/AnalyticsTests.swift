import Foundation
import FramewrightAnalytics
import Testing

private func event(_ payload: DiagnosticPayload, id: String = UUID().uuidString, session: String = "session") throws
    -> DiagnosticEvent
{
    try DiagnosticEvent(
        metadata: DiagnosticEventMetadata(sessionId: session, eventId: id, timestampMs: 100, elapsedRealtimeMs: 10),
        payload: payload
    )
}

@Test func summaryExcludesStartupBuffering() throws {
    let events = try [
        event(.rebufferEnd(RebufferEndPayload(durationMs: 500))),
        event(.renderFirstFrame(RenderFirstFramePayload(elapsedSincePrepareMs: 1_000))),
        event(.rebufferEnd(RebufferEndPayload(durationMs: 2_000))),
        event(
            .trackSwitch(
                TrackSwitchPayload(
                    toFormat: FormatSnapshot(bitrate: 1_000), reason: .initial,
                    estimatedBandwidthBps: 2_000, bufferedDurationMs: 500))),
        event(
            .decoderInit(
                DecoderInitPayload(
                    decoderName: "decoder", mimeType: "video/avc", trackType: .video,
                    initializationDurationMs: 20, isHardwareAccelerated: true))),
        event(.droppedFrames(DroppedFramesPayload(count: 4, elapsedMs: 1_000))),
        event(.sessionEnd(SessionEndPayload(durationMs: 60_000, reason: .playbackEnded))),
    ]
    let summary = try SessionSummaryCalculator().calculate(SessionSnapshot(sessionId: "session", events: events))
    #expect(summary.timeToFirstFrameMs == 1_000)
    #expect(summary.rebufferCount == 1)
    #expect(summary.totalRebufferDurationMs == 2_000)
    #expect(summary.rebufferRatio == 2_000.0 / 60_000)
    #expect(summary.trackSwitchesPerMinute == 1)
    #expect(summary.averageDecoderInitializationMs == 20)
    #expect(summary.droppedFrameCount == 4)
    #expect(!summary.startupFailed)
}

@Test func startupFailuresAndUnknownDurations() throws {
    let failure = try event(.playbackError(PlaybackErrorPayload(errorCode: "network")))
    let summary = try SessionSummaryCalculator().calculate(SessionSnapshot(sessionId: "session", events: [failure]))
    #expect(summary.startupFailed)
    #expect(summary.timeToFirstFrameMs == nil)
    #expect(summary.rebufferRatio == nil)
    #expect(summary.trackSwitchesPerMinute == nil)
    #expect(summary.averageDecoderInitializationMs == nil)
}

@Test func boundedHistoryPreservesInsertionOrderAndIsolation() throws {
    var history = try SessionAggregator(maxEventsPerSession: 2)
    let payload = try DiagnosticPayload.renderFirstFrame(RenderFirstFramePayload(elapsedSincePrepareMs: 10))
    for index in 0..<5 { history.record(try event(payload, id: "\(index)")) }
    history.record(try event(payload, session: "other"))
    let snapshot = try history.snapshot(sessionId: "session")
    #expect(snapshot.events.map(\.eventId) == ["3", "4"])
    #expect(snapshot.truncated)
    history.clear(sessionId: "session")
    #expect(try history.snapshot(sessionId: "session").events.isEmpty)
    #expect(try history.snapshot(sessionId: "other").events.count == 1)
    #expect(snapshot.events.count == 2)
    #expect(try !history.snapshot(sessionId: "missing").truncated)
}

@Test func rejectsInvalidDataAndSummaryOverflow() throws {
    #expect(throws: AnalyticsValidationError.self) { try SessionAggregator(maxEventsPerSession: 0) }
    #expect(throws: AnalyticsValidationError.self) { try FormatSnapshot(bitrate: -1) }
    #expect(throws: AnalyticsValidationError.self) { try DoubleRangeSnapshot(lower: .nan, upper: 2) }
    #expect(throws: AnalyticsValidationError.self) {
        try DiagnosticEventMetadata(sessionId: " ", eventId: "a", timestampMs: 0, elapsedRealtimeMs: 0)
    }
    let events = try [
        event(.renderFirstFrame(RenderFirstFramePayload(elapsedSincePrepareMs: 0))),
        event(.rebufferEnd(RebufferEndPayload(durationMs: .max))),
        event(.rebufferEnd(RebufferEndPayload(durationMs: 1))),
    ]
    #expect(throws: AnalyticsValidationError.self) {
        try SessionSummaryCalculator().calculate(SessionSnapshot(sessionId: "session", events: events))
    }
    #expect(throws: AnalyticsValidationError.self) { try SessionSnapshot(sessionId: "different", events: events) }
}

@Test func androidWireEnvelopeAndErrors() throws {
    let codec = DiagnosticEventJSONCodec()
    let json =
        #"{"schemaVersion":2,"event":{"sessionId":"session","eventId":"first","timestampMs":100,"elapsedRealtimeMs":10,"playerState":"READY","type":"RENDER_FIRST_FRAME","payload":{"elapsedSincePrepareMs":25}}}"#
    let decoded = try codec.decodeEvent(json)
    #expect(decoded.metadata.playerState == .ready)
    #expect(decoded.payload == .renderFirstFrame(try RenderFirstFramePayload(elapsedSincePrepareMs: 25)))
    #expect(try codec.decodeEvent(codec.encodeEvent(decoded)) == decoded)
    #expect(throws: CodecError.unsupportedSchemaVersion(99)) {
        try codec.decodeEvent(json.replacingOccurrences(of: "\"schemaVersion\":2", with: "\"schemaVersion\":99"))
    }
    #expect(throws: CodecError.unknownEventType("FUTURE")) {
        try codec.decodeEvent(json.replacingOccurrences(of: "RENDER_FIRST_FRAME", with: "FUTURE"))
    }
    #expect(throws: CodecError.malformedJSON) { try codec.decodeEvent("{") }
    #expect(throws: CodecError.self) {
        try codec.decodeEvent(
            json.replacingOccurrences(of: "\"elapsedSincePrepareMs\":25", with: "\"elapsedSincePrepareMs\":-1"))
    }
}

private struct FailingSink: DiagnosticEventSink {
    func record(_ event: DiagnosticEvent) throws { throw AnalyticsValidationError.invalidField("sink") }
}

@Test(.timeLimit(.minutes(1))) func sinkFailureAndSlowSubscribersDoNotLoseHistory() async throws {
    let pipeline = try DiagnosticEventPipeline(liveBufferCapacity: 1, sinks: [FailingSink(), FailingSink()])
    let first = try event(.renderFirstFrame(RenderFirstFramePayload(elapsedSincePrepareMs: 1)), id: "first")
    let noListeners = await pipeline.publish(first)
    #expect(noListeners.recorded && noListeners.sinkFailureCount == 2)
    #expect(noListeners.liveDelivery == .noSubscribers)
    let slow = await pipeline.subscribe()
    let fast = await pipeline.subscribe()
    var iterator = fast.events.makeAsyncIterator()
    #expect(await pipeline.publish(first).liveDelivery == .delivered)
    #expect(await iterator.next() == first)
    let second = try event(.rebufferEnd(RebufferEndPayload(durationMs: 5)), id: "second")
    #expect(await pipeline.publish(second).liveDelivery == .dropped)
    #expect(await iterator.next() == second)
    #expect(await pipeline.droppedLiveEventCount == 1)
    #expect(try await pipeline.snapshot(sessionId: "session").events.count == 3)
    await pipeline.unsubscribe(slow.id)
    await pipeline.close()
    #expect(await iterator.next() == nil)
    #expect(await pipeline.publish(first).liveDelivery == .closed)
    let closed = await pipeline.subscribe()
    var closedIterator = closed.events.makeAsyncIterator()
    #expect(await closedIterator.next() == nil)
}

@Test(.timeLimit(.minutes(1))) func concurrentPublicationRetainsEveryEvent() async throws {
    let pipeline = try DiagnosticEventPipeline(maxEventsPerSession: 1_000)
    let events = try (0..<200).map {
        try event(.droppedFrames(DroppedFramesPayload(count: 1, elapsedMs: 1)), id: "\($0)")
    }
    await withTaskGroup(of: Void.self) { group in
        for value in events { group.addTask { _ = await pipeline.publish(value) } }
    }
    let snapshot = try await pipeline.snapshot(sessionId: "session")
    #expect(Set(snapshot.events.map(\.eventId)) == Set(events.map(\.eventId)))
    let json = try await pipeline.exportSessionJSON(sessionId: "session")
    #expect(try DiagnosticEventJSONCodec().decodeSession(json) == snapshot)
    await pipeline.close()
}

@Test func everyEventTypeMatchesSchemaV2Fixture() throws {
    let url = try #require(Bundle.module.url(forResource: "schema-v2-session", withExtension: "json"))
    let json = try String(contentsOf: url, encoding: .utf8)
    let codec = DiagnosticEventJSONCodec()
    let snapshot = try codec.decodeSession(json)
    #expect(Set(snapshot.events.map(\.type)) == Set(EventType.allCases))
    let encoded = try codec.encodeSession(snapshot)
    let originalObject = try #require(JSONSerialization.jsonObject(with: Data(json.utf8)) as? NSDictionary)
    let encodedObject = try #require(JSONSerialization.jsonObject(with: Data(encoded.utf8)) as? NSDictionary)
    #expect(originalObject == encodedObject)
    for value in snapshot.events {
        #expect(try codec.decodeEvent(codec.encodeEvent(value)) == value)
    }
}

@Test func codecRejectsMismatchedSessionsAndInvalidNestedData() throws {
    let url = try #require(Bundle.module.url(forResource: "schema-v2-session", withExtension: "json"))
    let json = try String(contentsOf: url, encoding: .utf8)
    let codec = DiagnosticEventJSONCodec()
    var object = try #require(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
    object["sessionId"] = "wrong"
    let mismatched = String(decoding: try JSONSerialization.data(withJSONObject: object), as: UTF8.self)
    #expect(throws: CodecError.self) { try codec.decodeSession(mismatched) }
    #expect(throws: CodecError.self) {
        try codec.decodeSession(json.replacingOccurrences(of: "\"widthAlignment\": 2", with: "\"widthAlignment\": 0"))
    }
    #expect(throws: CodecError.self) {
        try codec.decodeSession(json.replacingOccurrences(of: "\"confidence\": 0.9", with: "\"confidence\": 1.1"))
    }
}

@Test func completedZeroDurationAndTruncatedSummaries() throws {
    let frame = try event(.renderFirstFrame(RenderFirstFramePayload(elapsedSincePrepareMs: 10)))
    let fatal = try event(.playbackError(PlaybackErrorPayload(errorCode: "later")))
    let end = try event(.sessionEnd(SessionEndPayload(durationMs: 0, reason: .error)))
    let result = try SessionSummaryCalculator().calculate(
        SessionSnapshot(sessionId: "session", truncated: true, events: [frame, fatal, end]))
    #expect(result.truncated)
    #expect(!result.startupFailed)
    #expect(result.rebufferRatio == nil)
    #expect(result.trackSwitchesPerMinute == nil)
}

@Test(.timeLimit(.minutes(1))) func subscribersHaveNoReplayAndExplicitUnsubscribe() async throws {
    let pipeline = try DiagnosticEventPipeline()
    let first = try event(.renderFirstFrame(RenderFirstFramePayload(elapsedSincePrepareMs: 1)))
    _ = await pipeline.publish(first)
    let subscription = await pipeline.subscribe()
    await pipeline.unsubscribe(subscription.id)
    await pipeline.unsubscribe(subscription.id)
    var iterator = subscription.events.makeAsyncIterator()
    #expect(await iterator.next() == nil)
    #expect(await pipeline.publish(first).liveDelivery == .noSubscribers)
    await pipeline.clear(sessionId: "session")
    #expect(try await pipeline.snapshot(sessionId: "session").events.isEmpty)
    await pipeline.close()
    await pipeline.close()
}

@Test(.timeLimit(.minutes(1))) func subscriberCancellationDoesNotStopPublication() async throws {
    let pipeline = try DiagnosticEventPipeline()
    let subscription = await pipeline.subscribe()
    let consumer = Task { for await _ in subscription.events {} }
    consumer.cancel()
    await consumer.value
    let value = try event(.renderFirstFrame(RenderFirstFramePayload(elapsedSincePrepareMs: 1)))
    #expect(await pipeline.publish(value).liveDelivery == .noSubscribers)
    #expect(try await pipeline.snapshot(sessionId: "session").events == [value])
    await pipeline.close()
}
