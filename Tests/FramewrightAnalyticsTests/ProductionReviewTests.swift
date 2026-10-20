import Foundation
import FramewrightAnalytics
import Testing

@Test func schemaIntegersRejectValuesOutsideAndroidRange() throws {
    let tooLarge = Int(Int32.max) + 1
    #expect(throws: AnalyticsValidationError.self) { try FormatSnapshot(bitrate: tooLarge) }
    #expect(throws: AnalyticsValidationError.self) { try DroppedFramesPayload(count: tooLarge, elapsedMs: 1) }
    #expect(throws: AnalyticsValidationError.self) { try IntRangeSnapshot(lower: Int(Int32.min) - 1, upper: 0) }
    #expect(throws: AnalyticsValidationError.self) { try CodecProfileLevelSnapshot(profile: tooLarge, level: 0) }
    #expect(try FormatSnapshot(bitrate: Int(Int32.max)).bitrate == Int(Int32.max))
    let json = "{\"count\":\(tooLarge),\"elapsedMs\":1}"
    #expect(throws: AnalyticsValidationError.self) {
        try JSONDecoder().decode(DroppedFramesPayload.self, from: Data(json.utf8))
    }
}

@Test(arguments: [false, true]) func fatalFlagMustBePresentAndNonNull(useNull: Bool) throws {
    let json = useNull ? #"{"errorCode":"network","isFatal":null}"# : #"{"errorCode":"network"}"#
    #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(PlaybackErrorPayload.self, from: Data(json.utf8))
    }
}

@Test func retainedSnapshotsSurviveBufferWrapAndValueCopies() throws {
    var original = try SessionAggregator(maxEventsPerSession: 1)
    let first = try reviewEvent(id: "first")
    let second = try reviewEvent(id: "second")
    original.record(first)
    let snapshot = try original.snapshot(sessionId: "session")
    var copy = original
    copy.record(second)
    #expect(try original.snapshot(sessionId: "session").events == [first])
    #expect(try copy.snapshot(sessionId: "session").events == [second])
    #expect(try copy.snapshot(sessionId: "session").truncated)
    #expect(snapshot.events == [first])
    copy.clear(sessionId: "session")
    copy.record(first)
    #expect(try !copy.snapshot(sessionId: "session").truncated)
}

@Test(.timeLimit(.minutes(1))) func releasingPipelineFinishesLiveStreams() async throws {
    var pipeline: DiagnosticEventPipeline? = try DiagnosticEventPipeline()
    weak var weakPipeline = pipeline
    let subscription = await pipeline!.subscribe()
    pipeline = nil
    #expect(weakPipeline == nil)
    var iterator = subscription.events.makeAsyncIterator()
    #expect(await iterator.next() == nil)
}

@Test(.timeLimit(.minutes(1))) func closingPipelineDrainsBuffersAndPreservesHistory() async throws {
    let pipeline = try DiagnosticEventPipeline(liveBufferCapacity: 2)
    let subscription = await pipeline.subscribe()
    let first = try reviewEvent(id: "first")
    let second = try reviewEvent(id: "second")
    _ = await pipeline.publish(first)
    _ = await pipeline.publish(second)
    await pipeline.close()
    var iterator = subscription.events.makeAsyncIterator()
    #expect(await iterator.next() == first)
    #expect(await iterator.next() == second)
    #expect(await iterator.next() == nil)
    let rejected = await pipeline.publish(first)
    #expect(!rejected.recorded)
    #expect(rejected.liveDelivery == .closed)
    #expect(try await pipeline.snapshot(sessionId: "session").events == [first, second])
}

private func reviewEvent(id: String) throws -> DiagnosticEvent {
    try DiagnosticEvent(
        metadata: DiagnosticEventMetadata(sessionId: "session", eventId: id, timestampMs: 0, elapsedRealtimeMs: 0),
        payload: .renderFirstFrame(RenderFirstFramePayload(elapsedSincePrepareMs: 0)))
}

@Test(arguments: ["deviceModel", "osVersion", "appVersion"])
func sessionMetadataDefaultsDoNotHideCorruptJSON(field: String) throws {
    var object: [String: Any] = [
        "mediaUri": "https://example.com/video", "deviceModel": "device", "osVersion": "16", "appVersion": "1",
    ]
    object.removeValue(forKey: field)
    #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(SessionStartPayload.self, from: JSONSerialization.data(withJSONObject: object))
    }
    object[field] = NSNull()
    #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(SessionStartPayload.self, from: JSONSerialization.data(withJSONObject: object))
    }
}

private final class ReviewRecordingSink: DiagnosticEventSink, @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [DiagnosticEvent] = []
    func record(_ event: DiagnosticEvent) { lock.withLock { recorded.append(event) } }
    func events() -> [DiagnosticEvent] { lock.withLock { recorded } }
}

private struct ReviewFailingSink: DiagnosticEventSink {
    func record(_ event: DiagnosticEvent) throws { throw AnalyticsValidationError.invalidField("sink") }
}

@Test(.timeLimit(.minutes(1))) func sinksStreamsAndHistoryPreserveConcurrentPublicationOrder() async throws {
    let sink = ReviewRecordingSink()
    let pipeline = try DiagnosticEventPipeline(liveBufferCapacity: 200, sinks: [ReviewFailingSink(), sink])
    let subscription = await pipeline.subscribe()
    let events = try (0..<100).map { try reviewEvent(id: String($0)) }
    await withTaskGroup(of: PublishResult.self) { group in
        for event in events { group.addTask { await pipeline.publish(event) } }
        for await result in group {
            #expect(result.sinkFailureCount == 1)
            #expect(result.liveDelivery == .delivered)
        }
    }
    await pipeline.close()
    var received: [DiagnosticEvent] = []
    for await event in subscription.events { received.append(event) }
    let snapshot = try await pipeline.snapshot(sessionId: "session")
    #expect(received.count == 100)
    #expect(received == snapshot.events)
    #expect(received == sink.events())
    let exported = try await pipeline.exportSessionJSON(sessionId: "session")
    #expect(try DiagnosticEventJSONCodec().decodeSession(exported) == snapshot)
}

@Test func optionalTrackFormatsRemainBackwardCompatible() throws {
    let json = #"{"toFormat":{"bitrate":1},"reason":"INITIAL","estimatedBandwidthBps":1,"bufferedDurationMs":0}"#
    let payload = try JSONDecoder().decode(TrackSwitchPayload.self, from: Data(json.utf8))
    #expect(payload.availableVideoFormats.isEmpty)
}

@Test(arguments: ["profileLevels", "selectedFormatSupport"])
func decoderCapabilityFieldsAreRequired(field: String) throws {
    let url = try #require(Bundle.module.url(forResource: "schema-v2-session", withExtension: "json"))
    let root = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    let events = try #require(root["events"] as? [[String: Any]])
    let decoderEvent = try #require(events.first { $0["type"] as? String == "DECODER_INIT" })
    let payload = try #require(decoderEvent["payload"] as? [String: Any])
    var capabilities = try #require(payload["capabilities"] as? [String: Any])
    capabilities.removeValue(forKey: field)
    #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(
            DecoderCapabilitySnapshot.self, from: JSONSerialization.data(withJSONObject: capabilities))
    }
    capabilities[field] = NSNull()
    #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(
            DecoderCapabilitySnapshot.self, from: JSONSerialization.data(withJSONObject: capabilities))
    }
}

@Test func codecRetainsFullInt64TimestampPrecision() throws {
    let event = try DiagnosticEvent(
        metadata: DiagnosticEventMetadata(
            sessionId: "session", eventId: "large-time", timestampMs: Int64.max,
            elapsedRealtimeMs: 9_007_199_254_740_993),
        payload: .renderFirstFrame(RenderFirstFramePayload(elapsedSincePrepareMs: 0)))
    let codec = DiagnosticEventJSONCodec()
    #expect(try codec.decodeEvent(codec.encodeEvent(event)) == event)
}
